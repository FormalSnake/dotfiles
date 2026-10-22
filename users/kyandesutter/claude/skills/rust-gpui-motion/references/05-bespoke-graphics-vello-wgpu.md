# Bespoke Graphics in gpui — Custom Painting, Vello/wgpu Surfaces, and the Cassette-Futurism Layer

> **Scope.** When the element tree (`div().bg().shadow().child()`) genuinely cannot express what you need — ordered dithering, a shimmer sweep, sparkle particles, scanlines, a scrubbed playhead, anti-aliased causal-thread beziers — you drop below the widget layer. This doc maps three escape hatches in increasing cost: (1) **gpui's low-level paint API** (`canvas` + `paint_quad` + `paint_path`) for things that are still "rectangles and paths in the gpui scene," (2) **a Vello/wgpu surface** for compute-rasterized vector + shader work the gpui scene can't do, and (3) the **retro-futuristic texture layer** (dither / shimmer / sparkle / scanline / grain) and where each one belongs.
>
> **Target is gpui 0.2.2 (Metal, macOS), not the web.** There is no `transform`, no `scale()`, no Framer Motion, no GSAP, no `<canvas>` 2D context, no shader-on-a-div. Everything below is Rust.

---

## 0. Where you are in the stack (read this first)

pd-console is a **gpui shell**. The decision is canonized in `docs/adr/0086-operator-console-rendering-stack.md`:

> *"The operator console is a gpui **shell**; bespoke-vector visualizations are Vello/wgpu **surfaces** the shell hosts."*

That ADR draws the exact line this doc operationalizes. gpui is excellent for the pane tree, hover-reactive widgets, and shaped text. What gpui's widget model **cannot** do well, per the ADR:

> *"arbitrary compute-rasterized vector art — smooth cubic-bezier causal threads, a scrubbed playhead, anti-aliased path fills at 60fps. gpui has **no fluent transform** (no scale / translate); 'motion' there is faked with box-shadow + opacity."*

So there are **three tiers**, and the engineering question is always "what is the lowest tier that does the job":

| Tier | API | Use it for | Real example |
|---|---|---|---|
| **T1 — element tree** | `div()`, `.shadow()`, `.opacity()`, `with_animation` | Widgets, layout, hover/focus, glow, the beacon pulse | `app.rs` `motion::glow`, the pulsing focus dot |
| **T2 — gpui low-level paint** | `canvas()`, `window.paint_quad(quad(...))`, `PathBuilder` + `window.paint_path` | Dither grids, scanlines, sparkles, sparklines, simple custom shapes that are still *quads and paths in gpui's scene* | (not yet in pd-console — this doc's net-new) |
| **T3 — Vello/wgpu surface** | `vello::Scene`, `kurbo::BezPath`, `peniko::Fill`, `wgpu` device/queue | Smooth bezier fills at 60fps, scrubbed playhead, shader effects, the v12 "living harbor" | `core/pd-timeline-proto/src/scene.rs` |

**Decision Point — T2 vs T3.** Stay in **T2** if the effect decomposes into ≤ a few thousand axis-aligned quads or a handful of stroked paths, redrawn at interaction rate (not 60fps continuous). Go to **T3** the moment you need *anti-aliased curved fills*, *a fragment shader*, or *continuous 60fps animation of vector geometry*. T3 is real systems work (a second GPU stack in the window); never reach for it to draw a rectangle.

---

## 1. T1 recap — what the element tree already buys you (so you don't drop a tier too early)

Before any `canvas`, remember pd-console already fakes "lift / glow / spring" without a transform. From `core/pd-console/src/app.rs:144`:

```rust
// ── Motion — gpui 0.2.2 has no fluent transform, so "lift/glow/spring" reads
// through hover color + box-shadow (instant, GPU-cheap) and with_animation
// one-shot/looping timelines.
mod motion {
    use gpui::{point, px, BoxShadow, Hsla};

    /// A soft halo glow (focus ring / hover). Alpha rides on `Hsla`.
    pub fn glow(color: u32, alpha: f32, blur: f32, spread: f32) -> Vec<BoxShadow> {
        let mut h: Hsla = gpui::rgb(color).into();
        h.a = alpha;
        vec![BoxShadow { color: h, offset: point(px(0.0), px(0.0)),
                         blur_radius: px(blur), spread_radius: px(spread) }]
    }
    /// Neobrutalist hard offset drop — the hover "lift" cue (no translate in 0.2.2).
    pub fn hard_offset(color: u32, dx: f32, dy: f32) -> Vec<BoxShadow> { /* ... */ }
}
```

