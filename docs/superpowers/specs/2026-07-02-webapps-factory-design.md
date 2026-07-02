# WebApp factory (declarative site → desktop app) — Design

**Date:** 2026-07-02
**Host:** g815 (NixOS, Hyprland) — home-manager, Linux-only mixin.

## Goal

A declarative factory in the Nix config: keep a list of sites; on `nix build`
each becomes a standalone desktop "WebApp" (a Chromium `--app` window wrapping
the site), appearing in the launcher with its own icon/`app_id`. `claude.ai` is
the first entry. User-facing name is **WebApp**.

## Engine decision (Chromium `--app`, not Pake/Tauri)

Originally prototyped with Pake (Tauri v2, WebKitGTK). Abandoned: on **Linux**
Tauri is architecturally bound to WebKitGTK (Chromium/WebView2 is Windows-only),
and Cloudflare-protected sites like claude.ai fail WebKitGTK's bot check in an
infinite "verify you are human" loop. Chromium passes Cloudflare and renders
better. So the engine is **Chromium in `--app` mode**, defaulting to **Helium**
(this host's existing browser) so all apps share one browser binary rather than
bundling a Chromium each (as Electron/nativefier would).

The `kyan.webapps.sites` interface is engine-agnostic and unchanged by this swap.

## Interface

Mixin `users/kyandesutter/mixins/webapps.nix`, imported from
`users/kyandesutter/linux.nix`. Options under `kyan.webapps`:

- `sites` — list; each entry a bare URL string **or** attrset
  `{ url; name?; id?; icon?; description?; width?; height?; darkMode?;
  borderless?; shareProfile?; }`. Only `url` required.
- `browser` — the Chromium package used as engine (default `pkgs.helium`).

```nix
kyan.webapps.sites = [
  { url = "https://claude.ai"; name = "Claude";
    icon = ./webapps-icons/claude.png; shareProfile = true; }
  "https://music.youtube.com"      # bare URL → auto name + favicon, isolated profile
];
```

## Per-site build

`buildWebApp` maps over `sites`, emitting two things per site into
`home.packages`:

1. `pkgs.writeShellScriptBin "webapp-<id>"` — `exec <browser> --app=<url>
   --class=webapp-<id> --window-size=W,H --no-first-run
   --no-default-browser-check [--user-data-dir=<profile>]`. Binary is namespaced
   `webapp-<id>` so it never shadows a real CLI (e.g. `claude` from claude-code).
   `--class` sets the Wayland `app_id` for a distinct dock icon.
2. `pkgs.makeDesktopItem` — `Name` = friendly name, `Exec = webapp-<id> %U`,
   `Icon`, `StartupWMClass = webapp-<id>`, `Categories=Network`.

## Profiles / logins (`shareProfile`)

- **Isolated (default)** — dedicated `--user-data-dir=~/.local/share/webapps/
  profiles/<id>`. Persistent logins per app, isolated from the main browser, own
  process → own `app_id`/icon.
- **`shareProfile = true`** — omits `--user-data-dir`, so the app uses the
  browser's default profile and reuses existing logins. Trade-off: the window
  runs inside the main browser process, inheriting its `app_id`/icon (no distinct
  dock icon). Used for Claude, which enforces a hard device limit — an isolated
  profile would burn a device slot per login.

## Auto-derivation & icons

- **Name** ← domain (`claude.ai` → `Claude`), overridable.
- **id** ← slug of name; used for binary/`--class`/`StartupWMClass`/icon path.
- **Explicit `icon`** → used as-is (build-time). Claude: `webapps-icons/
  claude.png` (180×180 apple-touch icon).
- **Auto icon** → `.desktop` `Icon=` points at `~/.local/share/webapps/icons/
  <id>.png`; a home-manager **activation script** fetches the favicon (icon.horse
  → DuckDuckGo `ip3` → Google s2), normalizes to PNG via ImageMagick, falls back
  to a committed generic globe (`webapps-icons/generic.png`, rendered from the
  lucide `globe` icon) on failure/offline. Impure/activation-time → pure builds
  preserved, no per-icon hash.
- **width/height** → `--window-size`. **darkMode/borderless** accepted for
  interface stability but WM/site-driven under Chromium+Hyprland (tiling WM
  windows already have no title bar).

## Scope boundaries (v1 / YAGNI)

Linux/g815 only. No Electron/nativefier (heavier). No per-site custom window
rules. The `sites` interface is stable regardless of engine.
