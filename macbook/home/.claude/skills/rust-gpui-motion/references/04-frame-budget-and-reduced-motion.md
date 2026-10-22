# Frame Budget & Reduced Motion in gpui

> Target file: `references/04-frame-budget-and-reduced-motion.md`. Companion to the gpui motion docs. All code is gpui 0.2.x (Rust, Metal), grounded in `pd-console/src/{app,main,palette,mux}.rs`.

The web `prefers-reduced-motion` reflex — `@media` query, `transition: none`, done — does not port. In gpui there is no compositor thread you can offload to, no CSS engine that quietly drops a keyframe. A `.repeat()` animation is a **standing invitation to re-render the window forever**, and every re-render walks your *entire* element tree top-to-bottom. The frame budget is not a styling concern here; it is an architecture concern. This doc ties that cost to the real per-frame work in this codebase, bounds it, and treats reduced-motion as a **design branch that preserves orientation**, not a kill switch.

---

## 1. The gpui render model: dirty-or-dark, and what `.repeat()` does to it

gpui is a hybrid immediate/retained framework. The load-bearing fact for motion:

> GPUI uses a dirty flag system. *"if dirty.get() { ... cx.draw(); cx.present() }"* — when nothing is dirty, the full render is skipped. Frame cadence comes from the `PlatformWindow::on_request_frame` callback, which abstracts **CADisplayLink** (the macOS vsync clock). — [Zed, *Optimizing the Metal pipeline to maintain 120 FPS*](https://zed.dev/blog/120fps)

So a static window costs ~nothing: no dirty flag, no draw. Two things flip the dirty bit:

1. **`cx.notify()`** — explicit "this view changed, re-render it." Used 9 times in `app.rs` (theme flip `:122/500`, focus moves `:638`, key handling `:733/811/896`) and on every data refresh in `main.rs:313`.
2. **A live `with_animation` whose `Animation` has not finished.** This is the trap. `Animation::new(...).repeat()` *never finishes*, so it re-arms `on_request_frame` every frame, holding the window dirty at the display's full cadence (60 / 120 Hz) **for the lifetime of the element**.

Here is the one looping animation in the console — the focused-pane "presence beacon" (`app.rs:658-666`):

```rust
// app.rs — the focused pane's dot "breathes" via a looping with_animation.
dot.with_animation(
    SharedString::from(format!("dot-pulse-{id}")),
    Animation::new(Duration::from_millis(2400))
        .repeat()                                  // ← never terminates
        .with_easing(pulsating_between(0.55, 1.0)),
    |el, delta| el.opacity(delta),                 // ← the only per-frame mutation
)
```

The `|el, delta|` closure is the **delta closure**: gpui hands you a `delta` in `[0,1]` (post-easing) and you return a mutated element. Note what it can and cannot touch.

> **Decision Point — what `delta` is allowed to drive.** gpui 0.2.x has **no fluent transform** (no `scale`, `translate`, `rotate` on `Div`). The delta closure can only feed properties that exist: `.opacity(delta)`, an interpolated `Hsla` into `.bg()`/`.text_color()`, an interpolated `BoxShadow` alpha/blur into `.shadow()`, or an animated **layout fraction** (`.w(relative(delta))`, `.flex_grow`). "Lift / slide / zoom / spring" are all *spelled* in those four nouns. The console's `motion` module (`app.rs:147-178`) is exactly this vocabulary: `glow()` builds a `BoxShadow` halo, `hard_offset()` builds a neobrutalist drop-shadow "lift," and `swoosh()` is a quintic ease-out curve — no transform anywhere, by necessity. The file even documents it: *"gpui 0.2.2 has no fluent transform, so 'lift/glow/spring' reads through hover color + box-shadow ... and with_animation."*

### Why "re-render" is expensive here specifically

When the beacon holds the window dirty, gpui does **not** re-run only the dot. It re-runs the **whole view's `render`** — every `render_leaf`, every pane's block builder — on every frame. In this app the render path is cheap *today* because the heavy lifting (daemon fetches, JSON parse) was deliberately pushed off the render thread:

- **Data is fetched on a background thread every 2s** and pushed over an `mpsc` channel (`main.rs:163`, producer thread).
- **The foreground consumer drains it every 500ms and `cx.notify()`s** (`main.rs:305-318`).

That architecture is the only reason a 120 Hz beacon is survivable: `render` is pure layout over already-fetched `Vec<Block>`. **The moment any per-frame disk read or daemon poll sneaks into a `render` method, a single `.repeat()` animation multiplies that cost by your refresh rate** — 120 reads/sec for one breathing dot.

> **Tie to the real per-frame-disk-read cost.** `main.rs:76-98` defines `FsAssets`, whose `load()` does `std::fs::read(&full)` and `list()` does `std::fs::read_dir`. gpui's `AssetSource` is consulted during paint for images/SVGs. Today that is fine because assets are content-hash cached by gpui after first load. But if you ever resolve an asset path *inside a render closure that also hosts a `.repeat()` animation* — e.g. an animated maritime flag SVG whose path is recomputed each frame — you convert a one-time `fs::read` into a **per-vsync syscall storm**. The detection rule below catches it.

---

## 2. Bounding the budget

Three escalating tactics, cheapest first.

### 2a. Prefer one-shot over `.repeat()`

Most "motion" is a *transition*, not a *loop*. A one-shot `Animation::new(dur)` (no `.repeat()`) marks the window dirty only until `delta` reaches 1.0, then **lets the dirty bit clear and the display downclock**. The console's `swoosh`/`RISE_MS` curve (`app.rs:150-155`) is built for exactly this — a pane rising into place once.

```rust
// One-shot: dirty for 500ms, then silent. The window can go back to sleep.
el.with_animation(
    "pane-rise".into(),
    Animation::new(Duration::from_millis(motion::RISE_MS))
        .with_easing(motion::swoosh),
    |el, t| el.opacity(t),
)
```

### 2b. Hover/press cues need NO animation at all

The cheapest motion is **no `with_animation`**: gpui re-skins on hover via `.hover(|s| ...)` and on state via `.when(cond, ...)`, which only dirty the window on the *event*, not every frame. The console does all its "lift / glow / press" this way (`app.rs:627-635, 785-789, 919-929`):

```rust
.when(is_focused, |s| s.shadow(motion::glow(theme.accent, 0.45, 16.0, 1.0)))
.hover(|h| h.bg(rgb(t.raised)).shadow(motion::hard_offset(t.sunken, 0.0, 2.0)))
```

This is the single biggest budget win: **an interaction cue is a state change, not a timeline.** Reserve `with_animation` for motion the user did *not* trigger (the breathing beacon, a loading shimmer).

### 2c. Cap concurrent loops and gate them on visibility

A `.repeat()` loop on **every** pane's dot would mean N windows-worth of vsync pressure. The console caps it structurally: only the **focused** pane breathes (`app.rs:658` — `if is_focused { dot.with_animation(...) } else { dot.into_any_element() }`). Idle panes are static. That is the right pattern: **at most one or two continuous loops on screen, and only on the element that currently has the user's attention.**

> **Decision Point — loop budget.** Treat continuous `.repeat()` animations like a scarce resource: target **≤2 on-screen at once**. Each one pins the window to full refresh. If you need many "alive" indicators, drive them from a **single** shared clock value in your view state that you bump on a coarse timer (e.g. the existing 500ms consumer tick in `main.rs:308`) and read in `render` — that gives you a 2 Hz pulse for the cost of the notify you already pay, instead of 120 Hz per dot.

---

## 3. Reading macOS reduce-motion + an env/flag gate

There is no `useReducedMotion()` hook in gpui. You read the OS preference yourself and thread it through your view state.

### 3a. The OS signal

macOS exposes **`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`** (Settings → Accessibility → Display → Reduce Motion). From Rust you reach it via `objc2` / `objc2-app-kit`:

```rust
// reduced_motion.rs — read once at startup; cache in view state.
#[cfg(target_os = "macos")]
fn os_reduce_motion() -> bool {
    use objc2_app_kit::NSWorkspace;
    use objc2_foundation::MainThreadMarker;
    // Must run on the main thread — call during view construction, not bg thread.
    let _mtm = MainThreadMarker::new().expect("reduce-motion read off main thread");
    unsafe { NSWorkspace::sharedWorkspace().accessibilityDisplayShouldReduceMotion() }
}

#[cfg(not(target_os = "macos"))]
fn os_reduce_motion() -> bool { false }
```

### 3b. The env/flag override (mirrors the theme pattern already in this repo)

The console already seeds theme from an env var before the window opens — `app::init_theme_from_env()` reading `PD_CONSOLE_THEME` (`main.rs:102`, `palette.rs:15`). **Mirror that exact pattern for motion** so screenshots, CI, and motion-sensitive users get a deterministic, testable switch that does not depend on the host's Accessibility settings:

```rust
// app.rs — resolve once, store on the view (like ThemeMode).
#[derive(Clone, Copy, PartialEq)]
pub enum MotionMode { Full, Reduced }

impl MotionMode {
    pub fn resolve() -> Self {
        match std::env::var("PD_CONSOLE_MOTION").as_deref() {
            Ok("reduced") | Ok("off") => MotionMode::Reduced, // explicit override wins
            Ok("full")                => MotionMode::Full,
            _ if os_reduce_motion()   => MotionMode::Reduced, // fall back to the OS
            _                          => MotionMode::Full,
        }
    }
    pub fn reduced(self) -> bool { matches!(self, MotionMode::Reduced) }
}
```

Store `motion: MotionMode` on `ConsoleView` next to the theme, resolve it in the constructor, and read it wherever you'd reach for `with_animation`. Env beats OS so the screenshot tooling (`--pane`, `main.rs:114`) can freeze motion regardless of the running machine.

---

## 4. Reduced motion is a BRANCH, not silence

The skill rule, mapped to gpui: *"The reduced branch removes animation but also removes orientation cues … Replace travel with smaller fades, instant reflow, or static state hints instead of deleting feedback entirely."* (animation-system-architect, Failure Mode 3).

In gpui that means: **when `motion.reduced()`, you still emit the element — you just emit its resolved end-state, or a cross-fade, instead of the timeline.** The orientation cue (which pane has focus? is this thing alive?) must survive.

### The presence beacon, branched

```rust
let dot = div()
    .text_color(rgb(if is_focused { theme.accent } else { theme.line }))
    .text_size(px(13.0))
    .child(if is_focused { "●" } else { "○" });

if is_focused && !self.motion.reduced() {
    // FULL: breathe (the continuous loop)
    dot.with_animation(
        format!("dot-pulse-{id}").into(),
        Animation::new(Duration::from_millis(2400))
            .repeat()
            .with_easing(pulsating_between(0.55, 1.0)),
        |el, delta| el.opacity(delta),
    ).into_any_element()
} else if is_focused {
    // REDUCED: orientation preserved, motion gone. The dot is solid + a static
    // glow halo so "this pane has the wheel" still reads — we did NOT just
    // delete the only focus signal. (cross-fade-on-focus-change, not travel.)
    dot.opacity(1.0)
       .shadow(motion::glow(theme.accent, 0.40, 10.0, 0.0))
       .into_any_element()
} else {
    dot.into_any_element()
}
```

The reduced branch keeps the *meaning* (focused = bright + haloed) and drops only the *oscillation*. That is the whole discipline: **opacity 0.55↔1.0 sweep → static opacity 1.0; travel → cross-fade.**

### Pane-rise, branched

A one-shot rise (§2a) under reduced motion becomes an **instant cross-fade or instant placement**, not a 500ms slide:

```rust
if self.motion.reduced() {
    el.into_any_element()                     // already at end-state; no timeline
} else {
    el.with_animation("pane-rise".into(),
        Animation::new(Duration::from_millis(motion::RISE_MS)).with_easing(motion::swoosh),
        |el, t| el.opacity(t),
    ).into_any_element()
}
```

> **Decision Point — fade vs. instant.** Keep a *short* (≤120ms) opacity cross-fade even in reduced mode when an element appears/disappears, because a hard pop can itself be disorienting; reserve fully-instant for *travel*-type motion (slides, rises). The web rubric's "smaller fades, not deletion" maps directly: reduced ≠ zero, reduced = *non-vestibular*.

---

## 5. Before / After

**Before** — a naive port of a web `prefers-reduced-motion` instinct: animate everything, kill it all under reduced motion, and (the real sin) resolve an asset path inside the animated render closure.

```rust
// ❌ Every pane breathes — N continuous loops pinning the window to 120Hz.
// ❌ Asset path recomputed + read inside a frame-cadence closure.
// ❌ Reduced motion = the dot vanishes (focus cue destroyed).
for pane in panes {
    let flag = self.assets.load(&format!("flags/{}.svg", pane.flag))?; // fs::read PER FRAME
    let dot = svg().path(flag);
    if reduced {
        // nothing — no dot at all
    } else {
        dot.with_animation("pulse".into(),
            Animation::new(Duration::from_millis(1000)).repeat()
                .with_easing(pulsating_between(0.0, 1.0)),  // 0.0 → invisible half the time
            |el, d| el.opacity(d))
    }
}
```

Symptoms: fans spin, battery drains, `Activity Monitor` shows pd-console pinned at the display's refresh rate while *idle*; under reduce-motion the user can no longer tell which pane is focused.

**After** — one loop, on the focused pane only; assets resolved outside the timeline; reduced motion preserves orientation.

```rust
// ✅ Resolve asset ONCE (cached by gpui's AssetSource thereafter), outside the closure.
let flag = self.flag_handle(pane.flag); // memoized SharedString path, no per-frame fs::read
let dot = svg().path(flag);

if is_focused && !self.motion.reduced() {
    dot.with_animation(format!("pulse-{}", pane.id).into(),
        Animation::new(Duration::from_millis(2400)).repeat()
            .with_easing(pulsating_between(0.55, 1.0)),   // floor 0.55 — never disappears
        |el, d| el.opacity(d))
        .into_any_element()
} else if is_focused {
    dot.opacity(1.0).shadow(motion::glow(theme.accent, 0.40, 10.0, 0.0)).into_any_element()
} else {
    dot.into_any_element()  // idle panes static — no dirty bit
}
```

Net: idle window goes dark (zero frames), exactly one loop when focused, focus always legible, no per-frame syscall.

---

## 6. Profiling gpui frames

You cannot open Chrome DevTools here. Use these:

- **`Activity Monitor` / `powermetrics`.** The blunt instrument: a *correct* idle gpui window uses ~0% CPU and lets the GPU downclock. If pd-console shows steady CPU/GPU while you are not touching it, **something is holding the window dirty** — almost always a stray `.repeat()`. `sudo powermetrics --samplers gpu_power -i 1000` shows whether the display is being driven at idle.
- **`PD_CONSOLE_MOTION=reduced` A/B.** Launch once full, once reduced, and diff the idle CPU. A large delta is your continuous-loop bill, itemized.
- **Metal HUD.** `export MTL_HUD_ENABLED=1` before launching shows a live FPS/frame-time overlay drawn by the driver. Watch it while *not* interacting: it should read 0–1 fps at idle and only climb during input. Sustained high fps at idle = a leaked loop.
- **Xcode → Debug → GPU Frame Capture / Instruments (Metal System Trace).** Attach to the running pd-console for a per-frame breakdown of draw-call count and GPU time. Use it to confirm a `render` pass isn't doing layout work proportional to off-screen data.
- **Frame cadence reminder.** Zed renders *repeated frames for 1s after the last input* to stay responsive ([120fps post](https://zed.dev/blog/120fps)). So expect ~1s of post-input frames even in a correct app — measure **idle**, not the second right after a keypress.
- **A `notify` counter (dev build).** Wrap `cx.notify()` behind a `#[cfg(debug_assertions)]` `AtomicU64::fetch_add` and log the rate. A correct idle console notifies ~2×/sec (the 500ms consumer in `main.rs:308`) plus your loop's frames. A runaway rate localizes the offending surface.

---

## 7. Anti-Patterns

### `.repeat()` on an off-screen or unfocused element
**Symptom:** Idle CPU/GPU never drops; fans audible with the window in the background.
**Detection:** `grep -n '\.repeat()' src/*.rs`; for each hit, confirm it is guarded by a visibility/focus condition (`app.rs:658` is the good example — `if is_focused`). An unguarded `.repeat()` is a defect.
**Fix:** Gate every loop on `is_focused`/visibility AND `!self.motion.reduced()`. Idle elements emit static, no animation.

### `pulsating_between(0.0, x)` — the disappearing element
**Symptom:** A "breathing" indicator blinks fully out, reading as a flicker/bug rather than presence.
**Detection:** Any `pulsating_between` whose low bound is `0.0` (or near it) on an *informational* element.
**Fix:** Floor the opacity so the cue never vanishes — the console uses `0.55` (`app.rs:663`). Reserve 0.0 floors for deliberate blink-out (errors), never for "alive."

### Per-frame `fs::read` / daemon poll inside `render`
**Symptom:** One animated element melts a core; `powermetrics` shows disk activity at the refresh rate.
**Detection:** `grep -n 'fs::read\|read_to_string\|read_dir\|\.load(' ` inside any `render`/delta closure. Cross-reference with `FsAssets::load` (`main.rs:79`) — asset paths must be resolved *before* the animated subtree, not within it.
**Fix:** Keep all I/O on the 2s background producer (`main.rs:163`); `render` only reads already-materialized state. Memoize asset `SharedString` paths so gpui's content cache serves them.

### Reduced motion = `if reduced { /* emit nothing */ }`
**Symptom:** Motion-sensitive users lose the focus/state cue entirely; the UI becomes ambiguous under Reduce Motion.
**Detection:** Any reduced branch that returns an empty/absent element or omits the end-state styling.
**Fix:** Reduced branch emits the **resolved end-state** (solid opacity + static `glow`), or a ≤120ms cross-fade. Preserve orientation; remove only oscillation/travel (§4).

### Many simultaneous loops driven by independent `Animation`s
**Symptom:** A dashboard of 10 "live" dots holds the window at 120 Hz; budget scales with element count.
**Detection:** More than ~2 concurrent `.repeat()` calls reachable in one frame.
**Fix:** Drive shared pulses from one clock value bumped on the existing 500ms tick (`main.rs:308`) and read in `render` — N indicators, one notify rate (§2c).

### Reading `accessibilityDisplayShouldReduceMotion` off the main thread
**Symptom:** Intermittent panic or UB; AppKit accessor invoked from the bg producer thread.
**Detection:** `os_reduce_motion()` called anywhere but view construction / main thread.
**Fix:** Resolve `MotionMode::resolve()` once during `ConsoleView` construction (main thread, like `init_theme_from_env`), cache on the view.

---

## 8. Quality Gates (gpui-mapped)

- [ ] **Motion owner is explicit per surface** — exactly one of {`.repeat()` loop, one-shot `with_animation`, `.hover`/`.when` state cue} per element; no element animated by two paths.
- [ ] **Continuous loops are gated** on visibility/focus *and* `!motion.reduced()`; idle/off-screen elements emit static (no dirty bit). Verified by `grep '\.repeat()'`.
- [ ] **Loop budget ≤2 on-screen**; many "alive" indicators share one clock value, not one `Animation` each.
- [ ] **Delta closures touch only real properties** — `opacity`, interpolated `Hsla` color, `BoxShadow` (`motion::glow`/`hard_offset`), or layout fraction. No attempt at `scale`/`translate` (they don't exist in 0.2.x).
- [ ] **Pulse opacity floors above 0** (`≥0.5`) on informational elements; 0.0 only for deliberate blink-out.
- [ ] **No I/O in render/delta closures** — `fs::read`/asset `load`/daemon polls live on the background producer; asset paths memoized.
- [ ] **Reduced-motion is a branch, not silence** — every reduced path emits the resolved end-state or a ≤120ms cross-fade; focus/state cues remain legible. A/B'd with `PD_CONSOLE_MOTION=reduced`.
- [ ] **Reduced-motion gate exists and is testable** — OS `accessibilityDisplayShouldReduceMotion` read on the main thread once, overridable by `PD_CONSOLE_MOTION` (mirrors `PD_CONSOLE_THEME`).
- [ ] **Idle window is dark** — verified via `powermetrics`/`MTL_HUD_ENABLED=1`: ~0 fps and near-0% CPU/GPU after the 1s post-input window elapses.
- [ ] **Durations proportional to task** — interaction acknowledgements ≤300ms (mostly state cues with no timeline); only ambient "presence" motion loops, and only on the focused element.

---

### Sources
- [Zed — *Optimizing the Metal pipeline to maintain 120 FPS in GPUI*](https://zed.dev/blog/120fps) (dirty-flag render gate, `on_request_frame`/CADisplayLink, repeated-frames-for-1s-after-input)
- [`gpui` on docs.rs](https://docs.rs/gpui) and [`Window` API](https://docs.rs/gpui_rn/latest/gpui/struct.Window.html) (mark-dirty / refresh on next frame)
- [GPUI Framework — DeepWiki](https://deepwiki.com/zed-industries/zed/2-gpui-framework) (Metal renderer, hybrid immediate/retained model)
- Real code: `pd-console/src/app.rs` (`motion` module `:144-178`; beacon `:658-666`; hover/glow cues `:627-635, 785-789, 919-929`), `main.rs` (`FsAssets::load` `:76-98`; bg producer `:163`; foreground consumer `:302-319`), `palette.rs` (`ThemeMode` + env-seed pattern), `mux.rs` (focus-order render).
