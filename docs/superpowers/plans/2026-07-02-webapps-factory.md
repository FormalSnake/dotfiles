# WebApp factory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A declarative `kyan.webapps.sites` list that turns each site into a standalone Tauri/webkit desktop app on `nix build`, `claude.ai` first.

**Architecture:** A Linux home-manager mixin defines `buildWebApp` (a `rustPlatform.buildRustPackage` over pinned `tw93/Pake` source with the URL/identity patched into `pake.json`/`tauri.conf.json`), maps it over the site list, and emits per-app binaries + `.desktop` items into `home.packages`. Auto-icons are fetched at activation time.

**Tech Stack:** Nix / home-manager, `rustPlatform.buildRustPackage`, `cargo-tauri.hook`, Tauri v2, webkitgtk_4_1, jq, imagemagick.

## Global Constraints

- Linux/g815-only: import from `users/kyandesutter/linux.nix`, not `default.nix`.
- Option namespace `kyan.webapps.sites` (matches repo `kyan.*` convention).
- User-facing name is **WebApp**; never surface "Pake" in option/app names.
- No hardcoded `/home/...`; derive icon dir from `config.home.homeDirectory`.
- Pure builds: no build-time network beyond pinned FODs (src hash + cargoHash). Favicon fetch is activation-time only.
- `git add` new files before any `nix build` (flake sees only tracked files).
- Verification per task = `nix build .#nixosConfigurations.g815...` or a targeted derivation build; no sudo needed for building packages.

---

### Task 1: Pin Pake source, prove it builds one app (claude)

**Files:**
- Create: `users/kyandesutter/mixins/webapps.nix`
- Create: `users/kyandesutter/mixins/webapps-icons/claude.png` (done)
- Modify: `users/kyandesutter/linux.nix` (add import)

**Interfaces:**
- Produces: `buildWebApp { url; name; id; icon; description; width; height; darkMode; }` → derivation; `kyan.webapps.sites` option.

- [ ] **Step 1:** Write `webapps.nix` with `buildWebApp` hardcoded to a single claude site (no list yet): `fetchFromGitHub` pin (rev+hash from prefetch), `cargoHash`, `sourceRoot="source/src-tauri"`, `postPatch` jq-rewrites `pake.json` + `tauri.conf.json`, nativeBuildInputs/buildInputs per spec, `cargo-tauri.hook` with `--no-bundle`, install binary `claude`, `makeDesktopItem`.
- [ ] **Step 2:** `git add` the new files.
- [ ] **Step 3:** `nix build .#nixosConfigurations.g815.config.home-manager.users.kyandesutter.home.packages` is awkward — instead expose the single app as a flake-check target OR build via `nix eval`+`nix build` of the derivation. Iterate `cargoHash`/`hash` from the "got/expected" errors until it compiles.
- [ ] **Step 4:** Confirm the built binary exists and `.desktop` is generated.
- [ ] **Step 5:** Commit.

### Task 2: Generalize to the site list + auto name/id

**Files:** Modify `users/kyandesutter/mixins/webapps.nix`

**Interfaces:**
- Consumes: `buildWebApp` from Task 1.
- Produces: `normalizeSite` (string|attrs → full attrs with derived name/id), `kyan.webapps.sites` mapped into `home.packages`.

- [ ] **Step 1:** Add `options.kyan.webapps.sites` (listOf (either str attrs)).
- [ ] **Step 2:** Add `deriveName` (domain → capitalized) and `slugify` (name → id) pure helpers; `normalizeSite` merging defaults (width 1200, height 800, darkMode true).
- [ ] **Step 3:** `config.home.packages = map (s: buildWebApp (normalizeSite s)) cfg.sites` (+ their desktop items).
- [ ] **Step 4:** Set `kyan.webapps.sites = [ { url="https://claude.ai"; name="Claude"; icon=./webapps-icons/claude.png; } ]` as the initial value in the mixin (or leave in linux.nix). `nix build`, verify claude app still builds via the list path.
- [ ] **Step 5:** Commit.

### Task 3: Activation-time favicon fetch for auto-icon sites

**Files:** Modify `users/kyandesutter/mixins/webapps.nix`

**Interfaces:**
- Consumes: normalized sites lacking explicit `icon`.
- Produces: `home.activation.webappIcons` script; auto `.desktop` `Icon=` → `~/.local/share/webapps/icons/<id>.png`.

- [ ] **Step 1:** For sites without `icon`, set desktop `icon` to `${config.home.homeDirectory}/.local/share/webapps/icons/<id>.png`; pre-seed a generic icon there via activation if missing.
- [ ] **Step 2:** Add `home.activation.webappIcons` (`lib.hm.dag.entryAfter ["writeBoundary"]`) running a script over auto-icon sites: curl fallback chain (icon.horse → ddg ip3 → google s2) → `magick` normalize to 256px PNG → write to icon path; leave generic on failure. Use `${pkgs.curl}/bin/curl`, `${pkgs.imagemagick}/bin/magick`.
- [ ] **Step 3:** Add a 2nd site with no icon/name (e.g. a bare URL) to exercise auto name+icon; `nix build`.
- [ ] **Step 4:** Commit.

### Task 4: Rebuild on g815 + verify runtime

**Files:** none (verification)

- [ ] **Step 1:** `git add -A`; hand the `nixos-rebuild switch` to the owner (sudo) or run if permitted.
- [ ] **Step 2:** Verify: Claude app launches, own window/app_id/icon; auto-icon site fetched its favicon into the icon dir.
- [ ] **Step 3:** Note WEBKIT_DISABLE_COMPOSITING_MODE / rendering; adjust if glitched. Commit any fix.
