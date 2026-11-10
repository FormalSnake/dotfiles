// A browser or simulator streamed from a machine's herdr-view relay (port 7650), as T3 Code's
// preview does: the browser is the headless Chromium agents on that machine drive over CDP, the
// simulator is serve-sim's stream of the booted device. props: { kind: "browser" | "sim", machine }.
//
// Frames go to frames/<copy>/ under the app home, one file per frame: image() caches by path, and
// a file written inside mods/ reloads the mod.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { WebSocket } from "websocket";
import { Buffer } from "buffer";
import * as fs from "fs/promises";
import { props, theme, hc, appHome } from "herdr";

const PORT = 7650;
const ICON = (name) => (["globe", "smartphone", "rotate-cw", "house"].includes(name) ? `mods/viewer/${name}.svg` : `mods/workspace-chrome/${name}.svg`);

// CDP key codes for the keys that type no character.
const KEYS = {
  enter: [13, "Enter", "\r"], backspace: [8, "Backspace"], tab: [9, "Tab"], escape: [27, "Escape"],
  delete: [46, "Delete"], left: [37, "ArrowLeft"], up: [38, "ArrowUp"], right: [39, "ArrowRight"],
  down: [40, "ArrowDown"], home: [36, "Home"], end: [35, "End"], pageup: [33, "PageUp"], pagedown: [34, "PageDown"],
};
const cdpModifiers = (m) => (m.alt ? 1 : 0) | (m.control ? 2 : 0) | (m.platform ? 4 : 0) | (m.shift ? 8 : 0);

// USB HID usages (page 7) for the simulator keyboard.
function hidUsage(key) {
  if (/^[a-z]$/.test(key)) return 4 + key.charCodeAt(0) - 97;
  if (/^[1-9]$/.test(key)) return 30 + Number(key) - 1;
  const named = { "0": 39, enter: 40, escape: 41, backspace: 42, tab: 43, space: 44, " ": 44, "-": 45, "=": 46, "[": 47, "]": 48,
    "\\": 49, ";": 51, "'": 52, "`": 53, ",": 54, ".": 55, "/": 56, right: 79, left: 80, down: 81, up: 82 };
  return named[key] ?? null;
}

let copies = 0;

export default class Viewer extends View {
  init(_props, cx) {
    this.kind = props()?.kind === "sim" ? "sim" : "browser";
    this.machine = props()?.machine ?? null;
    this.dir = `frames/viewer-${Date.now().toString(36)}-${copies++}`;
    this.frame = null;
    this.prev = null;
    this.n = 0;
    this.status = "Connecting…";
    this.size = null;
    this.handle = cx.focus_handle();
    this.id = 0;
    this.waiting = new Map();
    this.url = "";
    this.input = InputState.new({ placeholder: "Enter a URL" });
    this.input.on("submit", (_e, cx) => this.navigate(this.input.value(), cx));
    cx.spawn(async (cx) => {
      try {
        await this.sweep();
        await fs.mkdir(`${appHome()}/${this.dir}`, { recursive: true });
        this.base = await this.relay();
        await (this.kind === "browser" ? this.openBrowser(cx) : this.openSim(cx));
      } catch (e) {
        this.status = String(e?.message ?? e);
        cx.notify();
      }
    });
  }

  // close() gets 250 ms and can lose that race, so each start clears what dead copies left.
  // Live copies of this run list their folders on the shared module instance.
  async sweep() {
    const live = (globalThis.__herdrViewers ??= new Set());
    live.add(this.dir);
    const root = `${appHome()}/frames`;
    for (const d of await fs.readdir(root).catch(() => [])) {
      if (!d.startsWith("viewer-") || live.has(`frames/${d}`)) continue;
      for (const f of await fs.readdir(`${root}/${d}`).catch(() => [])) await fs.unlink(`${root}/${d}/${f}`).catch(() => {});
      await fs.rmdir(`${root}/${d}`).catch(() => {});
    }
  }

  async close() {
    this.closed = true;
    globalThis.__herdrViewers?.delete(this.dir);
    await Promise.all([this.ws?.close(), this.input_ws?.close()].filter(Boolean)).catch(() => {});
    for (const f of [this.frame, this.prev]) if (f) await fs.unlink(`${appHome()}/${f}`).catch(() => {});
    await fs.rmdir(`${appHome()}/${this.dir}`).catch(() => {});
  }

