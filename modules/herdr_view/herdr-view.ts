// What the Herdr viewer mod streams from this host, on 127.0.0.1 and the host's Tailscale address.
//
// The browser is a headless Chromium with CDP on 127.0.0.1:9222, the same one agents on this host
// drive, so the person watches what they do. The simulator is serve-sim's helper for the booted
// device: T3 Code may already run it on loopback without a token, and serve-sim allows one helper
// per device, so this reaches it from loopback (trusted) instead of starting a second one.

import { $ } from "bun";
import { realpathSync } from "fs";
import { networkInterfaces } from "os";
import { dirname, join } from "path";

const PORT = 7650;
const CDP = 9222;
const MAC = process.platform === "darwin";
const STATE = join(process.env.HOME ?? "", ".cache/herdr-view");
// The simulator stream is 60fps at device resolution; the mod writes each frame to disk.
const SIM_FRAME_MS = 66;

// Read from the interfaces: the App Store Tailscale CLI on macOS refuses to run from launchd.
async function tailscaleIp(): Promise<string> {
  for (;;) {
    for (const addrs of Object.values(networkInterfaces())) {
      for (const a of addrs ?? []) {
        const [x, y] = a.address.split(".").map(Number);
        if (a.family === "IPv4" && x === 100 && y >= 64 && y < 128) return a.address;
      }
    }
    await Bun.sleep(5000);
  }
}

// Browser

function chromium(): string {
  if (MAC) return "/Applications/Helium.app/Contents/MacOS/Helium";
  // The store's helium is a wrapper script; the binary sits in the versioned folder beside bin/.
  const root = join(dirname(realpathSync(Bun.which("helium") ?? "/opt/fspec/current/bin/helium")), "..");
  for (const hit of new Bun.Glob("helium-*_linux/helium").scanSync({ cwd: root })) return join(root, hit);
  throw new Error("no helium binary under " + root);
}

const cdp = (path: string, init?: RequestInit) => fetch(`http://127.0.0.1:${CDP}${path}`, init);

async function browserUp(): Promise<boolean> {
  try {
    return (await cdp("/json/version")).ok;
  } catch {
    return false;
  }
}

let starting: Promise<void> | null = null;
async function ensureBrowser(): Promise<void> {
  if (await browserUp()) return;
  starting ??= (async () => {
    Bun.spawn([
      chromium(), "--headless=new", `--remote-debugging-port=${CDP}`, "--remote-debugging-address=127.0.0.1",
      `--user-data-dir=${STATE}/chromium`, "--no-first-run", "--no-default-browser-check", "about:blank",
    ], { stdout: Bun.file(`${STATE}/chromium.log`), stderr: Bun.file(`${STATE}/chromium.log`) }).unref();
    for (let i = 0; i < 50 && !(await browserUp()); i++) await Bun.sleep(200);
  })().finally(() => (starting = null));
  await starting;
  if (!(await browserUp())) throw new Error("chromium did not start, see " + STATE + "/chromium.log");
}

async function pages() {
  await ensureBrowser();
  let list = ((await (await cdp("/json/list")).json()) as any[]).filter((t) => t.type === "page");
  if (!list.length) list = [await (await cdp("/json/new?about:blank", { method: "PUT" })).json()];
  return list.map((t) => ({ id: t.id, title: t.title, url: t.url }));
}

// Simulator

interface Stream { device: string; streamUrl: string; wsUrl: string }

async function stream(): Promise<Stream | null> {
  try {
    const out = JSON.parse(await $`serve-sim --list -q`.quiet().text());
    const list = (Array.isArray(out) ? out : [out]).filter((s) => s?.running && s.streamUrl);
    return list[0] ?? null;
  } catch {
    return null;
  }
}

async function booted(): Promise<{ udid: string; name: string; state: string }[]> {
  const out = JSON.parse(await $`xcrun simctl list devices available -j`.quiet().text());
  return Object.entries(out.devices as Record<string, any[]>)
    .filter(([runtime]) => runtime.includes("iOS"))
    .flatMap(([, ds]) => ds.map((d) => ({ udid: d.udid, name: d.name, state: d.state })));
}

