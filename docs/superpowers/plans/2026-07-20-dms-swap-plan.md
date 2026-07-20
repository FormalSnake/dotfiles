# Plan: Replace Noctalia with Dank Material Shell (DMS) on g815 — on main

Approved design: full swap on main (no branch), full theming parity, DMS default
bar/widgets (hand-tweaked later in its settings UI, so `settings.json` is NOT
home-manager-managed). Rollback = git revert + rebuild.

## Global Constraints (binding)

- **Power management is load-bearing** (`modules/nixos/mixins/power.nix`,
  `asus.nix`, `users/kyandesutter/mixins/niri.nix` power-tune/gpu-relog-prompt):
  reorganize-only. Only the noctalia-specific call sites change; the
  power-reconcile / dgpu-reconcile / PPD machinery is untouched. `power-source`
  stays in `environment.systemPackages`, referenced as
  `/run/current-system/sw/bin/power-source`.
- **Idle DPMS must stay OFF.** eDP-1 fails its wake modeset
  (`PHY A failed to request refclk`, i915 bug — see noctalia.nix idle comment /
  systems/g815/default.nix). Nothing may (re-)enable screen blanking; DMS's own
  idle defaults must be neutralized (see Task 1).
- **No hardcoded `/home/...`** — derive from `config.home.homeDirectory` (HM)
  or `config.users.users.kyandesutter.home` (system).
- **One concern per mixin**; enable-flag conventions per repo CLAUDE.md.
- **Flakes only see git-tracked files**: `git add` any new file before eval.
- Verification gate for every task: `nix-instantiate --parse` on changed .nix
  files, then `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'`
  AND `nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'`.
  (Do NOT eval `home-manager.users.*` paths — IFD.)
- Commit style: short imperative lowercase subject with conventional prefix
  (match `git log`), no co-author lines, no commit descriptions.