And the looping "presence beacon" — the closest thing pd-console has to a shader effect today — is pure `with_animation` over **opacity** (`app.rs:659`):

```rust
dot.with_animation(
    SharedString::from(format!("dot-pulse-{id}")),
    Animation::new(Duration::from_millis(2400))
        .repeat()
        .with_easing(pulsating_between(0.55, 1.0)),
    |el, delta| el.opacity(delta),     // delta closure: the ONLY animatable channel here
)
```

**This is the cassette-futurism aesthetic done in T1.** A "breathing" indicator is opacity + glow, not a particle system. **Reach for T2/T3 only when the texture itself is the point** (you literally need a Bayer grid or a shimmer gradient sweeping across a surface), not when a glow would read the same.

**Anti-Pattern — Dropping a tier for an effect T1 already does.**
- **Symptom:** A `canvas` closure that paints a soft circle that "pulses," reimplementing the beacon.
- **Detection:** grep for `canvas(` whose paint body only emits one quad with an animated alpha.
- **Fix:** Delete it. Use `with_animation(..., |el, delta| el.opacity(delta))` + `motion::glow`. T2 is for *texture*, not for *one thing fading*.

---

## 2. T2 — gpui's low-level paint API (`canvas`, `paint_quad`, `paint_path`)

gpui exposes a hybrid immediate/retained model. For bespoke drawing **inside** a gpui element, the entry point is the **`canvas` element** ([Zed `painting.rs` example](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/painting.rs)). It takes a **prepaint** closure and a **paint** closure:

```rust
use gpui::{canvas, quad, px, point, size, bounds, Bounds, Pixels, Background, PathBuilder};

canvas(
    // prepaint: measure / compute geometry from the laid-out bounds.
    move |bounds, _window, _cx| compute_cells(bounds),
    // paint: emit quads/paths into the scene for THIS frame.
    move |bounds: Bounds<Pixels>, cells, window, _cx| {
        for cell in &cells {
            window.paint_quad(quad(
                cell.bounds,             // Bounds<Pixels>
                px(0.),                  // corner_radius
                cell.color,              // Background (impl Into<Background>)
                px(0.),                  // border_width
                gpui::transparent_black(),
                gpui::BoxShadow::default(),
            ));
        }
    },
)
.size_full()
```

Two paint primitives matter:

- **`window.paint_quad(quad(bounds, radius, bg, border_w, border_color, shadow))`** — a colored rounded rect. This is your dither pixel, your scanline, your sparkle. *Must be called inside the paint phase* (the canvas paint closure, or a custom `Element::paint`).
- **`window.paint_path(path, color)`** where `path` comes from a `PathBuilder`:

```rust
let mut b = PathBuilder::fill();          // or PathBuilder::stroke(px(1.))
b.move_to(point(px(0.), px(0.)));
b.curve_to(ctrl, end);                    // quadratic bezier control + end
b.line_to(point(px(40.), px(8.)));
b.close();
let path = b.build().unwrap();
window.paint_path(path, gpui::rgb(0xFFDB33)); // mustard brand
```

