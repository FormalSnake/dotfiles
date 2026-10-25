// Mirrors Claude Code CLI sessions (herdr panes) into the local T3 Code server
// as they are written, so a session started in the terminal can be picked up
// from the T3 Code apps. T3 Code imports CLI transcripts only when asked, so
// this asks on every transcript change.
//
// Usage: t3code-cli-sync <t3 binary> <state dir> <claude config dir>...
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, realpathSync, watch, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";

const [t3, stateDir, ...configDirs] = process.argv.slice(2);
const origin = "http://127.0.0.1:3773";
const tokenFile = join(stateDir, "token");
const DEBOUNCE_MS = 1500;
const SESSION_FILE = /^[0-9a-f-]{36}\.jsonl$/;

const log = (...args) => console.log(new Date().toISOString(), ...args);

let token = existsSync(tokenFile) ? readFileSync(tokenFile, "utf8").trim() : "";

function issueToken() {
  const out = execFileSync(t3, [
    "auth", "session", "issue", "--token-only", "--ttl", "365d",
    "--label", "CLI session sync",
    "--scope", "orchestration:read", "--scope", "orchestration:operate",
  ], { encoding: "utf8" });
  token = out.split("\n").map((line) => line.trim()).filter(Boolean).at(-1);
  mkdirSync(stateDir, { recursive: true, mode: 0o700 });
  writeFileSync(tokenFile, token, { mode: 0o600 });
}

async function http(path, init = {}) {
  for (let attempt = 0; attempt < 2; attempt++) {
    if (!token) issueToken();
    const response = await fetch(origin + path, {
      ...init,
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...init.headers },
    });
    if (response.status === 401) {
      token = "";
      continue;
    }
    if (!response.ok) throw new Error(`${path}: ${response.status} ${await response.text()}`);
    return response.json();
  }
  throw new Error(`${path}: unauthorized after reissuing the token`);
}

// One socket per batch: the server's RPC protocol is Effect RPC over JSON.
async function rpc(calls) {
  const { ticket } = await http("/api/auth/websocket-ticket", { method: "POST" });
  const ws = new WebSocket(`${origin.replace("http", "ws")}/ws?orchestrationProtocol=2&wsTicket=${encodeURIComponent(ticket)}`);
  const pending = new Map();
  let next = 0;
  ws.onmessage = (event) => {
    const message = JSON.parse(String(event.data));
    if (message._tag !== "Exit") return;
    const done = pending.get(message.requestId);
    if (!done) return;
    pending.delete(message.requestId);
    if (message.exit._tag === "Success") done.resolve(message.exit.value);
    else done.reject(new Error(JSON.stringify(message.exit.cause).slice(0, 500)));
  };
  // A server restart drops the socket without an Exit, which would otherwise
  // leave the batch waiting forever.
  ws.onclose = () => {
    for (const { reject } of pending.values()) reject(new Error("socket closed"));
    pending.clear();
  };
  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = () => reject(new Error("socket failed to open"));
    setTimeout(() => reject(new Error("socket open timed out")), 15_000);
  });
  const call = (tag, payload) =>
    new Promise((resolve, reject) => {
      const id = String(next++);
      pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (pending.delete(id)) reject(new Error(`${tag} timed out`));
      }, 120_000);
      ws.send(JSON.stringify({ _tag: "Request", id, tag, payload, headers: [] }));
    });
  try {
    return await calls(call);
  } finally {
    ws.close();
  }
}

// The working directory sits on an early record of a Claude transcript, after
// metadata records that can carry large attachments.
function transcriptCwd(file) {
  const fd = openSync(file, "r");
  try {
    const buffer = Buffer.alloc(1 << 20);
    const length = readSync(fd, buffer, 0, buffer.length, 0);
    const match = buffer.subarray(0, length).toString("utf8").match(/"cwd":"((?:[^"\\]|\\.)*)"/);
    return match ? canonical(JSON.parse(`"${match[1]}"`)) : null;
  } finally {
    closeSync(fd);
  }
}

// macOS paths are case-insensitive and transcripts keep whatever case the
// shell had, so compare the on-disk spelling.
function canonical(path) {
  try {
    return realpathSync.native(path);
  } catch {
    return null;
  }
}

const seen = new Set();
const dirty = new Set();
let timer = null;
let running = false;

async function flush() {
  if (running) {
    timer = setTimeout(flush, DEBOUNCE_MS);
    return;
  }
  running = true;
  const files = [...dirty];
  dirty.clear();
  try {
    const cwds = new Set();
    let fresh = false;
    for (const file of files) {
      if (!existsSync(file)) continue;
      if (!seen.has(file)) fresh = true;
      seen.add(file);
      const cwd = transcriptCwd(file);
      if (cwd) cwds.add(cwd);
    }
    if (cwds.size === 0) return;
    await rpc(async (call) => {
      // The server caches its transcript list between scans; only a new
      // session file needs a rescan, a growing one is re-read on import.
      const scan = fresh ? await call("agentSessions.scan", {}) : null;
      const { projects } = await http("/api/projects");
      for (const cwd of cwds) {
        let project = projects.find((p) => p.deletedAt === null && canonical(p.workspaceRoot) === cwd);
        // Sessions in a git repository T3 Code does not know yet bring the
        // project along; anything else (home, /tmp) stays CLI only.
        const candidate = scan?.candidates.find((c) => canonical(c.path) === cwd);
        if (!project && candidate?.git) {
          project = await http("/api/projects/mutate", {
            method: "POST",
            body: JSON.stringify({
              type: "project.create",
              commandId: randomUUID(),
              projectId: randomUUID(),
              title: candidate.title,
              workspaceRoot: cwd,
            }),
          });
          projects.push(project);
          log("created project", cwd);
        }
        if (!project) continue;
        const result = await call("agentSessions.import", { projectId: project.id, expectedWorkspaceRoot: project.workspaceRoot });
        log("imported", cwd, JSON.stringify(result));
      }
    });
  } catch (error) {
    log("sync failed:", error.message);
    for (const file of files) dirty.add(file);
    timer = setTimeout(flush, 10_000);
  } finally {
    running = false;
  }
}

for (const configDir of configDirs) {
  const root = join(configDir, "projects");
  mkdirSync(root, { recursive: true });
  // Only <root>/<project>/<session>.jsonl: subagent transcripts nest deeper.
  watch(root, { recursive: true }, (_event, name) => {
    if (!name || !SESSION_FILE.test(basename(name)) || dirname(name).includes("/")) return;
    dirty.add(join(root, name));
    clearTimeout(timer);
    timer = setTimeout(flush, DEBOUNCE_MS);
  });
  log("watching", root);
}
