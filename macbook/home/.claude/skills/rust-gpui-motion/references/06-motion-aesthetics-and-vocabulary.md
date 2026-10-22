# Motion Aesthetics & Vocabulary

> *"Splendid, retro-futuristic, buttery."* Buttery is not a feeling you bolt on at the end — it is honest 60fps, motion that ends the instant its job is done, and a curve that decelerates like a heavy door settling on a good hinge. This document is the motion contract for the pd-operator-console gpui app. It is grounded in the real `mod motion` at `core/pd-console/src/app.rs:211-246` and the one live `with_animation` timeline at `app.rs:813-819`.

---

## The hard constraint, stated once

**gpui 0.2.2 has no fluent transform.** There is no `.scale()`, no `.translate()`, no `.rotate()` on a `Div`. The web verbs every motion designer reaches for — *lift, slide, zoom, spring, pop* — do not exist as transforms here. The compositor is Metal; the element tree is laid out every frame and painted by the GPU. Framer Motion, GSAP, View Transitions, `will-change`, `cubic-bezier()` CSS — **none of it exists.** Every reference to them in the `animation-system-architect` skill must be *translated*, not copied.

What you actually have:

| Web verb you want | gpui 0.2.2 primitive that fakes it | Where it lives in our code |
|---|---|---|
| `transform: scale(1.02)` lift | `shadow(BoxShadow{ blur, spread })` glow growing | `motion::glow` `app.rs:225` |
| `transform: translateY(-2px)` lift | `shadow(BoxShadow{ offset })` hard drop | `motion::hard_offset` `app.rs:237` |
| `opacity` fade / pulse | `.opacity(f32)` + `with_animation` delta closure | dot pulse `app.rs:813` |
| hover color transition | `.hover(\|s\| s.bg(...).text_color(...))` (instant) | gate btn `app.rs:1006` |
| layout spring / accordion | animated layout **fraction** (`flex_basis`/`w` driven by delta) | *not yet built* |
| easing curve | `with_easing(fn(f32)->f32)` or a hand-written closure | `motion::swoosh` `app.rs:220` |

The mental model: **opacity + shadow + hover-color + animated-layout-fraction.** Four levers. Everything "buttery" is a tasteful combination of those four, gated to ≤500ms.

---

## Part 1 — Why these curves read buttery

### Durations: 100–300ms is the butter zone