- DMS facts (verified against AvengeMedia/DankMaterialShell source + danklinux.com,
  2026-07-20): flake `github:AvengeMedia/DankMaterialShell/stable`; HM module
  `homeModules.dank-material-shell`; option namespace
  `programs.dank-material-shell` with `enable`, `package`, `systemd.enable`,
  `systemd.target`, `enableDynamicTheming` (pulls matugen), `enableSystemMonitoring`,
  `plugins.*`, HM-only `settings`/`clipboardSettings`/`session` (do NOT use —
  they make the JSON immutable). Runs as user unit `dms.service` via
  `dms run --session`. IPC: `dms ipc call spotlight toggle`,
  `clipboard toggle`, `notifications toggle`, `lock lock`, `powermenu toggle`,
  `settings toggle`, `notepad toggle`, `audio increment|decrement 3`,
  `audio mute`, `audio micmute`, `brightness increment|decrement 5 ""`,
  `mpris playPause|next|previous`, `theme toggle`, `night toggle`,
  `wallpaper set <path>`. Screenshots: `dms screenshot` (region),
  `dms screenshot full`. User matugen templates: DMS merges the `[config]` and
  `[templates]` sections of `~/.config/matugen/config.toml` verbatim into its
  merged matugen config on every palette generation (post_hook supported —
  it is matugen's native post_hook). Built-in templates include gtk3/gtk4
  (`~/.config/gtk-{3,4}.0/dank-colors.css`), qt5ct/qt6ct
  (`~/.config/qt{5,6}ct/colors/matugen.conf`), ghostty, neovim, equibop, niri.
  We do NOT import `homeModules.niri` (its keybind/include machinery would
  fight our niri-flake config); keybinds and the border fragment stay ours.

## Known losses (accepted for the trial, note in final report)

- Per-wallpaper Flexoki palette pinning (`flexoki-scheme`) — DMS has no
  wallpaper_changed hook with env vars. Dropped; wallpaper-derived M3 always.
- Noctalia session-menu Windows/BIOS buttons — replaced by launcher-visible
  .desktop entries (Task 5) unless DMS powermenu supports custom actions.
- Noctalia community yazi template — replaced by our own user template.

---

## Task 1 — flake input + core DMS module

1. `flake.nix`: remove the `noctalia` input block; add
   `dank-material-shell = { url = "github:AvengeMedia/DankMaterialShell/stable"; inputs.nixpkgs.follows = "nixpkgs"; };`
   with a comment in the file's existing style. Run
   `nix flake lock` (updates flake.lock for the new input).
2. New `users/kyandesutter/mixins/dms.nix` replacing
   `users/kyandesutter/mixins/noctalia.nix`:
   - Keep the `auraRepaint` writeShellApplication verbatim (it is
     shell-agnostic; update its header comment: triggered by the matugen aura
     template post_hook and by power-tune). Export via `home.packages`.
   - Drop `flexokiScheme` entirely (known loss).
   - `imports = [ inputs.dank-material-shell.homeModules.dank-material-shell ];`
   - `programs.dank-material-shell = { enable = true; systemd.enable = true; enableDynamicTheming = true; };`
     No `settings`/`clipboardSettings`/`session` attrs. No package override.
   - Seed-if-absent activation for `~/.config/DankMaterialShell/settings.json`
     that disables all idle monitors (screen-off/lock/suspend timeouts) per the
     idle constraint. FIRST verify the exact JSON key names from DMS source
     (`quickshell/Services/IdleService.qml` reads SettingsData; fetch via
     `gh api` or raw.githubusercontent from AvengeMedia/DankMaterialShell) —
     if the key names cannot be verified, write NO seed file and instead add a
     loud comment + report the manual step (disable idle in DMS settings UI
     immediately after first login). Use `home.activation` with
     `lib.hm.dag.entryAfter ["writeBoundary"]`, only when the file does not
     exist (runtime-mutable file, so HM must not own it).
3. `users/kyandesutter/linux.nix`: swap `./mixins/noctalia.nix` →
   `./mixins/dms.nix`.
4. Delete `users/kyandesutter/mixins/noctalia.nix` and
   `users/kyandesutter/mixins/noctalia-bt-rerender.patch` (check the patch
   file's actual path via `fd noctalia-bt users/`).
5. `users/kyandesutter/programs.nix`: btop's `settings.color_theme = "noctalia"`
   → `"dank"` (Task 2 writes `~/.config/btop/themes/dank.theme`); update the
   adjacent comment to point at the matugen user template.
6. Gate: parse + both nix evals green. Commit (e.g.
   `feat(dms): swap noctalia for dank material shell core`).

Note: other files still reference noctalia after this task (niri.nix, system
modules); the tree must still EVAL because those references are strings/paths,
not `inputs.noctalia` — EXCEPT `modules/nixos/mixins/niri.nix` which does
`inputs.noctalia.packages...`. To keep every task green, this task ALSO makes
the minimal system-side edit: in `modules/nixos/mixins/niri.nix`, replace the
`noctalia = inputs.noctalia.packages...` let-binding and the
lock-before-sleep script body with the DMS equivalent:
`dms = inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.default`
(verify the package attr name from the DMS flake — `nix flake show` the input —
before using; `dms-shell` may be the attr) and lock via
`timeout 10 ${dms}/bin/dms ipc call lock lock || true` (keep the exit-0
invariant and the Before=sleep.target ordering; the per-display socket-glob
dance is noctalia-specific — replace it, keeping the comment updated to explain
DMS's socket lives in the user's XDG_RUNTIME_DIR).

## Task 2 — matugen user templates (theming parity)

1. `git mv users/kyandesutter/noctalia-templates users/kyandesutter/matugen-templates`.
2. In `users/kyandesutter/mixins/dms.nix`: install template sources to
   `~/.config/matugen/templates/` via `xdg.configFile`, and write
   `xdg.configFile."matugen/config.toml"` containing `[templates.*]` entries
   (matugen TOML; DMS merges this file verbatim). Port each Noctalia user
   template 1:1 — same output paths where the consumer is unchanged:
   - `aura`: input `~/.config/matugen/templates/aura.tmpl`, output
     `~/.cache/dank/aura-color`, post_hook
     `<auraRepaint>/bin/aura-repaint {{colors.primary.default.hex_stripped}}`
     (store path interpolation like noctalia.nix did).
   - `ghostty`: output `~/.config/ghostty/themes/Matugen`, post_hook
     `pkill -SIGUSR2 ghostty || true`. (Keeps ghostty.nix's `theme = "Matugen"`.)
   - `neovim`: output `~/.config/nvim/lua/noctalia_base16.lua` — KEEP this
     output path (neovim.nix's dynamic-base16 watches that module name; renaming
     would touch neovim.nix too — do not).  Actually: rename output to
     `~/.config/nvim/lua/dank_base16.lua` AND update the module name in
     `users/kyandesutter/mixins/neovim.nix` (`module = "noctalia_base16"` →
     `"dank_base16"`) — complete the rename everywhere, it is two lines.
   - `equibop`: output `~/.config/equibop/themes/noctalia.theme.css` → rename
     output file to `dank.theme.css` (user re-enables theme once in Equibop
     settings; note in final report).
   - `spicetify`: same output `~/.config/spicetify/Themes/Comfy/color.ini`,
     same post_hook incl. `SPICETIFY_CONFIG` env (copy semantics from
     noctalia.nix lines 501-506).
   - `obsidian`: output `~/Notes/.obsidian/snippets/dank.css` — check
     `scripts/obsidian-vault-bootstrap.sh` + `users/kyandesutter/mixins/obsidian.nix`
     for the seeded snippet name; if the bootstrap seeds `noctalia.css`, update
     it to `dank.css` consistently (rg for it).
   - `niri-border`: output `~/.cache/dank/niri-border.kdl`, post_hook
     `niri msg action load-config-file || true` (pin niri by store path as
     before). niri.nix include-path changes happen in Task 3.
   - NEW `btop`: write `users/kyandesutter/matugen-templates/btop.theme.tmpl`
     (btop theme format: `theme[main_bg]="{{colors.surface.default.hex}}"` etc.,
     map M3 roles sensibly across the standard btop theme keys), output
     `~/.config/btop/themes/dank.theme`.
   - NEW `yazi`: write `users/kyandesutter/matugen-templates/yazi-flavor.toml.tmpl`
     mapping M3 roles into a yazi flavor `flavor.toml`, output
     `~/.config/yazi/flavors/dank.yazi/flavor.toml`; statically set
     `programs.yazi` theme pointer or `xdg.configFile."yazi/theme.toml"`
     ([flavor] dark = "dank", light = "dank") — first check how yazi is
     configured in this repo (`rg -l yazi users/`) and follow that.
   - GTK/Qt/ghostty built-in overlap: DMS ships built-in ghostty/gtk/qt
     templates. Our ghostty user template must win / not conflict — check the
     DMS application-themes docs or source for how built-in app themes are
     toggled; if built-in ghostty writes `~/.config/ghostty/config` and that
     file is HM-managed read-only, note it (harmless failure) but prefer
     disabling the built-in via whatever mechanism exists; if none exists
     declaratively, note the manual settings-UI toggle in the report.
3. `users/kyandesutter/mixins/qt.nix`: point `color_scheme_path` at
   `.../qt6ct/colors/matugen.conf` and `.../qt5ct/colors/matugen.conf` (DMS
   built-in qt template outputs); update comments.
4. Gate + commit (`feat(dms): port theming templates to matugen`).

## Task 3 — niri home mixin swap (`users/kyandesutter/mixins/niri.nix`)

1. Replace the `noctaliaBin` let-binding with a `dms` binding to the DMS
   package's `dms` binary (`config.programs.dank-material-shell.package` if the
   module exposes it — check `distro/nix/options.nix`; else the flake package).
2. Keybind swaps (same keys, allow-when-locked flags preserved):
   - Mod+Space → `dms ipc call spotlight toggle`
   - Mod+ntilde → `dms ipc call clipboard toggle`
   - Mod+Period (emoji) → drop the bind (no DMS equivalent; known loss) or bind
     to `spotlight toggle` — drop it, note in report.
   - Mod+Shift+T → `dms ipc call theme toggle`
   - Mod+Shift+Escape (lock-and-suspend) → spawn a tiny script:
     `dms ipc call lock lock && systemctl suspend`
   - Print → `dms screenshot full`; Mod+Shift+S → `dms screenshot`
   - XF86Audio{Raise,Lower}Volume → `audio increment 3` / `decrement 3`
   - XF86AudioMute → `audio mute`; XF86AudioMicMute → `audio micmute`
   - XF86MonBrightness{Up,Down} → `brightness increment 5 ""` /
     `decrement 5 ""`
   - XF86Audio{Play,Pause} → `mpris playPause`; Next/Prev/Stop → `mpris next` /
     `mpris previous` / (stop: use `mpris pause`, no stop verb verified).
3. Window rules: `dev.noctalia.Noctalia` float rule → drop or retarget to DMS
   (quickshell app-id — check what DMS surfaces use; if unknown, drop the rule).
   `noctalia-wallpaper`/`noctalia-backdrop` layer namespaces → DMS wallpaper
   layer namespace (check DMS source for its layer namespace, e.g. `dms` /
   `quickshell`; if unverifiable, drop — rules are cosmetic).
4. Border fragment: `include optional=true "~/.cache/dank/niri-border.kdl"`;
   seed logic (`borderSeed` cp) now targets `~/.cache/dank/`.
5. power-tune: `~/.cache/noctalia/aura-color` → `~/.cache/dank/aura-color`.
6. GTK: `gtk3.extraCss`/`gtk4.extraCss` `@import url("noctalia.css")` →
   `@import url("dank-colors.css")`; update the long ownership comments
   (noctalia → DMS, file names).
7. Update remaining noctalia comments in the file (clipboard poller, GTK theme
   note, screenshots owner rule).
8. Gate + commit (`feat(dms): swap niri keybinds and theming hooks to dms ipc`).

## Task 4 — system modules sweep

1. `modules/nixos/mixins/niri.nix`: already lock-swapped in Task 1 — finish
   comment updates (UPower/ddcutil/fonts notes mention noctalia); keep ddcutil
   (DMS brightness DDC support per docs).
2. `modules/nixos/mixins/asus.nix`: seed path →
   `<home>/.cache/dank/aura-color`; update comments (noctalia → DMS matugen
   template).
3. `modules/nixos/mixins/boot.nix`: the systemd-critical process regex
   `"^(niri|noctalia|polkit-kde-aut|sshd|systemd)$"` → replace `noctalia` with
   the DMS process name (`dms` — verify what the service main process is named;
   `dms run --session` spawns quickshell, so include `quickshell` and/or `qs`
   if that is the actual comm name); read the surrounding code to see what the
   regex feeds and update the noctalia comment at line ~219 (the polkit rule
   consumer note — DMS powermenu/desktop entries now start
   reboot-to-windows.service).
4. `modules/nixos/mixins/gaming.nix`: read the gameInhibit machinery; gaming
   is on Windows now, so DO NOT rebuild it for DMS — update the comments to
   say the idle stack is DMS's (which also honors org.freedesktop.ScreenSaver
   D-Bus inhibit) and that idle blanking is disabled anyway. No behavior
   change.
5. Comment-only updates: `modules/nixos/mixins/bluetooth.nix`,
   `modules/nixos/mixins/power.nix` (PPD consumer is now the DMS bar),
   `modules/nixos/mixins/nvidia-resume-recovery.nix` (lock-before-sleep ref).
6. `users/kyandesutter/mixins/autostart.nix`: `noctalia.service` →
   `dms.service` in helium's After/Wants + description; update the
   clipboard/notification-daemon comments (DMS is the notification daemon now).
7. `systems/g815/default.nix`: update whatever noctalia reference exists there
   (rg found one — read and adapt).
8. Gate + commit (`feat(dms): rewire system modules from noctalia to dms`).

## Task 5 — parity extras

1. Windows/BIOS entries: check DMS powermenu for custom-action support
   (danklinux.com docs / source `quickshell/Modules/...PowerMenu` or settings
   schema). If supported declaratively → wire
   `systemctl start reboot-to-windows.service` and
   `systemctl reboot --firmware-setup` there (settings.json is unmanaged, so
   "declarative" likely fails → fall back). Fallback: two
   `xdg.desktopEntries` in a sensible mixin (`users/kyandesutter/mixins/dms.nix`
   or desktop-apps.nix — follow repo convention): "Reboot to Windows" →
   `/run/current-system/sw/bin/systemctl start reboot-to-windows.service`,
   "UEFI Firmware Setup" → `/run/current-system/sw/bin/systemctl reboot --firmware-setup`
   (polkit rules in boot.nix already waive the password — verify the rule
   covers the user session context, read boot.nix).
2. Wallpaper-engine reconciler: read `users/kyandesutter/mixins/wallpaper-engine.nix`
   (`config.kyan.wallpaperEngine.selectCommand`) — it was fired from noctalia's
   wallpaper_changed hook. Re-wire via a matugen user template: matugen exposes
   the source image path as `{{image}}`; add a `[templates.wallpaper-path]`
   entry rendering `{{image}}` to `~/.cache/dank/wallpaper-path` with
   `post_hook = <selectCommand>` IF selectCommand's interface fits (it may read
   $NOCTALIA_WALLPAPER_PATH — adapt it to read the cache file or take an arg;
   smallest change that keeps the reconciler working). If the interface can't
   be adapted cleanly, report BLOCKED with findings instead of guessing.
3. Notification parity hooks (battery low / profile changed) — DMS: check
   whether DMS surfaces low-battery natively; if yes, nothing to do; if no,
   note the loss in the report (do NOT build a custom poller).
4. Gate + commit (`feat(dms): parity extras for power menu and wallpaper engine`).

## Task 6 — docs + final verification (controller-driven, not a subagent)

1. Update `CLAUDE.md` (project) theming/power sections: Noctalia → DMS (leave
   uncommitted per user rule; surface in final report).
2. `docs/g815-nixos.md`, `docs/noctalia-hm-internals.md`: retitle/adjust or
   mark superseded — minimal edits, no new docs.
3. `git add -A` (flake visibility), both nix evals, then rebuild g815. Rebuild
   needs interactive sudo → hand `! rebuild` (fish function) or
   `! sudo nixos-rebuild switch --flake ~/.config/nix#g815 --impure` to the
   owner if it blocks.
4. Post-switch smoke checklist (owner-assisted): bar up; spotlight/clipboard/
   lock binds; volume/brightness OSD; wallpaper pick recolors ghostty + GTK +
   spicetify + btop + aura keyboard + niri border; suspend locks first;
   **immediately verify idle blanking is OFF in DMS settings**; Windows/BIOS
   launcher entries work.
