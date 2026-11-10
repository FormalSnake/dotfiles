// The whole sidebar as T3 Code draws its threads: one card per tab (its space, title, branch,
// status), working tabs folded together below, settled tabs counted at the bottom.
// Icons come from the shipped workspace-chrome mod.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, panes, agents, run, theme, shared, setShared, setAgentOrder, window, layout, props } from "herdr";

const ICON = (name) => `mods/workspace-chrome/${name}.svg`;

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// Rail by width, as the shipped sidebar mods decide it, so their toggles agree.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

// The pane a tab is known by: its first agent, else its focused terminal, else its first one.
function leadPanes(all) {
  const leads = new Map();
  for (const p of all) {
    if (!p.terminal) continue;
    const cur = leads.get(p.tab);
    if (!cur || (!cur.program?.agent && (p.program?.agent || (!cur.focused && p.focused)))) leads.set(p.tab, p);
  }
  return leads;
}

// A named tab keeps its name; an unnamed one reads as what its lead program says it is doing.
function title(tab, lead) {
  const prog = lead?.program?.name;
  const live = clean(lead?.title);
  const telling = live && live !== prog && !/^[~/]|^[A-Za-z]:\\/.test(live) && !live.includes("@") && live.toLowerCase() !== lead?.program?.key;
  if (tab.named && tab.name !== prog) return tab.name;
  if (telling) return live;
  return prog && !lead?.program?.shell ? prog : `Tab ${tab.name}`;
}