Both design skills converge on the same window: *"100–300ms, ease-out to enter / ease-in to exit"* (`beautiful-gui-design` Visual System Rules) and *"Micro-interactions longer than the user action they acknowledge feel sluggish, not refined"* (`animation-system-architect` Anti-Pattern #4). Our `motion` module already caps at `RISE_MS: u64 = 500` (`app.rs:217`) and the comment at `app.rs:213` enforces "≤500ms." Tighten that into a tier table:

| Tier | Duration | Use | Curve |
|---|---|---|---|
| **Instant** | 0ms (no `with_animation`, just `.hover()`) | hover color/glow, focus border | gpui paints next frame |
| **Flick** | 90–140ms | button press ack, flag flick-up | ease-out (`swoosh`) |
| **Settle** | 160–260ms | pane focus glow bloom, card enter, approve→land confirm | ease-out (`swoosh`) |
| **Exit** | 120–200ms | dismiss, cancel, card leave | ease-**in** (mirror of swoosh) |
| **Ambient** | 1800–2600ms, `.repeat()` | breathing presence dot, flag-pulse beacon | `pulsating_between` |

> **Sidenote — why the enter is slower than the exit.** Entering is *information arriving*; the eye needs a beat to register the new thing, so 160–260ms reads considered. Leaving is *information you've already processed*; drag it out and you feel held up. Enter slow-ish, exit snappy. This is the ease-out/ease-in asymmetry, encoded in duration as well as curve.

### Easing: why `linear` is wrong, and what gpui actually ships

A linear ramp moves at constant velocity, then **stops dead** at the end. Nothing physical does that — every real object decelerates into rest. Linear motion reads as cheap and robotic precisely because it has no deceleration; your eye clocks the abrupt stop as a glitch. The only honest use of `linear` in this app is a *continuous* loop with no start/stop to betray it — a marquee, a spinner, a shimmer sweep — where there is no terminal frame to land badly.

gpui 0.2.x exports (confirmed against `zed/crates/gpui/examples/animation.rs`): **`ease_in_out`**, **`bounce`** (wraps another easing, e.g. `bounce(ease_in_out)`), **`pulsating_between(lo, hi)`**, and **`linear`**. Notably there is **no standalone `ease_out` export** — so for an ease-out enter we write our own, which is exactly what `motion::swoosh` is:

```rust
// app.rs:219 — `--swoosh`: graceful fast-out settle (≈ quintic ease-out).
pub fn swoosh(t: f32) -> f32 {
    1.0 - (1.0 - t).powi(5)
}
```

`swoosh(t)` starts fast and decelerates hard into 1.0 — quintic ease-out. It is our default enter/settle curve. For an **exit**, mirror it (ease-in): `t.powi(5)` — slow start, fast finish, snatching the element away. Add that as `motion::whisk`:

```rust
/// `--whisk`: ease-in exit, mirror of swoosh. Slow start, fast away.
pub fn whisk(t: f32) -> f32 { t.powi(5) }
```

> **Decision Point — spring vs. tween.** The `animation-system-architect` skill loves interruptible springs (`stiffness: 300, damping: 25`). gpui 0.2.2 has **no spring solver**. A spring is just an easing closure: `1.0 - (1.0 - t).powi(5)` *is* a critically-damped settle for our purposes. Do **not** try to port `react-spring` physics — write a closure that decelerates and stop there. If you genuinely need overshoot (a "pop"), use `bounce(ease_in_out)`, sparingly, and only on a positive confirmation (approve→land), never on a routine hover.

### `pulsating_between` is the ambient engine

Our one shipped timeline (`app.rs:813-819`):

```rust
dot.with_animation(
    SharedString::from(format!("dot-pulse-{id}")),
    Animation::new(Duration::from_millis(2400))
        .repeat()
        .with_easing(pulsating_between(0.55, 1.0)),
    |el, delta| el.opacity(delta),     // delta is the eased 0.55..1.0 value
)
```

`pulsating_between(0.55, 1.0)` triangle-waves the delta between 0.55 and 1.0; the closure pipes it straight into `.opacity()`. 2400ms is a slow human breath (~25 breaths/min) — calm, not anxious. **This is the only ambient pattern you ever need.** Every "alive" cue in the console is `pulsating_between` into `.opacity()` or into a `shadow` alpha, with the period encoding urgency (slower = calm presence, faster = wants attention).

---

## Part 2 — Retro-futuristic motion language (with restraint)

The aesthetic is maritime-signal + neobrutalist + a faint CRT/cassette nostalgia. The *temptation* is to make everything dither and shimmer. **Restraint is the whole craft here.** Retro-futurist cues are seasoning, not the meal — one per surface, on the moments that matter (state change, arrival, alarm), never as idle chrome.

| Cue | What it evokes | gpui recipe | When (and only when) |
|---|---|---|---|
| **Dither dissolve** | old Mac 1-bit transitions | step `.opacity()` through 3–4 discrete levels (`0 → .33 → .66 → 1`) instead of smooth, via a stepped easing closure | a surface/pane *appearing* — once, on mount |
| **Shimmer sweep** | loading bar / scanline | a `linear` `.repeat()` moving a bright `motion::glow` band's alpha across a row | a row that is *working* (agent mid-task), and nothing else |
| **Sparkle glint** | "new!" / success | a single 140ms `swoosh` opacity flash of an accent overlay, no repeat | approve→land success, PR merged |
| **CRT/cassette settle** | power-on, tracking-lock | a `bounce(ease_in_out)` on a focus glow's spread (overshoot then settle) | pane gaining focus — at most |
| **Flag flick** | a real signal flag snapping taut | 110ms `swoosh` opacity 0→1 + a 2px `hard_offset` shadow that retracts to 0 | a maritime flag hoisting on state change |

> **Anti-Pattern — "Retro Vomit."** **Symptom:** every pane dithers, every row shimmers, the focus dot *and* three flags *and* a scanline are all animating at once. **Detection:** count simultaneously-animating elements in a single screenshot/recording — more than **2** ambient loops on screen is a smell (mirrors the `beautiful-gui-design` "Rainbow Vomit" rule, applied to motion). **Fix:** ambient motion is a scarce budget. One breathing dot for the focused pane, plus at most one working-row shimmer. Everything else is instant or one-shot. Decoration that outlasts intent is the failure.

---

## Part 3 — Micro-interaction catalog for the agent-fleet console

Each entry: the verb, the gpui primitive, duration, easing, and the real code anchor.

### 1. Pane focus (the "wheel")
**Goal:** prove which pane has keyboard focus. **Primitive:** `shadow(motion::glow(accent, 0.45, 16, 1))` — a mustard halo (`app.rs:783`). Unfocused panes preview it on hover at 0.18 alpha (`app.rs:787`). **Duration:** instant (paint-next-frame on `cx.notify()`). **Buttery upgrade:** on *gaining* focus, run a one-shot 200ms `swoosh` that blooms the glow's spread from 0→1 (a CRT power-on settle); steady-state stays static.

```rust
.when(is_focused, |s| s.shadow(motion::glow(theme.accent, 0.45, 16.0, 1.0)))
.when(!is_focused, |s| s.hover(|h|
    h.border_color(rgb(theme.accent))
     .shadow(motion::glow(theme.accent, 0.18, 10.0, 0.0))))
```

### 2. Breathing presence dot ✅ shipped
**Goal:** the focused pane is *alive*. **Primitive:** `with_animation` + `pulsating_between(0.55, 1.0)` → `.opacity()` (`app.rs:813`). **Duration:** 2400ms `.repeat()`. Idle panes render a static hollow `○`. **This is the reference implementation** — copy its shape for every other ambient cue.

### 3. Steer-send pulse
**Goal:** acknowledge a steering message left the operator's hands and is in flight to an agent. **Primitive:** a one-shot accent glow flash on the send affordance — 140ms `swoosh` opacity 0→1→fade on a `motion::glow(accent, 0.5, 12, 0)` overlay — *plus* the existing `control_flash` text confirm ("sent to cartographer — watch the lane", `app.rs:685`). **Duration:** Flick (≤140ms). **Easing:** `swoosh`. Not a repeat — send is a discrete event; a looping pulse would lie that it's still sending.

### 4. Card hop (board reorder / dispatch entering the queue)
**Goal:** a dispatch card arrives in the Nightshift review queue. **No translate exists** — so "hop in" is a **dither dissolve**: opacity stepped `0 → .33 → .66 → 1` over ~220ms with a stepped easing closure, paired with a 2px `motion::hard_offset(sunken, 0, 2)` shadow that retracts to 0 (the neobrutalist "drop into place"). **Duration:** Settle. **Anti-pattern:** do not animate the card's `h`/`w` to grow it in — that is layout thrash (`animation-system-architect` Anti-Pattern #1); fade + shadow only.

### 5. Approve → land
**Goal:** the highest-stakes positive action — operator approves a dispatch, it lands. **Primitive:** the gate button already swaps to `bg(raised)` + `motion::glow(color, 0.22, 8, 0)` on hover (`app.rs:1006`); on click it sets `control_flash = "dispatch approved → landing"` (`app.rs:1014`). **Buttery upgrade:** a single **sparkle glint** — one 160ms `bounce(ease_in_out)` opacity flash of a `landed`-green overlay (`theme.landed`, `0x15803d` light / `0x6dd3a8` dark). The `bounce` overshoot is *earned* here — it's a celebration, the one place a little spring is honest. **Duration:** Settle, no repeat.

### 6. Flag-pulse (maritime alarm / HiTL)
**Goal:** an agent hoists a flag that demands attention — Foxtrot (awaiting-human) or Juliett (mayday) per `maritime.rs:230-239`. **Primitive:** the flag badge (32×20 colored block + ICS letter, `maritime.rs:171`) gets a `with_animation` `pulsating_between(0.45, 1.0)` on its background alpha — but **faster than the breathing dot**: ~900–1200ms for *awaiting*, ~600ms for *mayday*. Period encodes urgency. Calm-presence flags (engaged/resting) do **not** pulse — only attention-seeking states. **Easing:** `pulsating_between`. **Decision Point:** pulse **alpha/glow**, not the letter's opacity — the ICS letter must stay legible at all times (it carries meaning; a half-faded "J" is a readability defect, mirroring the `beautiful-gui-design` 4.5:1 floor).

### 7. Cost-ledger tick / value landing
**Goal:** a new cost row or a budget threshold crossing registers without yanking the eye. **Primitive:** a 200ms `swoosh` opacity 0→1 on the new row + a brief `raised` bg wash that decays to `panel`. **Duration:** Settle. No repeat. If a budget **cap** is breached, escalate to a single `gated`-crimson glint (sparkle, item #5's recipe but in `theme.gated`).

### 8. Control-flash status line (already shipped, generalize it)
The `control_flash: Option<String>` field (`app.rs:443`) + `when_some` render (`app.rs:899`) is the console's **transient-confirmation bus**. Every micro-interaction above pairs its visual cue with a `control_flash` string so the action is legible to screen-reading-by-eye and survives a glance away. Keep that pairing mandatory: *every motion cue has a text twin.*

---

## Part 4 — Before / After

**Before** — a "send to agent" button that ports web habits into gpui:

```rust
// WRONG: pretends gpui has CSS transitions + scale, animates layout, loops forever.
div()
    .w(px(120.0))
    .hover(|s| s.w(px(128.0)))          // animating width = layout thrash
    .with_animation(                      // a looping pulse on a discrete action
        "send-pulse",
        Animation::new(Duration::from_millis(1200)).repeat(),
        |el, d| el.opacity(0.5 + d * 0.5),
    )
```
Problems: (1) `.hover` width change is layout work, not compositor work — `animation-system-architect` Anti-Pattern #1. (2) gpui won't smoothly tween the `w` anyway — it snaps. (3) A `.repeat()` on *send* lies: send is one event, not an ongoing state. (4) No text confirm, so a screen-glance-away misses it entirely.

**After** — honest gpui, one-shot, ≤140ms, with a text twin:

```rust
// RIGHT: instant hover color/glow; click fires a one-shot swoosh flash + control_flash text.
div()
    .id("steer-send")
    .px(px(12.0)).py(px(5.0))
    .text_color(rgb(theme.accent_ink))
    .cursor_pointer()
    .hover(|s| s.bg(rgb(theme.raised))
               .shadow(motion::glow(theme.accent, 0.22, 8.0, 0.0)))   // instant, GPU-cheap
    .on_click(cx.listener(move |this, _ev, _w, cx| {
        if let Some(tx) = &this.control_tx { let _ = tx.send(ControlMsg::Steer { /* … */ }); }
        this.control_flash = Some("sent to cartographer — watch the lane".into());  // text twin
        this.send_glint = Some(Instant::now());   // drives a 140ms one-shot swoosh overlay
        cx.notify();
    }))
// elsewhere, the overlay reads send_glint.elapsed(), maps 0..140ms → swoosh(t) → .opacity(), clears when done
```

Why it's buttery: hover feedback is *instant* (next paint), the click ack is a **single** 140ms ease-out flash that ends the moment the action is acknowledged, and the `control_flash` text makes it legible without the motion. Nothing loops, nothing animates layout, nothing outlasts intent.

---

## Part 5 — Reduced-motion & honesty

gpui has no `prefers-reduced-motion` media query, but the principle from both skills still binds: **motion must degrade to a static state hint, never to silence.** Read the OS setting once at startup (`NSWorkspace.accessibilityDisplayShouldReduceMotion` on macOS) into a global, mirroring `THEME_MODE` (`app.rs:181`). When set:
- Ambient loops (dot, flags) → **static** at their bright endpoint (full-opacity dot, full-alpha flag) — presence is shown by *state*, not pulsing.
- One-shot enters/exits → **instant** opacity swap, no tween.
- Status still flashes via `control_flash` text — the *information* survives; only the travel is removed.

This is the `animation-system-architect` rule "reduced branch preserves orientation, not just silence" mapped to gpui: a motion-sensitive operator must still see *which agent needs them* — the Foxtrot flag is brightly lit, just not throbbing.

---

## Quality Gates

- [ ] **No layout-property animation.** Grep the diff for `with_animation` closures touching `.w(`, `.h(`, `.flex_basis`, `.px/.py` — animate `.opacity()` / `shadow` only, unless it's a *deliberate* accordion using an animated layout fraction with a documented `// motion: layout fraction` comment.
- [ ] **Every `with_animation` ≤500ms OR `.repeat()` with period ≥1800ms.** No mid-length loops (a 400ms repeat reads as a stutter, not a breath).
- [ ] **No `linear` on a start/stop animation.** `linear` is legal only on a continuous `.repeat()` with no terminal frame (shimmer/marquee). Enter/settle = `swoosh`; exit = `whisk`; pulse = `pulsating_between`.
- [ ] **Enter slower than exit.** Enter/settle 160–260ms; exit 120–200ms. Asymmetry is intentional.
- [ ] **One-shot for discrete events, repeat only for ongoing state.** A send/approve/merge is a flash; "agent working" / "pane focused" / "needs human" is a loop.
- [ ] **≤2 ambient loops on screen at once.** Count them in a recording. The breathing dot + at most one working-row shimmer/attention-flag.
- [ ] **Every motion cue has a `control_flash` text twin.** Visual + legible, both.
- [ ] **ICS letters / meaningful glyphs never drop below full opacity.** Pulse the *alpha/glow*, not the readable text.
- [ ] **Retro cues are seasoning.** Dither/shimmer/sparkle/CRT appear on state-change or arrival, never as idle chrome.
- [ ] **Reduced-motion path degrades to a static state hint**, not to nothing.
- [ ] **No phantom web APIs.** Grep for `scale`, `translate`, `cubic-bezier`, `transition:`, `will-change`, `Framer`, `gsap` in `.rs` — every hit is a porting error.

---

### Sources
- [zed-industries/zed — gpui animation example](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/animation.rs) (confirmed `Animation::new`, `.repeat()`, `.with_easing()`, `ease_in_out`, `bounce`, `pulsating_between`, `linear`, `|el, delta|` closure)
- [docs.rs/gpui](https://docs.rs/gpui)
- [gpui-animation — lib.rs](https://lib.rs/crates/gpui-animation)
- Real code: `core/pd-console/src/app.rs:211-246` (`mod motion`), `app.rs:813-819` (breathing dot), `app.rs:1006-1031` (dispatch gate buttons), `app.rs:443/899` (`control_flash` bus); `core/pd-console/src/palette.rs` (theme roles); `core/pd-console/src/maritime.rs:171-239` (ICS flag badges).
