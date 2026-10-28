# Transition Architecture

> One motion **owner** per surface. An interruptible transition state machine that lives *in the view*, retargetable mid-flight. How to choreograph pd-console's `spawn → advanced(expand) → fleet(list) → fullscreen(zoom) → diff(tab-slide)` flow when gpui has no fluent transform, no `AnimatePresence`, and no layout engine.

This is the companion to `references/04-motion-and-microinteractions.md`. That doc covers *atoms* — a glow, a breathing dot, a hover lift. This doc covers *transitions* — what happens when a surface changes **shape or identity**: a pane expands, a list reflows, a tab slides in, a thing that wasn't there appears. Atoms are stateless (`with_animation` fires and forgets). Transitions are stateful, interruptible, and must be **owned**.

---

## The Hard Constraint (read this first)

gpui 0.2.x ([docs.rs/gpui](https://docs.rs/gpui), [zed-industries/zed gpui](https://github.com/zed-industries/zed/tree/main/crates/gpui)) has **no fluent transform on `Div`**. There is no `.scale()`, no `.translate_x()`, no `.transition()`. The only animation entry point on a styled element is the `AnimationExt` trait's `with_animation`, demonstrated in [zed's `animation.rs` example](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/animation.rs):

```rust
use gpui::{Animation, AnimationExt as _, ease_in_out, bounce, percentage};

el.with_animation(
    "image_circle",
    Animation::new(Duration::from_secs(2)).repeat().with_easing(bounce(ease_in_out)),
    |svg, delta| svg.with_transformation(Transformation::rotate(percentage(delta))),
)
```

`Transformation::rotate` exists **only for `svg()` elements** (it's a paint-time matrix on the rasterized glyph), not for `Div`. So for a `Div`, the `delta: f32` closure can drive only the properties `Div` actually exposes: **`opacity`, `bg`/`text_color` (interpolated by hand), `shadow(BoxShadow)`, and layout sizes (`w`, `h`, `flex_basis`)**. Our codebase already lives inside this constraint — `pd-console/src/app.rs:144-179` documents it verbatim:

```rust
// ── Motion — gpui 0.2.2 has no fluent transform, so "lift/glow/spring" reads
// through hover color + box-shadow (instant, GPU-cheap) and with_animation
// one-shot/looping timelines. Curves match the mock's bezier set. ≤500ms.
mod motion {
    pub const RISE_MS: u64 = 500;
    pub fn swoosh(t: f32) -> f32 { 1.0 - (1.0 - t).powi(5) } // quintic ease-out
    pub fn glow(color: u32, alpha: f32, blur: f32, spread: f32) -> Vec<BoxShadow> { /* … */ }
    pub fn hard_offset(color: u32, dx: f32, dy: f32) -> Vec<BoxShadow> { /* … */ }
}
```

**Translation table — Framer Motion / GSAP intent → gpui primitive.** The `animation-system-architect` skill assumes a web stack; every line of it must be re-mapped before it applies here:

| Web concept (skill vocabulary) | Does NOT exist in gpui 0.2.x | What we use instead |
|---|---|---|
| `motion.div` `scale`/`translate` | no `Transform` on `Div` | animate `flex_basis`/`w`/`h` fractions; fake "lift" with `shadow(hard_offset)` |
| `AnimatePresence` enter/exit | no mount/unmount hook | keep the element in the tree during exit; drive `opacity`→0 then drop next frame |
| Framer `layout` (FLIP) | no layout-diff engine | animate the `Child.weight` floats in `mux.rs`; the existing `render_node` flex map (app.rs:576) does the rest |
| GSAP timeline | no global timeline | one `Transition` enum per view + `with_animation`'s `delta` as the playhead |
| interruptible spring | no spring solver | re-seed the state machine's `from` to the *current interpolated value*, restart the clock |
| `View Transitions` shared element | none | render the same surface in both layouts; cross-fade opacity over a weight animation |

**Decision Point — is this an atom or a transition?**
- *Atom*: no identity change, no reflow, self-contained, can loop forever. → fire-and-forget `with_animation`, no view state. (the focused-dot beacon, app.rs:659.)
- *Transition*: shape changes, identity changes, or another element must yield space. → it needs an **owner** and a **state machine**. Everything below.

---

## Principle 1 — One Motion Owner Per Surface

The `animation-system-architect` skill's rule #4 — *"Choose one orchestration owner… should own a flow, not compete inside it"* — is the load-bearing principle here, and gpui makes violating it especially nasty because **`with_animation` is keyed by `ElementId`** and gpui caches each animation's start-time against that id. Two animations targeting the same visual property with overlapping ids fight over the same cached clock; you get stutter, restart-on-every-notify, or a frozen half-state.

**Owner = the `Entity<V>` (the view) whose `Context<V>` drives the flow.** In pd-console that is `ConsoleView` (app.rs:319). The owner holds:
1. exactly one `Transition` enum field (the current in-flight transition, or `Idle`),
2. the `Instant` the transition started,
3. a single `cx.notify()` pump (or an animation `delta` closure) advancing it.

Sub-elements (panes, list rows, tabs) **never** own a transition that reflows their siblings. A pane cannot animate its own `flex_basis` toward "expanded" because its sibling has to give up exactly that space simultaneously — only the common ancestor (the `Workspace`/`ConsoleView`) sees both. This is why `mux.rs` is deliberately **GPUI-free** (mux.rs:7) and stores `weight: f32` per `Child` (mux.rs:80): the owner mutates weights; the renderer (app.rs:576-593) projects them to flex. The tree is the single source of layout truth; the transition is the owner animating that truth over time.

**Anti-Pattern: Distributed Ownership**
- **Symptom:** Expanding a pane "snaps" or two panes both try to grow; closing a pane leaves a frozen sliver.
- **Detection:** grep for `with_animation` inside `render_leaf` / per-row render fns that animate `flex_basis`, `w`, or `h`. Any layout-affecting `with_animation` below the `render_node` ancestor is a smell. (Currently app.rs:659 only animates `opacity` on a leaf dot — that's fine, it's an atom.)
- **Fix:** Lift the animated quantity to the owner's `Transition` state; have the leaf render *read* an interpolated value passed down, never compute its own reflow.

---

## Principle 2 — The Interruptible Transition State Machine

A real operator clicks "expand," changes their mind, hits fleet, then fullscreen — faster than any 250ms animation finishes. The web answer is interruptible springs; we don't have a spring solver, so we build the smallest thing that retargets cleanly: a hand-rolled state machine on the owner, advanced by a per-frame clock, **retargetable mid-flight** by re-seeding `from` to the current interpolated value.

```rust
// in pd-console/src/app.rs, owned by ConsoleView (the entity)
use std::time::Instant;

/// A geometry transition for the active workspace. Exactly one is live at a time.
/// `from`/`to` are the *flex weights* of the focused pane (mux.rs Child.weight),
/// because weight is the only layout quantity gpui can interpolate for us.
#[derive(Clone)]
enum Transition {
    Idle,
    /// Pane grows/shrinks within its split (advanced "expand", zoom, restore).
    Resizing { pane: PaneId, started: Instant, dur: Duration, from: f32, to: f32, easing: fn(f32) -> f32 },
    /// A surface is being swapped under a cross-fade (fleet list ⇄ agent).
    Crossfade { pane: PaneId, started: Instant, dur: Duration, outgoing: SurfaceKind },
    /// Tabs slide: the diff tab enters from the right (app.rs switch_tab today is instant).
    TabSlide { started: Instant, dur: Duration, from: usize, to: usize, dir: i8 },
    /// An enter (spawn appears) or exit (pane closes) — the AnimatePresence stand-in.
    Presence { pane: PaneId, started: Instant, dur: Duration, kind: PresenceKind },
}

#[derive(Clone, Copy)] enum PresenceKind { Enter, Exit }
```

**Progress is computed, never stored.** Storing a `progress: f32` and incrementing it per-tick double-buffers the truth and drifts. Store `started: Instant`; compute `t = elapsed / dur` clamped, then `eased = (easing)(t)`. This matches how gpui's own `with_animation` works — it caches *start time*, not progress, and recomputes `delta` each frame ([zed animation.rs](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/animation.rs)).

```rust
impl Transition {
    /// Current eased value in [0,1], and whether the transition has finished.
    fn sample(&self, now: Instant) -> (f32, bool) {
        let (started, dur, easing): (Instant, Duration, fn(f32)->f32) = match self {
            Transition::Idle => return (1.0, true),
            Transition::Resizing { started, dur, easing, .. } => (*started, *dur, *easing),
            Transition::Crossfade { started, dur, .. }
            | Transition::TabSlide { started, dur, .. }
            | Transition::Presence { started, dur, .. } => (*started, *dur, motion::swoosh),
        };
        let raw = (now.duration_since(started).as_secs_f32() / dur.as_secs_f32()).clamp(0.0, 1.0);
        (easing(raw), raw >= 1.0)
    }
}
```

**Retargeting — the whole point.** When a new transition arrives mid-flight, we do **not** start from `to_old`; we start from *where we visually are right now*, so there's no jump:

```rust
impl ConsoleView {
    /// Retarget the focused pane's weight to `target`, springing off the live value.
    fn retarget_resize(&mut self, pane: PaneId, target: f32, cx: &mut Context<Self>) {
        let now = Instant::now();
        // 1. Freeze the current interpolated weight as the new `from`.
        let from = match &self.transition {
            Transition::Resizing { from, to, .. } => {
                let (e, _) = self.transition.sample(now);
                from + (to - from) * e               // current visual weight
            }
            _ => self.current_weight(pane),          // resting weight from the tree
        };
        // 2. Restart the clock toward the new target.
        self.transition = Transition::Resizing {
            pane, started: now, dur: Duration::from_millis(motion::RISE_MS),
            from, to: target, easing: motion::swoosh,
        };
        cx.notify(); // kick the pump
    }
}
```

**Decision Point — `cx.notify()` pump vs `with_animation` delta closure.** Two ways to advance a frame in gpui:
- **`with_animation` (delta closure):** gpui owns the clock and re-renders for the animation's duration. Clean for an *atom on one element* (the dot, app.rs:659). Bad for transitions because the `delta` only reaches the closure's element — it can't simultaneously shrink a *sibling*. And it's keyed by `ElementId`; retargeting means changing the id, which resets the clock to 0 (a jump).
- **Self-driven `cx.notify()` pump:** in `render`, if `!matches!(self.transition, Idle)`, schedule the next frame. This re-renders the *whole view*, so the owner can read one `sample()` and apply it to the growing pane **and** the shrinking sibling and the entering tab in one consistent pass. **This is the right tool for retargetable, multi-element transitions.** The cost is you must stop the pump at rest, or you spin the CPU.

```rust
fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
    let now = Instant::now();
    if !matches!(self.transition, Transition::Idle) {
        let (_, done) = self.transition.sample(now);
        if done {
            self.commit_transition();          // bake final weights into the tree, set Idle
        } else {
            // Re-render next frame. request_animation_frame keeps us at display refresh
            // without a busy-loop; falling back to a 16ms timer also works.
            window.request_animation_frame();  // gpui 0.2.x frame hook
            cx.notify();
        }
    }
    /* … render the tree, reading self.transition.sample(now) for live geometry … */
}
```

**Anti-Pattern: The Un-Interruptible Animation**
- **Symptom:** clicking expand→fleet→zoom rapidly makes panes "queue up" and play sequentially, or the second click is ignored until the first finishes.
- **Detection:** a transition kicked via `with_animation` keyed by a *constant* `ElementId`; or an owner that early-returns if `transition != Idle`.
- **Fix:** the `retarget_*` pattern above — always accept the new intent, re-seed `from` from the live sample, restart the clock. Never gate new input on the old transition completing.

---

## Principle 3 — Choreographing the pd-console Flow

The flow `spawn → advanced(expand) → fleet(list) → fullscreen(zoom) → diff(tab-slide)` is five transitions, each a variant above. Crucially they share **one owner** (`ConsoleView`) and **one `Transition` field**, so each new step naturally retargets the last.

### spawn → (Presence::Enter)
A new agent appears. There is no `AnimatePresence`, so the owner inserts the leaf into the `mux.rs` tree *immediately* (so layout is correct) but tags it `Presence { kind: Enter }`. The render reads `sample()` and:

```rust
// in render_leaf, the entering pane fades + glow-rises in; weight grows 0 → resting.
let (e, _) = enter_sample;                       // 0..1
pane.opacity(e)
    .when(e < 1.0, |s| s.shadow(motion::glow(theme.accent, 0.45 * e, 16.0 * e, 1.0)))
// and its Child.weight is interpolated 0.0 → 1.0 so siblings yield space smoothly
```

There is no scale, but **opacity + a growing weight + a swelling glow** reads as "materializing." That's the gpui idiom for "zoom in."

### advanced(expand) → (Resizing)
The "advanced view" expands the focused pane to dominate its split. This is purely `Child.weight` animation: `from = current_weight`, `to = 4.0` (4:1 dominance). The sibling shrinks automatically because `render_node` normalizes `frac = weight / total` (app.rs:583). **No code in the renderer changes** — the owner just moves the float and pumps frames.

```rust
self.retarget_resize(focused, /*to*/ 4.0, cx);   // expand
```

### fleet(list) → (Crossfade + staggered reflow)
Swapping the focused surface to `SurfaceKind::Fleet` (mux.rs:45) is an *identity* change, not a geometry one. We cross-fade: keep the outgoing surface painted at `opacity(1-e)` behind/over the incoming at `opacity(e)` for `dur`, then drop the outgoing. The list itself reflows with a stagger — see Principle 5.

### fullscreen(zoom) → (Resizing to full)
pd-console already has a `zoomed: Option<PaneId>` per tab (app.rs:407). Today it's an instant boolean. Animate it: `Resizing` from the pane's resting weight to "fills the tab." Because zoom is modeled as *the pane temporarily owning 100% of the tab's flex*, it's the same `Resizing` variant with `to = f32::MAX`-ish (clamp to e.g. `999.0` so `frac → ~1.0`). Restore = retarget back to the saved weight. Retargeting means hitting Escape mid-zoom reverses *from the current size*, not from full.

### diff(tab-slide) → (TabSlide)
Opening a diff opens a new tab. `switch_tab` (app.rs:434) is instant today:
```rust
fn switch_tab(&mut self, delta: isize) { /* … */ self.active_tab = …; }   // snap
```
Make it a `TabSlide`. gpui can't translate, so "slide" is faked with **animated `flex_basis` on a two-up filmstrip**: render both the outgoing and incoming tab side-by-side inside an `overflow_hidden` row, and animate the *filmstrip offset* by giving the outgoing tab `flex_basis(relative(1.0 - e))` and the incoming `flex_basis(relative(e))`. The clip does the rest. It reads as a horizontal slide without a transform.

```rust
// owner sets:  Transition::TabSlide { from: prev, to: next, dir: +1, started, dur }
// render: a clipped 2-up strip; e drives which tab occupies the viewport.
div().flex().flex_row().overflow_hidden().size_full()
    .child(div().flex_basis(relative(1.0 - e)).overflow_hidden().child(self.render_tab(from)))
    .child(div().flex_basis(relative(e)).overflow_hidden().child(self.render_tab(to)))
```

**Choreography note:** because all five are the *same field*, the sequence is automatically interruptible end-to-end. `spawn`'s Enter can be cut off by `expand`; `expand` by `fleet`; etc. Each `retarget_*` reads the live `sample()`, so the chain never jumps. This is the gpui equivalent of one GSAP timeline you can `.tweenTo()` anywhere on — built from a single enum and a single clock.

---

## Principle 4 — AnimatePresence Equivalent (enter/exit when gpui has none)

Framer's `AnimatePresence` defers a component's *unmount* until its exit animation finishes. gpui has no such hook: when your `render` stops emitting an element, it's gone next frame — no exit. The pattern:

**Keep the dying element in the tree until its exit animation completes; the owner, not the renderer, decides when to actually drop it.**

```rust
// CLOSING a pane (app.rs has Workspace::close at mux.rs that merges instantly).
fn begin_close(&mut self, pane: PaneId, cx: &mut Context<Self>) {
    // Do NOT call ws.close() yet — that would delete the node and kill the exit.
    self.transition = Transition::Presence {
        pane, started: Instant::now(), dur: Duration::from_millis(180), kind: PresenceKind::Exit,
    };
    cx.notify();
}

fn commit_transition(&mut self) {
    if let Transition::Presence { pane, kind: PresenceKind::Exit, .. } = self.transition {
        self.ws_mut().close_pane(pane);   // NOW remove it from the mux tree
    }
    self.transition = Transition::Idle;
}
```

Render the exiting pane with `opacity(1 - e)` and a collapsing weight (`weight *= 1 - e`) so neighbors reclaim the space smoothly, then `commit_transition` deletes the node. Enter is the mirror (Principle 3, spawn). Keep exits **short** (≤180ms): the `beautiful-gui-design` skill's rule is *ease-out to enter, ease-in to exit, 100–300ms* — an exit that lingers feels broken. Our `swoosh` is ease-*out*; for exits use its inverse `t.powi(5)` (ease-in) so the element accelerates away.

**Anti-Pattern: Orphaned Exit State**
- **Symptom:** a closed pane reappears for one frame, or the app panics indexing a `PaneId` that was already removed.
- **Detection:** the renderer reads `ws.close()`-mutated tree while a `Presence::Exit` still references the old `PaneId`; or `commit_transition` removing the node *before* the last frame paints.
- **Fix:** single authority over removal — only `commit_transition` deletes, and only after `sample().1 == true`. The renderer guards every lookup: `if let Some(surface) = ws.surface_in(pane)` (mux.rs already exposes `surface_in`, app.rs:407 region).

---

## Principle 5 — Staggered List Reflow Without a Layout Engine (recency float-up)

When a fleet agent emits activity, its row should **float to the top** of the list, and the rows below should slide down to make room — staggered, not all at once. Framer does this with `layout` + FLIP. We have no FLIP. But we have something better for a *list*: we control the order and the per-row offset directly.

**Model:** the list is `Vec<Row>` sorted by recency. On reorder, the owner records, per row, `from_index` and `to_index` and a single `started: Instant`. Each row computes its own vertical offset by interpolating between its old and new slot, with a **stagger delay** proportional to its target index.

```rust
struct RowMotion { id: String, from_y: f32, to_y: f32, delay_ms: u64 }

fn render_row(&self, row: &Row, rm: &RowMotion, now: Instant) -> impl IntoElement {
    let t0 = self.reflow_started + Duration::from_millis(rm.delay_ms);
    let raw = if now < t0 { 0.0 }
              else { (now.duration_since(t0).as_secs_f32() / 0.22).clamp(0.0, 1.0) };
    let e = motion::swoosh(raw);
    let y = rm.from_y + (rm.to_y - rm.from_y) * e;     // interpolated slot
    // No translate in gpui → position via an absolute-offset child or a top margin.
    div().absolute().top(px(y)).left(px(0.0)).w_full()
        // The freshly-promoted row also flashes a recency glow that decays:
        .when(rm.to_y == 0.0, |s| s.shadow(motion::glow(theme.accent, 0.4 * (1.0 - e), 12.0, 0.0)))
        .child(/* row content */)
}
```

Two gpui realities make this work without a layout engine:
1. **Absolute positioning is the FLIP substitute.** gpui supports `.absolute().top(px(y))` inside a `.relative()` container. The owner computes each row's pixel slot (`row_height * index`) and animates `top`. No layout pass re-runs; we're just painting at a moving `y`.
2. **Stagger = per-row delay, one shared clock.** Don't give each row its own `with_animation` (N cached clocks, N `ElementId`s, jank). Share `reflow_started` on the owner; each row offsets by `delay_ms = to_index * 30`. This is the gpui-correct way to express the skill's "staggered list animation" idiom.

**Decision Point — absolute-offset rows vs animated `flex_basis`.** Use **absolute `top`** for reflow (rows cross each other, need overlap during the swap). Use **`flex_basis`** for expand/collapse (siblings divide a fixed space, never overlap). Mixing them — animating `flex_basis` for a reorder — fails because flex children can't cross each other.

**Anti-Pattern: N-Clock Stagger**
- **Symptom:** a 40-row list stutters on every update; CPU spikes; rows restart their animation when an unrelated row changes.
- **Detection:** `with_animation` called inside a `.map()` over rows, each keyed `format!("row-{id}")`.
- **Fix:** one owner clock (`reflow_started`), per-row `delay_ms`, computed offset in the row render. Stop the pump when the last (highest-delay) row finishes.

---

## Before / After — the tab switch

**Before** (app.rs:434, shipping today — instant, no transition state):
```rust
fn switch_tab(&mut self, delta: isize) {
    let n = self.tabs.len() as isize;
    self.active_tab = (((self.active_tab as isize + delta) % n + n) % n) as usize;
    // active_tab flips; next render snaps to the new tab. No motion, no owner.
}
```

**After** (owner-driven, interruptible, gpui-idiomatic slide via clipped flex):
```rust
fn switch_tab(&mut self, delta: isize, cx: &mut Context<Self>) {
    let n = self.tabs.len();
    if n < 2 { return; }
    let next = (((self.active_tab as isize + delta) % n as isize + n as isize) % n as isize) as usize;
    let dir = if delta >= 0 { 1i8 } else { -1 };
    // Retarget: if a slide is already running, seed `from` from the live position
    // so a fast [ ] ] ] doesn't jump.
    self.transition = Transition::TabSlide {
        started: Instant::now(), dur: Duration::from_millis(220),
        from: self.active_tab, to: next, dir,
    };
    self.active_tab = next;   // logical truth flips now; the slide is cosmetic catch-up
    cx.notify();
}
```
The render reads `Transition::TabSlide` and lays out the clipped 2-up filmstrip from Principle 3; `commit_transition` sets `Idle` when `sample().1`. Same five-line easing budget as everything else, one owner, fully interruptible.

---

## Quality Gates

Ship a transition only when **all** of these hold:

- [ ] **One owner.** The transition lives in a single `Entity`'s `Transition` field. No layout-affecting `with_animation` below the common ancestor (grep `with_animation` in per-leaf/per-row render fns — only `opacity`-on-self atoms allowed).
- [ ] **Interruptible.** Firing the transition again mid-flight re-seeds `from` from the live `sample()` and restarts the clock — no visible jump. Tested by mashing the trigger.
- [ ] **Computed progress.** State stores `started: Instant`, not a `progress: f32`. `sample(now)` recomputes each frame.
- [ ] **Pump stops at rest.** `request_animation_frame`/`cx.notify()` loop runs *only* while `transition != Idle`. Verified: idle CPU ≈ 0, no notify storm. (Mirror the existing rule that idle panes are static while only the focused dot loops, app.rs:653.)
- [ ] **Enter/exit committed by the owner.** Elements are removed from the `mux.rs` tree *only* in `commit_transition`, after `sample().1 == true`. Every tree lookup in render is `Option`-guarded.
- [ ] **No transform assumed.** Zero `.scale`/`.translate` (they don't exist). "Lift/zoom/slide" reads through `opacity` + `shadow(BoxShadow)` + animated `flex_basis`/`top`. Grep proves no fictional API crept in.
- [ ] **Budget respected.** Durations ≤ `motion::RISE_MS` (500ms); micro-transitions 150–250ms (`beautiful-gui-design`: enter ease-out, exit ease-in, 100–300ms). Stagger step ≤ 30ms/row.
- [ ] **Reduced-motion branch.** A `PD_CONSOLE_REDUCED_MOTION` (peer of `PD_CONSOLE_THEME`, app.rs:130) collapses every transition to `dur = 0` → instant commit, no pump. The state machine still runs; it just samples to `1.0` immediately. (The skill's rule #2: reduced-motion is a design branch, not a toggle.)
- [ ] **Theme-safe.** Every interpolated color/glow reads from `palette.rs` roles (`current_theme().accent`, etc.), never raw hex, so transitions survive the `Ctrl-A g` light⇄dark flip.

---

**Sources:** [gpui — docs.rs](https://docs.rs/gpui) · [zed-industries/zed gpui crate](https://github.com/zed-industries/zed/tree/main/crates/gpui) · [gpui animation.rs example](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/animation.rs) · [GPUI framework overview (DeepWiki)](https://deepwiki.com/zed-industries/zed/2-gpui-framework). In-repo grounding: `pd-console/src/app.rs` (`mod motion` :144-179, focused-dot `with_animation` :659-665, `render_node` flex map :576-593, `ConsoleView`/`active_tab`/`switch_tab` :319/:434, `zoomed` :407) and `pd-console/src/mux.rs` (GPUI-free tree, `Child.weight` :80, `SurfaceKind` :33).
