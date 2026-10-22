# 02 — The No-Fluent-Transform Constraint

> *gpui 0.2.x has no `scale`, `translate`, or `rotate` on elements. There is no `transform` property to interpolate. Every "lift / slide / zoom / spring" you've internalized from CSS and Framer Motion must be re-derived from the primitives gpui actually ships: opacity, `BoxShadow`, hover color, animated **layout fractions**, and the `delta` closure inside `with_animation`. This doc is the translation table — with real Rust from `pd-console/src/app.rs`.*

The motion-architecture skill's prime directive is **"animate compositor-friendly properties — prefer `transform` and `opacity`; treat layout properties as an explicit exception"** (`animation-system-architect/SKILL.md:50`). On the web the compositor-safe pair is `transform` + `opacity`. **In gpui 0.2.x, half that pair does not exist.** There is no fluent transform on `Div`. So our compositor-safe vocabulary shrinks to: `opacity`, `shadow(BoxShadow)`, and `text_color`/`bg` swaps. Everything else — width, height, `flex_basis`, inset — is the *layout* exception, and the skill is explicit that layout animation is the thing you ration, not the thing you reach for.

That's the whole game. This doc tells you how to fake the missing vocabulary, what each fake costs, and where the real console already does it right.

---

## What gpui 0.2.x actually gives you

Grepping the real tree (`core/pd-console/src`) for every motion primitive in use, the entire surface is four things:

| Capability | gpui primitive | Where it lives in the console | Cost class |
|---|---|---|---|
| Fade / pulse / reveal | `.opacity(f32)`, animated via `with_animation` `delta` | `app.rs:664` (dot pulse), `app.rs:686` (`group_hover` reveal) | **Compositor** (cheap) |
| "Lift" / "press" / glow | `.shadow(Vec<BoxShadow>)` | `motion::glow` `app.rs:158`, `motion::hard_offset` `app.rs:170` | **Compositor** (cheap) |
| State color change | `.hover(\|s\| …)`, `.bg`, `.text_color`, `.border_color` | `app.rs:786`, `app.rs:631`, `app.rs:927` | **Compositor** (cheap) |
| Slide / expand / split-resize | animated `flex_basis(relative(frac))` | `app.rs:586` + weights in `mux.rs:80,363` | **Layout** (expensive — ration it) |