**Decision Point — `canvas` vs a full custom `Element`.** Use `canvas(prepaint, paint)` for *"short-term custom drawing inside a view"* (the docs' words). Implement a full `impl Element` (with `request_layout` / `prepaint` / `paint`) only when the thing needs its own layout participation, hit-testing, or to be reused as a first-class element across panes. For a dither overlay or a sparkline, `canvas` is correct and far less code.

**Coordinates & HiDPI.** `bounds` in the paint closure is in **logical pixels**; gpui handles the Retina scale for quads/paths. Your Bayer math should be in logical px and let the compositor upscale — same discipline the timeline proto uses (`Layoutspec { scale }` in `scene.rs:45`).

**Animating a T2 canvas.** `canvas` itself isn't a `with_animation` target. To animate it you drive a `f32`/clock value on the owning view and call `cx.notify()` each tick (pd-console calls `cx.notify()` everywhere — `app.rs:500, 534, 638…`), recomputing geometry from the new phase in the paint closure. For a *continuous 60fps* sweep this is the boundary where T3 starts to win — see §6.

---

## 3. T2 recipe — ORDERED (Bayer) DITHERING as gpui quads

pd-console's sibling `fleet-config-ui` already declares a dither *contract* — `src/ships/DitherPipeline.tsx` is a dependency-free boundary marker for "bloom-then-Bayer postprocessing" with an exposed palette:

```tsx
const DEFAULT_DITHER_PALETTE = [
  'var(--pd-bg)', 'var(--pd-text)', 'var(--pd-accent)',
  'var(--pd-success)', 'var(--pd-line)',
] as const;
// "named boundary for bloom-then-Bayer postprocessing … enabled=false is a
//  legal no-op for reduced-motion, snapshot, and server-rendered views."
```

That web component is a *placeholder around an EffectComposer*. In gpui there is no EffectComposer and no postprocessing pass over the div tree — so ordered dithering is done **forward**, as quads, via a Bayer threshold matrix. This is the canonical T2 effect:

```rust
// 4×4 ordered Bayer matrix, normalized 0..1. The classic recursive matrix.
const BAYER4: [[f32; 4]; 4] = [
    [ 0.0,  8.0,  2.0, 10.0],
    [12.0,  4.0, 14.0,  6.0],
    [ 3.0, 11.0,  1.0,  9.0],
    [15.0,  7.0, 13.0,  5.0],
]; // divide by 16.0 at use

/// Paint a value-ramp dithered between two palette roles into `bounds`.
/// `value(x,y)` returns 0..1 (e.g. a radial falloff, a heat field, a gradient).
fn paint_dither(
    window: &mut gpui::Window,
    bounds: gpui::Bounds<gpui::Pixels>,
    cell: f32,                 // logical px per dither pixel (chunky = more retro)
    lo: u32, hi: u32,          // two palette roles, e.g. bg + accent
    value: impl Fn(f32, f32) -> f32,
) {
    let cols = (f32::from(bounds.size.width)  / cell).ceil() as i32;
    let rows = (f32::from(bounds.size.height) / cell).ceil() as i32;
    for gy in 0..rows {
        for gx in 0..cols {
            let v = value(gx as f32 / cols as f32, gy as f32 / rows as f32);
            let threshold = BAYER4[(gy & 3) as usize][(gx & 3) as usize] / 16.0;
            let color = if v > threshold { hi } else { lo };
            let origin = gpui::point(
                bounds.origin.x + gpui::px(gx as f32 * cell),
                bounds.origin.y + gpui::px(gy as f32 * cell),
            );
            window.paint_quad(gpui::quad(
                gpui::Bounds { origin, size: gpui::size(gpui::px(cell), gpui::px(cell)) },
                gpui::px(0.), gpui::rgb(color), gpui::px(0.),
                gpui::transparent_black(), gpui::BoxShadow::default(),
            ));
        }
    }
}
```

**Honor the brand.** `lo`/`hi` must come from `palette.rs` roles (`bg: 0xf5f5f0`, `accent: 0xffdb33`, `gated: 0xc41e30`), never hardcoded — `scripts/check-brand-colors.mjs` fails CI on cinnabar `#CC3D2E` / brass / patina (`palette.rs:8`). Theme flip (`Ctrl-A g`) must re-skin the dither on the next `cx.notify()`.

**Decision Point — cell size = your budget knob.** `cell = 2.0` on a 600×400 region is ~60k quads/frame — fine for a static panel background, a problem at 60fps. `cell = 6.0`–`8.0` is "cassette chunky," ~4k quads, and reads *more* retro. Pick the largest cell that still looks like dithering; it's also your perf ceiling.

**Anti-Pattern — Per-pixel dither at screen resolution.**
- **Symptom:** `cell = 1.0` over a full pane; frame time spikes, fans spin.
- **Detection:** quad count = pane_px_w × pane_px_h.
- **Fix:** Chunk to ≥4px cells, or move the effect to a **T3 fragment shader** (§6) where a Bayer dither is ~6 lines of WGSL and free per-pixel.

---

## 4. T2 recipes — SCANLINES, SHIMMER, SPARKLE

### Scanlines / grain (cheap, static, very on-aesthetic)
Horizontal scanlines are one translucent quad per other row:

```rust
fn paint_scanlines(window: &mut gpui::Window, b: gpui::Bounds<gpui::Pixels>, line_h: f32) {
    let mut scan: gpui::Hsla = gpui::black().into();
    scan.a = 0.06;                                  // barely-there CRT darkening
    let rows = (f32::from(b.size.height) / (line_h * 2.0)).ceil() as i32;
    for r in 0..rows {
        let y = b.origin.y + gpui::px(r as f32 * line_h * 2.0);
        window.paint_quad(gpui::quad(
            gpui::Bounds { origin: gpui::point(b.origin.x, y),
                           size: gpui::size(b.size.width, gpui::px(line_h)) },
            gpui::px(0.), scan, gpui::px(0.),
            gpui::transparent_black(), gpui::BoxShadow::default(),
        ));
    }
}
```
Grain is the same idea with a hashed per-cell alpha (`hash(gx,gy,frame)` → 0.0..0.04). Keep alpha tiny; grain that reads as grain at a glance is too strong.

### Shimmer sweep (a moving highlight band)
No gradient-fill primitive and no transform, so a shimmer is **a stack of quads with a triangular alpha falloff**, its center driven by an animated phase. Drive `phase: f32` (0..1) on the view, `cx.notify()` per tick:

```rust
fn paint_shimmer(window: &mut gpui::Window, b: gpui::Bounds<gpui::Pixels>,
                 phase: f32, band_px: f32, tint: u32) {
    let center = f32::from(b.size.width) * phase;       // sweep L→R
    let steps = (band_px / 3.0) as i32;                 // 3px sub-bands
    for i in -steps..=steps {
        let dx = i as f32 * 3.0;
        let a = (1.0 - (dx.abs() / band_px)).max(0.0) * 0.25;   // triangular peak
        let mut c: gpui::Hsla = gpui::rgb(tint).into();
        c.a = a;
        let x = b.origin.x + gpui::px(center + dx);
        window.paint_quad(gpui::quad(
            gpui::Bounds { origin: gpui::point(x, b.origin.y),
                           size: gpui::size(gpui::px(3.0), b.size.height) },
            gpui::px(0.), c, gpui::px(0.),
            gpui::transparent_black(), gpui::BoxShadow::default(),
        ));
    }
}
```
This is the "scanning / loading" cue for a sortie that's mid-flight — the T2 cousin of the T1 breathing beacon. Tint = `accent 0xffdb33`.

### Sparkle micro-particles
A handful (≤ ~40) of tiny quads (or `PathBuilder::fill` diamonds) at deterministic positions, each twinkling on its own phase offset so they don't blink in lockstep:

```rust
struct Spark { x: f32, y: f32, phase: f32 }   // phase seeded per-spark, NOT shared

fn paint_sparkles(window: &mut gpui::Window, b: gpui::Bounds<gpui::Pixels>,
                  sparks: &[Spark], clock: f32) {
    for s in sparks {
        let tw = ((clock + s.phase) * std::f32::consts::TAU).sin() * 0.5 + 0.5; // 0..1
        let mut c: gpui::Hsla = gpui::rgb(0xffdb33).into();
        c.a = tw * 0.9;
        let sz = gpui::px(2.0 + tw * 2.0);          // size twinkles WITH alpha
        window.paint_quad(gpui::quad(
            gpui::Bounds { origin: gpui::point(b.origin.x + gpui::px(s.x),
                                               b.origin.y + gpui::px(s.y)),
                           size: gpui::size(sz, sz) },
            sz, c, gpui::px(0.), gpui::transparent_black(), gpui::BoxShadow::default(),
        ));
    }
}
```

**Decision Point — particle count.** Sparkle is *micro*. 12–40 deterministic particles. If you want a firefly *biofield* over the whole filetree (hundreds, with motion + soft bloom), that is **T3** — ADR-0086 names "the biofield (fireflies over the filetree)" explicitly as a Vello surface, not a gpui widget.

**Anti-Pattern — Lockstep twinkle.**
- **Symptom:** every sparkle/scanline flashes on the same frame; reads as a strobe, not life.
- **Detection:** the alpha for all particles is `f(clock)` with no per-particle offset.
- **Fix:** seed a `phase`/offset per particle (and per pane via the `id`, like `dot-pulse-{id}` in `app.rs:660`) so the field shimmers incoherently.

---

## 5. `reduced-motion`, snapshots, and the off-switch

The web `DitherPipeline` makes `enabled=false` *"a legal no-op for reduced-motion, snapshot, and server-rendered views."* Carry that contract into gpui: **every T2/T3 effect needs a static fallback.** There is no `prefers-reduced-motion` media query in gpui — wire it to a config/env flag (mirror `PD_CONSOLE_THEME`, read in `init_theme_from_env`, `app.rs:130`), e.g. `PD_CONSOLE_FX=off`:

- **Dither:** still paints (it's static texture) — keep it.
- **Shimmer / sparkle / sweep:** paint a single mid-phase frame, stop calling `cx.notify()` on a clock. The surface looks "lit" without animating.
- **Snapshot/test builds:** the engine REPL bin (`Cargo.toml:7`, no-gpui CI gate) never compiles any of this — keep all paint code behind `#[cfg(feature = "gpui")]`, exactly as the gpui bin already is (`required-features = ["gpui"]`).

This is also a correctness gate: the Linux `rust-console` CI must never compile Vello's heavy GPU deps (ADR-0086 §Consequences).

---

## 6. T3 — Vello/wgpu surfaces (the ceiling, already proven)

When T2 quads can't express it — *anti-aliased curved fills, a scrubbed playhead, a real fragment shader, continuous 60fps vector animation* — you render with **Vello** (Linebender's compute-based GPU path renderer) on **wgpu** (lowers to Metal on macOS). pd-console's proof spike `core/pd-timeline-proto` already does this against live daemon data.

The scene is hand-built vector geometry — `scene.rs:1`:

> *"Everything here is bespoke GPU vector rendering: we hand-build paths (lines, dots, blocks, smooth cubic-bezier causal threads) and feed Parley glyph runs straight into the same Vello scene. No widget tree — full control of every pixel."*

```rust
// core/pd-timeline-proto/src/scene.rs
use kurbo::{Affine, BezPath, Circle, Line, Point, Rect, Stroke};
use peniko::{Brush, Color, Fill};
use vello::Scene;

const PLAYHEAD: Color = Color::rgb8(0xff, 0x6b, 0x35);
const THREAD:   Color = Color::rgb8(0x4f, 0xd1, 0xc5);

// A causal thread is a real cubic bezier, anti-aliased — impossible in T2 quads:
let mut path = BezPath::new();
path.move_to(start);
path.curve_to(ctrl1, ctrl2, end);
scene.stroke(&Stroke::new(2.0), Affine::IDENTITY, THREAD, None, &path);
scene.fill(Fill::NonZero, Affine::IDENTITY, &Brush::Solid(track_color(t)), None, &marker);
```

And the wgpu render loop confirms Metal (`main.rs:148`): *"Report the chosen GPU backend — this proves Metal on macOS"* → `backend: Metal, Apple M4 Max`. The render path is `Renderer::render_to_surface(device, queue, &scene, &surface_texture, &RenderParams{...})` then `surface_texture.present()`.

### The two integration paths (ADR-0086, verbatim shape)

ADR-0086 considered three bridges and **sequences two**:

| # | Bridge | Verdict |
|---|--------|---------|
| 1 | Port viz down to gpui | **Rejected** — gpui can't render the smooth beziers/scrub. |
| 2 | **Embed** a wgpu/Vello surface *inside* the gpui window (custom GPU element, shared device/queue) | **The target** — one window, viz as a first-class pane. Hard. Long-term home for ghost-filetree / merge-as-light / biofield. |
| 3 | **Companion window** — gpui console execs the proven `pd-timeline` binary as a child window | **Ship now** — scrubber in the loop this week, zero stack-mixing risk. |

> ADR §"Why this is honest, not a dodge": *"A single-window, two-GPU-stack embed (path 2) is real systems work (sharing the wgpu device with gpui's renderer, or compositing offscreen). Pretending the timeline can 'just drop in' is the hollowness this project keeps catching."*

**Decision Point — embed vs companion.**
- **Companion window (path 3):** the console `Ctrl-A` → Timeline `exec`s the installed `pd-timeline` binary. Choose this **now** and for any viz that's a *focused, modal* experience (the scrubber, a one-off harbor view). Lowest risk; the Vello code keeps running in production while path 2 is built.
- **Embedded surface (path 2):** the viz lives **in the pane tree** next to text panes. Choose this when the viz must be *ambient and persistent* — the ghost filetree, merge-as-light, the biofield. Cost: sharing the `wgpu` device with gpui's renderer (or compositing an offscreen Vello texture into a gpui quad). This is the load-bearing v12 bet; do not pretend it's free.

**Anti-Pattern — Reaching for Vello to draw a sparkline.**
- **Symptom:** a new `wgpu` device spun up for a 40-point activity sparkline.
- **Detection:** Vello/wgpu deps pulled into a surface that draws axis-aligned bars.
- **Fix:** That's `Block::Spark` territory (`app.rs:254`) or a T2 `PathBuilder::stroke`. T3 is justified by *curves at 60fps* or *shaders*, nothing less. A second GPU stack in the window is the most expensive dependency in the console.

### Dither/shimmer as a T3 shader (when T2's quad count loses)
If you genuinely need per-pixel dither at full res and 60fps, it's a **WGSL fragment shader** sampling the Bayer matrix — a custom `wgpu::RenderPipeline` on the same surface as Vello, or a Vello post-pass. ~6 lines of WGSL (`bayer[(coord.x & 3u) + (coord.y & 3u) * 4u]` threshold), free per-pixel. This is the *only* place the web `DitherPipeline`'s "EffectComposer postprocessing" mental model maps cleanly — and it lives in T3, never in the gpui scene.

---

## 7. Before / After — the "agent is thinking" indicator

**Before (T1, what pd-console ships):** the focused-pane dot breathes via opacity (`app.rs:659`). Correct, cheap, on-aesthetic. For "this pane has the wheel," **this is the right tier — don't touch it.**

**After (T2, justified only for a richer state):** a sortie pane that is *mid-flight and streaming* wants more than a breathing dot — it wants the surface to feel *alive and scanning*. That earns a T2 `canvas` overlay: a faint Bayer-dithered amber field (`paint_dither` with `bg`→`accent`, `cell=6.0`) + a slow shimmer sweep (`paint_shimmer`, `band_px=80`, 3s period) gated behind `PD_CONSOLE_FX`. When the sortie lands, the canvas is removed and the pane falls back to the static `motion::glow(landed, …)` border. The **escalation in tier tracks an escalation in meaning** — that's the only honest reason to climb.

What would be *wrong*: porting that same shimmer to a Vello surface (T3) — a second GPU stack to sweep a translucent band a stack of quads draws fine.

---

## 8. Quality Gates

- [ ] **Lowest tier that works.** Every `canvas`/Vello surface justified: T1 glow/opacity can't express it (texture is the point), and for T3 specifically the effect needs *curved AA fills, a shader, or continuous 60fps vector motion*.
- [ ] **Colors are palette roles.** Every `paint_quad`/`paint_path`/Vello `Color` reads a `palette.rs` role; no cinnabar/brass/patina; theme flip (`Ctrl-A g`) re-skins on `cx.notify()`. (`scripts/check-brand-colors.mjs` green.)
- [ ] **Off-switch exists.** Every animated effect has a static frame under `PD_CONSOLE_FX=off`; dither stays (static), shimmer/sparkle freeze mid-phase. Mirrors `DitherPipeline enabled=false`.
- [ ] **Quad budget bounded.** Dither `cell ≥ 4px`; sparkles ≤ ~40; no per-screen-pixel quad loops at 60fps (those go to a T3 shader).
- [ ] **Phases are per-element.** Sparkle/shimmer/beacon offsets seeded per particle and per pane `id` — no lockstep strobe.
- [ ] **Paint only in the paint phase.** `paint_quad`/`paint_path` called only inside a `canvas` paint closure or a custom `Element::paint`; geometry computed in `prepaint`.
- [ ] **CI gate respected.** All T2/T3 code behind `#[cfg(feature = "gpui")]`; Vello/wgpu deps stay out of the `core/` workspace so Linux `rust-console` never compiles them (ADR-0086).
- [ ] **T3 path declared.** Any Vello surface states whether it's **companion (path 3)** or **embedded (path 2)** and, if embedded, owns the shared-device cost honestly — no "just drops in."

---

## References (grounded in the repo)

- `core/pd-console/src/app.rs:144` — `mod motion` (`glow`, `hard_offset`); `:659` the `with_animation` beacon; `cx.notify()` redraw pattern.
- `core/pd-console/src/palette.rs:8` — brand roles + banned colors; `Cargo.toml:18` `required-features = ["gpui"]`, gpui `0.2.2`.
- `fleet-config-ui/src/ships/DitherPipeline.tsx` — the web Bayer/`enabled=false` contract this doc forward-ports to gpui.
- `core/pd-timeline-proto/src/scene.rs` & `main.rs` — the Vello + kurbo + peniko + wgpu proof spike; Metal-on-M4-Max confirmed at runtime.
- `docs/adr/0086-operator-console-rendering-stack.md` — gpui-shell + Vello-surfaces decision; the path-2 (embed) vs path-3 (companion) sequencing.
- gpui paint API: [Zed `painting.rs` example](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/painting.rs), [gpui docs.rs](https://docs.rs/gpui/latest/gpui/), [2D Canvas API discussion #41673](https://github.com/zed-industries/zed/discussions/41673).
