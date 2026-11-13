// Points T3's default model at the Claude account that still has usage left: Claude while it has
// room, Claude Pulse while Claude is limited. The other account becomes the fallback.
// T3's own fallback reads a cached usage snapshot that misses an exhausted window, so this asks
// each account directly with the CLI's get_usage control request.
import { renameSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";

const SETTINGS = `${homedir()}/.t3/userdata/settings.json`;
const ACCOUNTS = [
  { instanceId: "claudeAgent", configDir: undefined },
  { instanceId: "claude-pulse", configDir: `${homedir()}/.claude-pulse` },
] as const;

async function usedPercent(configDir: string | undefined): Promise<number | undefined> {
  const env = { ...process.env };
  delete env.CLAUDE_CONFIG_DIR;
  if (configDir) env.CLAUDE_CONFIG_DIR = configDir;
  const proc = Bun.spawn(
    ["claude", "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
    { env, stdin: "pipe", stdout: "pipe", stderr: "ignore", cwd: homedir() },
  );
  const request = (id: string, subtype: string) =>
    JSON.stringify({ type: "control_request", request_id: id, request: { subtype } }) + "\n";
  proc.stdin.write(request("init", "initialize") + request("usage", "get_usage"));
  proc.stdin.flush();
  const timer = setTimeout(() => proc.kill(), 90_000);
  try {
    let buffered = "";
    for await (const chunk of proc.stdout.pipeThrough(new TextDecoderStream())) {
      buffered += chunk;
      let newline: number;
      while ((newline = buffered.indexOf("\n")) >= 0) {
        const line = buffered.slice(0, newline);
        buffered = buffered.slice(newline + 1);
        if (!line.includes('"usage"')) continue;
        const message = JSON.parse(line);
        if (message.response?.request_id !== "usage") continue;
        const limits = message.response.response?.rate_limits;
        if (!limits) return undefined;
        // get_usage reports 0-100.
        return Math.max(limits.five_hour?.utilization ?? 0, limits.seven_day?.utilization ?? 0);
      }
    }
    return undefined;
  } finally {
    clearTimeout(timer);
    proc.kill();
  }
}

const settings = JSON.parse(readFileSync(SETTINGS, "utf8"));
const current = settings.defaultModelSelection;
// A default set to another provider by hand is left alone.
if (current && !ACCOUNTS.some((a) => a.instanceId === current.instanceId)) process.exit(0);
const model = current?.model ?? "claude-opus-5-5";
const usage = await Promise.all(ACCOUNTS.map((a) => usedPercent(a.configDir)));
console.log(new Date().toISOString(), ACCOUNTS.map((a, i) => `${a.instanceId}=${usage[i] ?? "?"}`).join(" "));

// An unreadable account counts as unavailable; with neither readable, nothing changes.
const open = ACCOUNTS.findIndex((_, i) => usage[i] !== undefined && usage[i]! < 100);
if (open < 0) process.exit(0);
const pick = ACCOUNTS[open]!.instanceId;
const other = ACCOUNTS[1 - open]!.instanceId;
if (current?.instanceId === pick && settings.fallbackModelSelection?.instanceId === other) process.exit(0);

settings.defaultModelSelection = { ...current, instanceId: pick, model };
settings.fallbackModelSelection = { instanceId: other, model };
writeFileSync(SETTINGS + ".tmp", JSON.stringify(settings, null, 2) + "\n");
renameSync(SETTINGS + ".tmp", SETTINGS);
console.log(`default -> ${pick}, fallback -> ${other}`);