There is **no** `Animation` import beyond `with_animation`/`Animation::new`/`pulsating_between`, no spring type, no `AnimatePresence`, no shared-element/View-Transition machinery. The console pulls the entire API in via a glob (`use gpui::*;` at `app.rs:19`) and then uses exactly the symbols above. Confirm that for yourself: `grep -rn "with_animation\|Animation::new\|pulsating_between\|BoxShadow\|shadow(" .` returns a *short* list. That short list is your palette. The community wrapper [`gpui-animation`](https://lib.rs/crates/gpui-animation) exists but is not a dependency here and does not add transforms — it wraps the same `delta` model.

The console author wrote the constraint down in a header comment so the next agent doesn't go looking for `scale`:

```rust
// app.rs:144
// ── Motion — gpui 0.2.2 has no fluent transform, so "lift/glow/spring" reads
// through hover color + box-shadow (instant, GPU-cheap) and with_animation
// one-shot/looping timelines. Curves match the mock's bezier set. ≤500ms.
```

Keep that ≤500ms budget. The beautiful-gui skill puts the web band at **100–300ms, ease-out to enter / ease-in to exit** (`beautiful-gui-design/SKILL.md:59`); the console's looping beacon is a deliberate exception (presence signal, not a transition) and even it is capped.

---

## The `with_animation` mental model

There is exactly one time-driven primitive, and it does not animate a property — it hands you a normalized **`delta: f32`** each frame and lets you fold it into the element yourself. This is the seam through which *all* faked motion flows.

```rust
// app.rs:659 — the focused pane's presence beacon (looping)
dot.with_animation(
    SharedString::from(format!("dot-pulse-{id}")),         // stable ElementId — REQUIRED
    Animation::new(Duration::from_millis(2400))
        .repeat()                                            // loop forever
        .with_easing(pulsating_between(0.55, 1.0)),          // delta oscillates in [0.55, 1.0]
    |el, delta| el.opacity(delta),                           // YOU apply delta to a property
)
.into_any_element()
```

Read the closure literally: `|el, delta|` receives the element and the eased scalar; **you** decide what `delta` means. Here it's `opacity`. It could just as well drive a `flex_basis`, an alpha channel on a shadow color, or a `px()` height. `pulsating_between(a, b)` makes `delta` ping-pong; plain `.with_easing(swoosh)` makes it ramp `0.0 → 1.0` once. The console's own curve is quintic ease-out:

```rust
// app.rs:152
/// `--swoosh`: graceful fast-out settle (≈ quintic ease-out).
pub fn swoosh(t: f32) -> f32 { 1.0 - (1.0 - t).powi(5) }
```

**Decision Point — `with_animation` vs `hover` vs `cx.notify()`:**
- **Continuous/looping** signal with no input (presence, "thinking", waiting) → `with_animation(...).repeat()`. The beacon at `app.rs:659` is the canonical example.
- **State-driven** transition keyed off pointer/focus → use `.hover(...)` / `group_hover` and let gpui's built-in 150ms color interpolation carry it. No timeline needed (`app.rs:786`, `app.rs:687`).
- **Data-driven** one-shot (a value arrived, a resize landed) → mutate state, call `cx.notify()` (`app.rs:638`), and let the next render diff. If you want it *eased*, you must own the tween yourself (see Spring section).

**Anti-Pattern — unstable `ElementId` on an animation.**
**Symptom:** an animation restarts from frame 0 every render, or two panes' beacons fight. **Detection:** the `SharedString` passed to `with_animation` is a constant literal (`"dot-pulse"`) while multiple instances mount, or it's recomputed from volatile state. **Fix:** derive it from a stable identity — the console uses `format!("dot-pulse-{id}")` keyed on `PaneId` (`app.rs:660`) so each pane owns its own timeline and it persists across re-renders.

---

## Faking "lift" — `shadow(BoxShadow)` + offset, never `translateY`

The web idiom is `transform: translateY(-1px)` plus a drop shadow on hover. We have no `translateY`. The console fakes the *entire* lift with shadow geometry, and says so in the comment:

```rust
// app.rs:169
/// Neobrutalist hard offset drop — the hover "lift" cue (no translate in 0.2.2).
pub fn hard_offset(color: u32, dx: f32, dy: f32) -> Vec<BoxShadow> {
    let h: Hsla = gpui::rgb(color).into();
    vec![BoxShadow {
        color: h,
        offset: point(px(dx), px(dy)),   // a HARD shadow offset reads as "the chip rose"
        blur_radius: px(0.0),            // 0 blur = neobrutalist hard edge
        spread_radius: px(0.0),
    }]
}
```

Applied on an inactive tab's hover (`app.rs:929`):

```rust
.when(!active, |s| s.hover(|h| {
    let t = current_theme();
    h.bg(rgb(t.raised))
     .text_color(rgb(t.ink2))
     .shadow(motion::hard_offset(t.sunken, 0.0, 2.0))   // mock said translateY(-1px); this IS the lift
}))
```

The eye reads a hard shadow appearing *below* an element as the element rising off the page. You get the affordance with zero geometry change to the element itself — purely a paint-time shadow. For a *soft* halo (focus ring, "this has the wheel"), use the companion:

```rust
// app.rs:158 — alpha rides on Hsla; blur+spread shape the halo
pub fn glow(color: u32, alpha: f32, blur: f32, spread: f32) -> Vec<BoxShadow> {
    let mut h: Hsla = gpui::rgb(color).into();
    h.a = alpha;
    vec![BoxShadow { color: h, offset: point(px(0.0), px(0.0)),
                     blur_radius: px(blur), spread_radius: px(spread) }]
}
```

```rust
// app.rs:629 — focused pane gets a 16px mustard halo; unfocused previews a faint one on hover
.when(is_focused, |s| s.shadow(motion::glow(current_theme().accent, 0.45, 16.0, 1.0)))
.when(!is_focused, |s| s.hover(|h|
    h.border_color(rgb(current_theme().accent))
     .shadow(motion::glow(current_theme().accent, 0.18, 10.0, 0.0))))
```

**Cost:** `BoxShadow` is rasterized on the GPU at paint; it never touches layout. This is the cheapest "motion" you can buy — it's why the console reaches for it for every lift/press/focus cue instead of trying to move pixels.

**Decision Point — hard_offset vs glow:** hard, zero-blur, *offset* shadow = "object lifted" (neobrutalist, directional). Soft, zero-offset, *blurred+spread* shadow = "object is energized/selected" (halo, omnidirectional). Don't mix metaphors: a focus state is a glow, a press is an offset.

---

## Faking "slide / expand / split-resize" — animated layout fractions (the bounded exception)

This is the one place you're *allowed* to animate layout, and the console's whole multiplexer leans on it. Panes are not positioned; they're **weighted flex children**. The weight model lives in `mux.rs`:

```rust
// mux.rs:76
/// A weighted child within a Split. `weight` is a relative flex factor;
/// only ratios matter, so weights need not sum to 1.
pub struct Child { pub weight: f32, pub node: Node }
```

```rust
// mux.rs:363 — resize SHIFTS weight between a leaf and its sibling
let shift = children[pos].weight * delta;
children[pos].weight     = (children[pos].weight + shift).max(0.05);
children[neighbor].weight = (children[neighbor].weight - shift).max(0.05);
```

And weights become geometry in the renderer by normalizing to a fraction and feeding `flex_basis(relative(frac))`:

```rust
// app.rs:576
let total: f32 = children.iter().map(|c| c.weight).sum::<f32>().max(0.0001);
…
for child in children {
    let frac = child.weight / total;
    container = container.child(
        div()
            .flex_basis(relative(frac))   // <-- THE animatable layout fraction
            .flex_grow()
            .flex_shrink()
            .overflow_hidden()
            .child(self.render_node(&child.node, focused, cx)),
    );
}
```

To get a **smooth** slide/expand (a pane growing in, a sidebar sliding out), you animate `frac` itself with the `with_animation` `delta` closure rather than snapping the weight:

```rust
// PATTERN: ease a pane from collapsed to its target fraction on spawn.
// `frac_target` is the steady-state weight ratio; we ramp from a sliver.
let frac_target = child.weight / total;
div()
    .id(SharedString::from(format!("pane-grow-{id}")))   // stable id, as always
    .flex_grow()
    .child(/* pane body */)
    .with_animation(
        SharedString::from(format!("pane-grow-anim-{id}")),
        Animation::new(Duration::from_millis(motion::RISE_MS)) // 500ms cap, app.rs:150
            .with_easing(motion::swoosh),                      // quintic ease-out settle
        move |el, delta| {
            // delta: 0.0 → 1.0. Interpolate from a 4% sliver to the real fraction.
            let frac = 0.04 + (frac_target - 0.04) * delta;
            el.flex_basis(relative(frac))
        },
    )
```

A horizontal "slide-in" panel is the same trick on a `Dir::Row` split; a "drawer expand" is the same on `Dir::Col` with `delta` driving `flex_basis`. You never translate — you *grow the box*. The neighbor shrinks because the fractions are normalized.

**Cost — this is the expensive one, and the skill flags it (`SKILL.md:50,82`).** Every animated frame here triggers gpui's layout pass (Taffy/flexbox solve) for the whole subtree, not just a paint. The motion-architect anti-pattern is explicit: **"Animations on width/height/top/left … janky"** with the detection being **"tall Layout/Recalc bars during animation"** (`SKILL.md:81-82`). gpui has the equivalent layout cost.

**Bound it — the rules for spending the layout budget:**
1. **Short and few.** ≤500ms (`RISE_MS`, `app.rs:150`), and ideally only one layout animation in flight at a time. A pane spawn/close is a discrete event; a *continuously* dragged splitter should update weight on `cx.notify()` per drag-move and *not* run a tween (the input is already the timeline).
2. **Animate the smallest subtree.** Put `with_animation` on the pane wrapper, not the root container, so the layout solve is scoped.
3. **Snap, don't tween, when data is the trigger.** The console's resize (`mux.rs:363`) snaps the weight and calls `cx.notify()` — instant. Only ramp `frac` when the *intent* is a reveal/grow the user should perceive as motion (spawn, zoom toggle), never for routine data churn.

**Anti-Pattern — layout-animating on every data tick.**
**Symptom:** the whole pane tree visibly reflows/judders whenever upstream data updates. **Detection:** a `with_animation` driving `flex_basis`/`w`/`h` is mounted on a node whose state changes on a poll/stream cadence; or more than ~2 layout animations run concurrently. **Fix:** move continuous/data-driven changes to a snap + `cx.notify()` (the `mux.rs:363` pattern), and reserve `flex_basis` tweens for discrete user-perceptible events.

---

## Faking "zoom / shared-element" — opacity cross-fade + size interpolation

The web move is a View-Transition shared element that `scale`s from thumbnail to full. We have neither View Transitions nor `scale`. The console's zoom is a **layout swap** today: `render` branches between the full tree and a single maximized pane (`app.rs:866`):

```rust
let body: AnyElement = match zoomed.and_then(/* … */) {
    Some((zid, surf)) => self.render_leaf(zid, &surf, true, cx),  // one pane, full window
    None => self.render_node(&self.ws().root.clone(), focused, cx),
};
```

That's an instant cut. To make it *read* as a zoom (the missing `scale`), compose two compositor-cheap fakes and one bounded layout fake:

1. **Opacity cross-fade** between outgoing tree and incoming maximized pane — pure `opacity`, compositor-cheap. Mount the incoming pane at `opacity(delta)` and (optionally) the outgoing at `opacity(1.0 - delta)` via a one-shot `with_animation`.
2. **Size interpolation** as the substitute for `scale`: ramp the maximized pane's `flex_basis`/`size` fraction from "its current cell" toward `1.0` using the `frac` pattern above. Growth + fade together reads as "this pane zoomed forward." This is the layout-budget spend — keep it to the single zooming pane.
3. **Glow punctuation** on settle: snap a `motion::glow` at the end so the arrival has weight, matching the focus-halo language (`app.rs:629`).

```rust
// Sketch: zoom-in = cross-fade + grow, driven by ONE delta.
maximized_pane
    .with_animation(
        SharedString::from(format!("zoom-{zid}")),
        Animation::new(Duration::from_millis(motion::RISE_MS)).with_easing(motion::swoosh),
        move |el, delta| {
            el.opacity(0.3 + 0.7 * delta)          // fade up (compositor)
              .flex_basis(relative(start_frac + (1.0 - start_frac) * delta)) // grow (layout)
        },
    )
```

**Decision Point — true shared-element vs cross-fade.** A genuine shared-element morph (one DOM node tracked across two layouts) is not expressible in gpui 0.2.x. Don't fake the *identity* continuity; fake the *perceived* continuity with a fast cross-fade (≤250ms here, well under `RISE_MS`). Users read a tight opacity hand-off as "same thing, new size" without the engine ever tracking node identity.

---

## Faking "spring" — easing, because there is no spring type

Framer Motion's interruptible spring (`SKILL.md:71`) has no gpui 0.2.x analog. There is no spring solver, no velocity carry-over, no `react-spring`. You approximate spring *feel* purely through the easing function you hand `.with_easing(...)`. Two honest approximations:

```rust
// (a) Settle-only "soft landing" — the console's swoosh: fast out, gentle stop.
//     Reads as a critically-damped spring with no overshoot. (app.rs:152)
pub fn swoosh(t: f32) -> f32 { 1.0 - (1.0 - t).powi(5) }

// (b) Overshoot "bouncy" — a back-ease for chips/badges that should feel springy.
//     Single overshoot past 1.0 then settle. (add to mod motion if you need bounce)
pub fn back_out(t: f32) -> f32 {
    let c1 = 1.70158_f32;
    let c3 = c1 + 1.0;
    1.0 + c3 * (t - 1.0).powi(3) + c1 * (t - 1.0).powi(2)
}
```

**Hard limitation to state plainly:** easing is a *fixed-duration* curve. It cannot be interrupted mid-flight and re-targeted with conserved velocity the way a real spring can. The skill warns against exactly this brittleness — **"Prefer interruptible springs over brittle fixed keyframes"** (`SKILL.md:71`) — but interruptible springs are not on the menu in gpui 0.2.x. So: keep spring-feel animations **short and non-interruptible** (entrance, settle, a one-shot badge pop), and never use a fixed-easing "spring" for something the user can grab and fling (drag, scrub) — drive those directly from input + `cx.notify()` instead, where the input *is* the velocity source.

**Anti-Pattern — faking a spring on an interruptible gesture.**
**Symptom:** a dragged splitter or scrubbed value animates with a `back_out` easing and feels rubbery/laggy because every input event restarts a fixed tween. **Detection:** a `with_animation` keyed to a value the user is *actively* dragging. **Fix:** bind the value to the gesture and `cx.notify()` per move (the `mux.rs:363` resize model); reserve easing-springs for discrete, fire-and-forget entrances.

---

## Before / After

A real example: making the spawned-agent flash (`app.rs:737`, `control_flash`) *arrive* instead of blinking on.

**Before — instant pop (no motion, reads as a glitch):**
```rust
.when_some(control_flash, |bar, flash| {
    bar.child(
        div()
            .text_color(rgb(current_theme().muted))
            .text_size(px(13.0))
            .child(flash),          // appears between one frame and the next — jarring
    )
})
```

**After — fade-up with the house curve (compositor-cheap, ≤500ms):**
```rust
.when_some(control_flash, |bar, flash| {
    bar.child(
        div()
            .id(SharedString::from("control-flash"))      // stable id for the timeline
            .text_color(rgb(current_theme().muted))
            .text_size(px(13.0))
            .child(flash)
            .with_animation(
                SharedString::from("control-flash-in"),
                Animation::new(Duration::from_millis(motion::RISE_MS))
                    .with_easing(motion::swoosh),          // quintic ease-out, app.rs:152
                |el, delta| el.opacity(delta),             // 0 → 1 fade; pure compositor
            ),
    )
})
```

No transform invented, no layout touched, no new dependency. The message *settles in* using the exact curve the rest of the console already speaks. That's the whole discipline: when you want "enter," reach for `opacity` + `swoosh`; when you want "lift," reach for `shadow`; only when you genuinely need a box to change size do you spend the layout budget on `flex_basis`.

---

## Quality Gates

Run these before shipping any motion in this codebase:

- [ ] **No phantom transforms.** `grep -rn "\.scale(\|\.translate\|\.rotate" core/pd-console/src` returns nothing. They don't exist in 0.2.x; if you typed one it won't compile, but don't *design* around one either.
- [ ] **Every `with_animation` has a stable, unique `ElementId`.** Derived from a real identity (`format!("…-{id}")`, `app.rs:660`), never a bare literal on a repeated element.
- [ ] **Lift = shadow, not geometry.** Hover/press "rise" cues use `motion::hard_offset` / `motion::glow` (`app.rs:170,158`), never an attempted position change.
- [ ] **Layout animation is rationed.** At most ~1–2 concurrent `flex_basis`/`w`/`h` tweens; each ≤`RISE_MS` (500ms); reserved for discrete user-perceptible events (spawn, zoom, close), never data-tick churn. Data/resize updates **snap + `cx.notify()`** (`mux.rs:363`).
- [ ] **Compositor-first.** If a motion can be expressed in `opacity` + `shadow` + color, it is — those never trigger a layout pass.
- [ ] **Springs are short and non-interruptible.** Easing-based "spring feel" only on fire-and-forget entrances; interruptible gestures bind to input + `cx.notify()`, not a fixed tween (`SKILL.md:71`).
- [ ] **Duration budget honored.** ≤500ms per the `app.rs:144` header; transitions land in the 100–300ms band (`SKILL.md:59`); only the looping presence beacon exceeds it, deliberately.
- [ ] **One owner per motion.** A given element's motion is either a `with_animation` timeline *or* a `hover`/`group_hover` state transition — not both fighting over the same property (the skill's "ownership ambiguity is usually the real bug," `SKILL.md:91`).

---

*Sources: real console code in `core/pd-console/src/{app.rs,mux.rs,palette.rs}` (cited inline by file:line); [`beautiful-gui-design`](file:///Users/erichowens/.claude/skills/beautiful-gui-design/SKILL.md) and [`animation-system-architect`](file:///Users/erichowens/.claude/skills/animation-system-architect/SKILL.md) skills; [gpui-animation — lib.rs](https://lib.rs/crates/gpui-animation) (confirms the `delta`-closure model, no transforms added).*