  // This computer's relay listens on loopback; another machine's on its Tailscale name.
  async relay() {
    if (!this.machine) return `127.0.0.1:${PORT}`;
    const out = JSON.parse((await hc(["machine", "ls", "--json"])).stdout);
    const m = out.machines.find((x) => x.name === this.machine);
    return `${m?.host ?? this.machine}:${PORT}`;
  }

  async show(bytes, cx) {
    const rel = `${this.dir}/${this.n++}.jpg`;
    await fs.writeFile(`${appHome()}/${rel}`, bytes);
    // The previous frame stays drawn under the new one while it decodes.
    const gone = this.prev;
    this.prev = this.frame;
    this.frame = rel;
    this.status = null;
    cx.notify();
    if (gone) await fs.unlink(`${appHome()}/${gone}`).catch(() => {});
  }

  // Browser

  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve) => {
      this.waiting.set(id, resolve);
      this.ws?.write(JSON.stringify({ id, method, params })).catch(() => {});
    });
  }

  async openBrowser(cx) {
    const res = await fetch(`http://${this.base}/browser/pages`);
    const pages = await res.json();
    if (!res.ok || !Array.isArray(pages)) throw new Error(pages?.error ?? "no browser on " + (this.machine ?? "this computer"));
    const page = props()?.page ?? pages[0].id;
    this.url = pages.find((p) => p.id === page)?.url ?? "";
    this.input.set_value(this.url === "about:blank" ? "" : this.url);
    this.ws = await WebSocket.connect(`ws://${this.base}/browser/page/${page}`);
    cx.notify();
    cx.spawn(async (cx) => {
      while (!this.closed) {
        let msg;
        try { msg = JSON.parse(await this.ws.read()); } catch { break; }
        if (msg.id && this.waiting.has(msg.id)) {
          this.waiting.get(msg.id)(msg.result ?? msg);
          this.waiting.delete(msg.id);
        } else if (msg.method === "Page.screencastFrame") {
          this.ws.write(JSON.stringify({ id: ++this.id, method: "Page.screencastFrameAck", params: { sessionId: msg.params.sessionId } })).catch(() => {});
          await this.show(Buffer.from(msg.params.data, "base64"), cx);
        } else if (msg.method === "Page.frameNavigated" && !msg.params.frame.parentId) {
          this.url = msg.params.frame.url;
          this.input.set_value(this.url === "about:blank" ? "" : this.url);
          cx.notify();
        }
      }
      this.status = "Disconnected";
      cx.notify();
    });
    await this.send("Page.enable");
    if (this.size) await this.fit();
  }

  // The page lays out at the pane's size, so frame pixels map to pane points one to one.
  async fit() {
    if (!this.ws || !this.size) return;
    const w = Math.max(200, Math.round(this.size.width));
    const h = Math.max(200, Math.round(this.size.height));
    await this.send("Emulation.setDeviceMetricsOverride", { width: w, height: h, deviceScaleFactor: 1, mobile: false });
    await this.send("Page.startScreencast", { format: "jpeg", quality: 70, maxWidth: w * 2, maxHeight: h * 2 });
  }

  navigate(text, cx) {
    let url = text.trim();
    if (!url) return;
    if (!/^[a-z]+:/i.test(url)) url = /^[\w-]+(\.[\w-]+)+|^localhost|^\d+\.\d+\.\d+\.\d+/.test(url) ? `http://${url}` : `https://duckduckgo.com/?q=${encodeURIComponent(url)}`;
    this.send("Page.navigate", { url });
    this.handle.focus();
    cx?.notify();
  }

  async history(step) {
    const h = await this.send("Page.getNavigationHistory");
    const entry = h.entries?.[h.currentIndex + step];
    if (entry) this.send("Page.navigateToHistoryEntry", { entryId: entry.id });
  }

  mouse(type, e, button = "left") {
    const p = e.local_position;
    if (!p) return;
    this.send("Input.dispatchMouseEvent", { type, x: p.x, y: p.y, button: type === "mouseMoved" ? (this.down ? "left" : "none") : button, clickCount: e.click_count ?? 1, modifiers: cdpModifiers(e.modifiers) });
  }

  browserKey(e) {
    const mods = cdpModifiers(e.modifiers);
    const named = KEYS[e.key];
    const typed = e.key_char && !e.modifiers.control && !e.modifiers.platform ? e.key_char : null;
    if (named) {
      const [code, key, text] = named;
      this.send("Input.dispatchKeyEvent", { type: "keyDown", key, windowsVirtualKeyCode: code, modifiers: mods, ...(text ? { text } : {}) });
      this.send("Input.dispatchKeyEvent", { type: "keyUp", key, windowsVirtualKeyCode: code, modifiers: mods });
    } else if (typed) {
      this.send("Input.dispatchKeyEvent", { type: "keyDown", key: typed, text: typed, modifiers: mods });
      this.send("Input.dispatchKeyEvent", { type: "keyUp", key: typed, modifiers: mods });
    } else if (e.key.length === 1) {
      const code = e.key.toUpperCase().charCodeAt(0);
      this.send("Input.dispatchKeyEvent", { type: "keyDown", key: e.key, windowsVirtualKeyCode: code, modifiers: mods });
      this.send("Input.dispatchKeyEvent", { type: "keyUp", key: e.key, windowsVirtualKeyCode: code, modifiers: mods });
    }
  }

  // Simulator

  async openSim(cx) {
    const info = await (await fetch(`http://${this.base}/sim/info`)).json();
    if (info.error) throw new Error(info.error);
    this.sim = info;
    if (!info.device) {
      this.status = null;
      cx.notify();
      return;
    }
    this.input_ws = await WebSocket.connect(`ws://${this.base}/sim/input`);
    // The helper pushes config on this socket; read it so it doesn't back up.
    cx.spawn(async () => { while (!this.closed) { try { await this.input_ws.read(); } catch { break; } } });
    this.ws = await WebSocket.connect(`ws://${this.base}/sim/frames`);
    cx.notify();
    cx.spawn(async (cx) => {
      while (!this.closed) {
        let msg;
        try { msg = await this.ws.read(); } catch { break; }
        if (typeof msg !== "string") await this.show(msg, cx);
      }
      this.status = "Disconnected";
      cx.notify();
    });
  }

  async boot(udid, cx) {
    this.status = "Booting…";
    cx.notify();
    await fetch(`http://${this.base}/sim/boot?udid=${udid}`, { method: "POST" });
    await this.openSim(cx).catch((e) => { this.status = String(e?.message ?? e); });
    cx.notify();
  }

  simSend(tag, body) {
    const bytes = Buffer.from(JSON.stringify(body), "utf8");
    const out = new Uint8Array(bytes.length + 1);
    out[0] = tag;
    out.set(bytes, 1);
    this.input_ws?.write(out).catch(() => {});
  }

  // The device screen as drawn: fitted into the pane, centered.
  screen() {
    const c = this.sim?.config;
    if (!c || !this.size) return null;
    const scale = Math.min(this.size.width / c.width, this.size.height / c.height);
    const w = c.width * scale;
    const h = c.height * scale;
    return { x: (this.size.width - w) / 2, y: (this.size.height - h) / 2, w, h };
  }

  touch(type, e) {
    const s = this.screen();
    const p = e.local_position;
    if (!s || !p) return;
    const x = (p.x - s.x) / s.w;
    const y = (p.y - s.y) / s.h;
    if (type === "begin" && (x < 0 || y < 0 || x > 1 || y > 1)) return;
    this.simSend(0x03, { type, x: Math.min(1, Math.max(0, x)), y: Math.min(1, Math.max(0, y)) });
  }

  simKey(e) {
    const key = e.key_char && e.key_char.length === 1 ? e.key_char.toLowerCase() : e.key;
    const usage = hidUsage(key);
    if (usage == null) return;
    const shift = e.modifiers.shift || (e.key_char && e.key_char !== e.key_char.toLowerCase());
    if (shift) this.simSend(0x06, { type: "down", usage: 225 });
    this.simSend(0x06, { type: "down", usage });
    this.simSend(0x06, { type: "up", usage });
    if (shift) this.simSend(0x06, { type: "up", usage: 225 });
  }

  // UI

  button(id, icon, tip, action) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.muted)
      .hover((s) => s.bg(t.hover).text_color(t.foreground)).tooltip(tip).on_click(action).child(svg(ICON(icon)).size(15));
  }

  toolbar(t) {
    const where = this.machine ?? "this computer";
    const bar = h_flex().flex_none().h(38).px(8).gap(4).items_center().border_b(1).border_color(t.border).bg(t.chrome);
    if (this.kind === "browser") {
      return bar
        .child(this.button("v-back", "chevron-left", "Back", () => this.history(-1)))
        .child(this.button("v-forward", "chevron-right", "Forward", () => this.history(1)))
        .child(this.button("v-reload", "rotate-cw", "Reload", () => this.send("Page.reload")))
        .child(h_flex().flex_1().h(26).mx(4).px(10).gap(8).items_center().rounded(7).bg(t.raised).border(1).border_color(t.border)
          .child(svg(ICON("globe")).size(13).flex_none().text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.5).text_color(t.foreground)))
        .child(div().flex_none().text_size(11).text_color(t.dim).child(where));
    }
    return bar
      .child(svg(ICON("smartphone")).size(14).flex_none().text_color(t.muted))
      .child(div().flex_1().truncate().text_size(12.5).text_color(t.foreground).child(this.sim?.name ?? "Simulator"))
      .child(div().flex_none().text_size(11).text_color(t.dim).mr(4).child(where))
      .child(this.button("v-home", "house", "Home", () => this.simSend(0x04, { button: "home" })));
  }

  devices(t) {
    const list = (this.sim?.devices ?? []).slice(0, 12);
    return v_flex().size_full().p(16).gap(6).text_size(13)
      .child(div().text_color(t.muted).child("No simulator is booted. Boot one:"))
      .children(list.map((d) => h_flex().id(`boot-${d.udid}`).h(30).px(10).rounded(8).items_center().gap(8).cursor_pointer()
        .text_color(t.foreground).hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => this.boot(d.udid, cx))
        .child(svg(ICON("smartphone")).size(14).text_color(t.muted)).child(d.name)));
  }

  view(t) {
    const frames = [this.prev, this.frame].filter(Boolean);
    const s = this.kind === "sim" ? this.screen() : this.size ? { x: 0, y: 0, w: this.size.width, h: this.size.height } : null;
    const area = div().id("v-view").flex_1().min_h(0).relative().overflow_hidden().bg(this.kind === "sim" ? t.canvas : "#ffffff")
      .track_focus(this.handle)
      .on_size_change((size, cx) => {
        this.size = size;
        if (this.kind === "browser") this.fit();
        cx.notify();
      })
      .when(Boolean(s), (el) => el.children(frames.map((f) => image(f).absolute().left(s.x).top(s.y).w(s.w).h(s.h))))
      .when(Boolean(this.status), (el) => el.child(div().absolute().left(0).top(0).size_full().flex().items_center().justify_center()
        .bg(t.canvas).text_size(12.5).text_color(t.dim).child(this.status)));
    if (this.kind === "browser") {
      return area
        .on_mouse_down("left", (e) => { this.handle.focus(); this.down = true; this.mouse("mousePressed", e); })
        .on_mouse_up("left", (e) => { this.down = false; this.mouse("mouseReleased", e); })
        .on_mouse_down("right", (e) => this.mouse("mousePressed", e, "right"))
        .on_mouse_up("right", (e) => this.mouse("mouseReleased", e, "right"))
        .on_mouse_move((e) => this.mouse("mouseMoved", e))
        .on_scroll_wheel((e) => e.local_position && this.send("Input.dispatchMouseEvent", { type: "mouseWheel", x: e.local_position.x, y: e.local_position.y, deltaX: -e.delta.x, deltaY: -e.delta.y }))
        .on_key_down((e) => this.browserKey(e));
    }
    return area
      .on_mouse_down("left", (e) => { this.handle.focus(); this.down = true; this.touch("begin", e); })
      .on_mouse_up("left", (e) => { if (this.down) this.touch("end", e); this.down = false; })
      .on_mouse_move((e) => { if (this.down) this.touch("move", e); })
      .on_scroll_wheel((e) => {
        const sc = this.screen();
        const p = e.local_position;
        if (!sc || !p) return;
        this.simSend(0x0b, { dx: -e.delta.x / sc.w, dy: -e.delta.y / sc.h, x: (p.x - sc.x) / sc.w, y: (p.y - sc.y) / sc.h });
      })
      .on_key_down((e) => this.simKey(e));
  }

  render() {
    const t = theme();
    const body = this.kind === "sim" && this.sim && !this.sim.device ? this.devices(t) : this.view(t);
    return v_flex().id("root").size_full().min_h(0).bg(t.background).child(this.toolbar(t)).child(body);
  }
}