async function simInfo() {
  if (!MAC) return { error: "no simulator on this host" };
  let s = await stream();
  const devices = await booted();
  if (!s && devices.some((d) => d.state === "Booted")) {
    await $`serve-sim --detach -q --codec mjpeg`.quiet().nothrow();
    s = await stream();
  }
  if (!s) return { devices };
  const config = await (await fetch(s.streamUrl.replace(/stream\.mjpeg$/, "config"))).json().catch(() => null);
  const name = devices.find((d) => d.udid === s!.device)?.name ?? s.device;
  return { device: s.device, name, config };
}

// JPEG frames cut out of the MJPEG body by their start and end markers.
async function pumpFrames(url: string, send: (jpeg: Uint8Array) => void, signal: AbortSignal) {
  const res = await fetch(url, { signal });
  const reader = res.body!.getReader();
  let buf = new Uint8Array(0);
  let last = 0;
  for (;;) {
    const { value, done } = await reader.read();
    if (done) return;
    const next = new Uint8Array(buf.length + value.length);
    next.set(buf);
    next.set(value, buf.length);
    buf = next;
    let start = -1;
    let frame: Uint8Array | null = null;
    let cut = 0;
    for (let i = 0; i + 1 < buf.length; i++) {
      if (buf[i] === 0xff && buf[i + 1] === 0xd8 && start < 0) start = i;
      else if (buf[i] === 0xff && buf[i + 1] === 0xd9 && start >= 0) {
        frame = buf.subarray(start, i + 2);
        cut = i + 2;
        start = -1;
      }
    }
    if (frame) {
      const now = Date.now();
      if (now - last >= SIM_FRAME_MS) {
        last = now;
        send(frame.slice());
      }
    }
    buf = buf.slice(start >= 0 ? start : cut);
  }
}

// Server

type Socket = { kind: "proxy"; target: string; up?: WebSocket; queue: any[] } | { kind: "frames"; abort?: AbortController };

const json = (body: unknown, status = 200) => Response.json(body, { status });

async function route(req: Request, server: any): Promise<Response | undefined> {
  const url = new URL(req.url);
  const p = url.pathname;
  try {
    if (p === "/browser/pages") return json(await pages());
    if (p.startsWith("/browser/page/")) {
      await ensureBrowser();
      const target = `ws://127.0.0.1:${CDP}/devtools/page/${p.slice("/browser/page/".length)}`;
      if (server.upgrade(req, { data: { kind: "proxy", target, queue: [] } })) return;
    }
    if (p === "/sim/info") return json(await simInfo());
    if (p === "/sim/boot" && req.method === "POST") {
      await $`xcrun simctl boot ${url.searchParams.get("udid") ?? ""}`.quiet().nothrow();
      return json(await simInfo());
    }
    if (p === "/sim/input") {
      const s = await stream();
      if (s && server.upgrade(req, { data: { kind: "proxy", target: s.wsUrl, queue: [] } })) return;
    }
    if (p === "/sim/frames" && server.upgrade(req, { data: { kind: "frames" } })) return;
    return json({ error: "not found" }, 404);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
}

const websocket = {
  async open(ws: any) {
    const d: Socket = ws.data;
    if (d.kind === "frames") {
      const s = await stream();
      if (!s) return ws.close(1011, "no simulator stream");
      d.abort = new AbortController();
      pumpFrames(s.streamUrl, (f) => {
        // A slow client skips frames rather than queueing them.
        if (ws.getBufferedAmount() < 1 << 20) ws.send(f);
      }, d.abort.signal).catch(() => {}).finally(() => ws.close());
      return;
    }
    const up = new WebSocket(d.target);
    up.binaryType = "arraybuffer";
    d.up = up;
    up.onopen = () => { for (const m of d.queue.splice(0)) up.send(m); };
    up.onmessage = (e) => ws.send(e.data);
    up.onclose = () => ws.close();
    up.onerror = () => ws.close();
  },
  message(ws: any, msg: string | Uint8Array) {
    const d: Socket = ws.data;
    if (d.kind !== "proxy") return;
    if (d.up?.readyState === WebSocket.OPEN) d.up.send(msg);
    else d.queue.push(msg);
  },
  close(ws: any) {
    const d: Socket = ws.data;
    if (d.kind === "frames") d.abort?.abort();
    else d.up?.close();
  },
};

await $`mkdir -p ${STATE}`.quiet();
Bun.serve({ hostname: "127.0.0.1", port: PORT, fetch: route, websocket });
Bun.serve({ hostname: await tailscaleIp(), port: PORT, fetch: route, websocket });