function ago(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "now";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

// Two letters for a space: "formalspec" FO, "CanaryPulseDemo" CP, "herdr-app" HA.
function initials(name) {
  const words = (name || "?").replace(/([a-z])([A-Z])/g, "$1 $2").split(/[\s\-_.~/]+/).filter(Boolean);
  const two = words.length > 1 ? words[0][0] + words[1][0] : (words[0] ?? "?").slice(0, 2);
  return two.toUpperCase();
}

function hue(name, t) {
  let h = 0;
  for (const c of name || "") h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return t[`ansi${9 + (h % 6)}`] ?? t.accent;
}

function programIcon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

export default class Threads extends View {
  init(_props, cx) {
    // When each tab last changed, kept across restarts: changed_at is null until something moves.
    this.stamps = JSON.parse(localStorage.getItem("stamps") ?? "{}");
    this.open = JSON.parse(localStorage.getItem("open") ?? '{"working":true,"settled":false}');
    cx.timer.every(30000, (cx) => cx.notify());
  }

  stamp(tab) {
    const at = tab.changed_at ?? this.stamps[tab.id] ?? null;
    if (at && this.stamps[tab.id] !== at) {
      this.stamps[tab.id] = at;
      this.dirty = true;
    }
    return at;
  }

  toggle(key, cx) {
    this.open[key] = !this.open[key];
    localStorage.setItem("open", JSON.stringify(this.open));
    cx.notify();
  }

  iconButton(id, icon, tip, action) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6)
      .text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground)).tooltip(tip)
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click(action).child(svg(ICON(icon)).size(15));
  }

  badge(t, item, now) {
    const { tab } = item;
    const pill = (color, icon, text, spin = false) => h_flex().flex_none().gap(4).items_center().text_size(11.5).font_medium().text_color(color)
      .child(spin ? svg(ICON(icon)).size(12).flex_none().spin(900) : svg(ICON(icon)).size(12).flex_none())
      .child(text);
    if (tab.status === "working") return pill(t.accent, "spinner", `Working ${ago(now - (tab.working_since ?? item.at ?? now))}`, true);
    if (tab.status === "blocked") return pill(t.blocked, "clock", item.at ? `Waiting ${ago(now - item.at)}` : "Waiting");
    if (tab.status === "done") return pill(t.done, "circle-check", "Done");
    return div().flex_none().text_size(11.5).text_color(t.dim).child(item.at ? ago(now - item.at) : "");
  }

  chip(t, name, size = 18) {
    const c = hue(name, t);
    return div().size(size).flex_none().rounded(4).bg(c + "2e").text_color(c).text_size(size * 0.56).font_bold()
      .flex().items_center().justify_center().child(initials(name));
  }

  card(t, item, now) {
    const { tab, space, lead } = item;
    const remote = Boolean(space.machine);
    const branch = lead?.branch ?? space.branch;
    const pic = programIcon(lead?.program?.agent ? lead.program : null, 13, t.muted);
    const quiet = tab.status === "working" && !tab.active;
    return v_flex()
      .id(`th-${tab.id}`)
      .flex_none()
      .px(10)
      .py(8)
      .gap(3)
      .rounded(10)
      .cursor_pointer()
      .when(tab.active && space.active, (el) => el.bg(t.selected))
      .hover((s) => s.bg(t.hover))
      .on_hover((on, cx) => {
        if (on) this.hovered = tab.id;
        else if (this.hovered === tab.id) this.hovered = null;
        cx.notify();
      })
      .on_click(() => {
        run("space.select", { id: space.id });
        run("tab.select", { id: tab.id });
      })
      .child(h_flex().gap(7).items_center()
        .child(this.chip(t, space.name))
        .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(t.muted).child(space.name))
        .when(this.hovered === tab.id && !tab.settled, (el) => el.child(this.iconButton(`settle-${tab.id}`, "archive", "Settle", (_e, cx) => {
          cx.stop_propagation();
          run("tab.settle", { id: tab.id });
        }).size(20)))
        .when(this.hovered === tab.id && tab.settled, (el) => el.child(this.iconButton(`unsettle-${tab.id}`, "archive", "Bring back", (_e, cx) => {
          cx.stop_propagation();
          run("tab.unsettle", { id: tab.id });
        }).size(20)))
        .child(this.badge(t, item, now)))
      .child(div().truncate().text_size(13.5).font_medium().text_color(quiet || tab.settled ? t.muted : t.foreground).child(item.title))
      .child(h_flex().gap(6).items_center().text_size(11.5).text_color(t.dim)
        .child(h_flex().flex_1().min_w(0).gap(4).items_center()
          .when(Boolean(branch), (el) => el.child(svg(ICON("git-branch")).size(11).flex_none()).child(div().truncate().child(branch))))
        .child(svg(ICON(remote ? "server" : "monitor")).size(12).flex_none().tooltip(remote ? space.machine : "This computer"))
        .when(Boolean(pic), (el) => el.child(pic)));
  }

  section(t, key, label, count, cx) {
    const open = this.open[key];
    return h_flex()
      .id(`sec-${key}`)
      .flex_none()
      .h(30)
      .px(10)
      .mt(6)
      .gap(6)
      .items_center()
      .text_size(12)
      .font_medium()
      .text_color(t.muted)
      .cursor_pointer()
      .hover((s) => s.text_color(t.foreground))
      .on_click((_e, cx) => this.toggle(key, cx))
      .child(div().flex_1().child(label))
      .child(div().text_color(t.dim).child(String(count)))
      .child(svg(ICON(open ? "chevron-down" : "chevron-right")).size(12).flex_none().text_color(t.dim));
  }

  rail(t, items) {
    return v_flex().size_full().bg(t.chrome).items_center().pt(window()?.platform === "macos" ? 40 : 10).gap(6)
      .child(this.iconButton("sidebar-toggle", "sidebar", "Show sidebar", toggleSidebar))
      .child(v_flex().id("rail").flex_1().min_h(0).gap(6).items_center().overflow_y_scrollbar()
        .children(items.map(({ tab, space }) => div().id(`rail-${tab.id}`).relative().p(3).rounded(6)
          .when(tab.active && space.active, (el) => el.bg(t.selected))
          .hover((s) => s.bg(t.hover)).tooltip(`${space.name}: ${tab.name}`)
          .on_click(() => { run("space.select", { id: space.id }); run("tab.select", { id: tab.id }); })
          .child(this.chip(t, space.name, 22))
          .when(Boolean(tab.status && tab.status !== "idle"), (el) => el.child(div().absolute().top(1).right(1).size(7).rounded_full().bg(t[tab.status] ?? t.dim))))));
  }

  render(cx) {
    const t = theme();
    const now = Date.now();
    const leads = leadPanes(panes());
    this.dirty = false;
    const all = spaces().flatMap((space) => space.tabs.map((tab) => {
      const lead = leads.get(tab.id);
      return { tab, space, lead, title: title(tab, lead), at: this.stamp(tab) };
    }));
    if (this.dirty) localStorage.setItem("stamps", JSON.stringify(this.stamps));

    const recent = (a, b) => (b.at ?? 0) - (a.at ?? 0);
    const live = all.filter((i) => !i.tab.settled);
    const top = live.filter((i) => i.tab.status !== "working").sort(recent);
    const working = live.filter((i) => i.tab.status === "working").sort((a, b) => (a.tab.working_since ?? a.at ?? now) - (b.tab.working_since ?? b.at ?? now));
    const settled = all.filter((i) => i.tab.settled).sort(recent);

    // agent.next / agent.prev walk the cards top to bottom.
    const order = [...top, ...working, ...settled].map((i) => i.tab.id);
    const rank = new Map(order.map((id, n) => [id, n]));
    setAgentOrder(agents().slice().sort((a, b) => (rank.get(a.tab) ?? 1e9) - (rank.get(b.tab) ?? 1e9)).map((a) => a.address));

    const mac = window()?.platform === "macos" && !window()?.fullscreen;
    const header = h_flex().id("th-header").flex_none().size_full().bg(t.chrome).pl(mac ? 76 : 10).pr(10).gap(8).items_center()
      .child(this.iconButton("sidebar-toggle", "sidebar", "Hide sidebar", toggleSidebar))
      .child(div().flex_1().font_semibold().text_size(14).text_color(t.foreground).child("Herdr"));
    // The layout's header block drags the window; this copy draws only the bar.
    if (props()?.header) return narrow() ? h_flex().size_full().bg(t.chrome) : header;
    if (narrow()) return this.rail(t, [...top, ...working]);

    const search = h_flex().flex_none().h(34).mx(8).px(8).gap(8).items_center()
      .child(h_flex().id("th-search").flex_1().h_full().gap(8).items_center().rounded(8).text_color(t.muted).cursor_pointer()
        .hover((s) => s.text_color(t.foreground))
        .on_click(() => run("mod.open", { name: "picker" }))
        .child(svg(ICON("search")).size(15).flex_none())
        .child(div().text_size(13.5).child("Search")))
      .child(this.iconButton("th-new-space", "folder-plus", "New space", () => run("space.new")))
      .child(this.iconButton("th-new-tab", "square-pen", "New tab", () => run("tab.new")));

    const list = v_flex().id("th-list").flex_1().min_h(0).px(8).pt(4).gap(2).overflow_y_scrollbar()
      .children(top.map((i) => this.card(t, i, now)))
      .when(top.length === 0 && working.length === 0, (el) => el.child(div().px(10).py(8).text_size(12.5).text_color(t.dim).child("No tabs yet. Start one with the pen above.")));

    const below = v_flex().flex_none().px(8).gap(2)
      .when(working.length > 0, (el) => el.child(this.section(t, "working", "Working", working.length, cx))
        .when(this.open.working, (el) => el.children(working.map((i) => this.card(t, i, now)))))
      .when(settled.length > 0, (el) => el.child(this.section(t, "settled", "Settled", settled.length, cx))
        .when(this.open.settled, (el) => el.child(v_flex().id("th-settled").max_h(320).gap(2).overflow_y_scrollbar()
          .children(settled.map((i) => this.card(t, i, now))))));

    const footer = h_flex().flex_none().h(44).px(10).gap(2).items_center()
      .child(this.iconButton("th-settings", "settings", "Settings", () => run("app.settings")))
      .child(this.iconButton("th-machine", "server", "Add machine", () => run("mod.open", { name: "machine-add" })))
      .child(this.iconButton("th-layout", "layers", "Switch layout", () => run("layout.switch")))
      .child(div().flex_1())
      .child(div().id("th-new").size(30).flex_none().rounded_full().border(1).border_color(t.input).flex().items_center().justify_center()
        .text_color(t.foreground).hover((s) => s.bg(t.hover)).tooltip("New tab")
        .on_click(() => run("tab.new")).child(svg(ICON("plus")).size(15)));

    return v_flex().id("root").size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(search).child(list).child(below).child(footer);
  }
}
