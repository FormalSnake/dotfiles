# librepods → Noctalia AirPods control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Noctalia bar button on g815 that switches AirPods noise-control modes via librepods, with a daemon autostart and OSD feedback.

**Architecture:** A `systemd.user.service` runs the librepods Qt daemon (which hosts the `app_server` socket). A `librepods-anc` shell wrapper drives `librepods-ctl noise:*`, tracks mode in a state file (no readback exists), and fires `notify-send` OSDs. A Noctalia `custom_button` bar widget binds click/scroll to that wrapper.

**Tech Stack:** NixOS + home-manager, `pkgs.librepods` (v0.2.5, Qt), `pkgs.writeShellApplication`, Noctalia V5 native shell.

## Global Constraints

- Host g815 only; no macbook change, no cross-host sync obligation.
- Nix flakes only see git-tracked files — `git add` new/changed files before any build.
- librepods v0.2.5 socket accepts only: `reopen`, `noise:off`, `noise:anc`, `noise:transparency`, `noise:adaptive`. Write-only, no readback.
- Noctalia `custom_button` keys (exact): `glyph`, `label`, `tooltip`, `command`, `right_command`, `middle_command`, `scroll_up_command`, `scroll_down_command`. Type string `"custom_button"`. No `textCommand`/`textIntervalMs`.
- Noctalia service runs with a limited PATH → reference all executables by absolute store path.
- No enable flag (always-on where imported).
- Sudo caveat: if `nixos-rebuild` blocks on a password, hand that step to the owner.

---

## File Structure

- `users/kyandesutter/mixins/autostart.nix` (modify) — add the librepods daemon user service.
- `users/kyandesutter/mixins/noctalia.nix` (modify) — add the `librepodsAnc` wrapper (in `let`), install it + `pkgs.librepods`, add `"airpods"` to `bar.main.end`, add the `widget.airpods` table.

---

### Task 1: librepods daemon autostart

**Files:**
- Modify: `users/kyandesutter/mixins/autostart.nix` (add one service block)

**Interfaces:**
- Produces: a running `librepods` daemon hosting the `app_server` `QLocalSocket`, so `librepods-ctl` (Task 2) can connect.

- [ ] **Step 1: Add the service block**

Insert after the `kdeconnect-indicator` service (or anywhere among the service blocks), before the final closing `}`:

```nix
  # librepods — AirPods daemon (hosts the app_server socket that librepods-ctl
  # drives). DE-agnostic tray app, so it lives here like the other login items.
  # Absolute store path (no loginExec needed); starts hidden to the tray.
  # No Restart: quitting from the tray must not relaunch it.
  systemd.user.services.librepods = {
    Unit = {
      Description = "librepods (AirPods daemon, hidden to tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.librepods}/bin/librepods --hide";
    };
  };
```

- [ ] **Step 2: Parse-check**

Run: `nix-instantiate --parse users/kyandesutter/mixins/autostart.nix`
Expected: prints the parsed expression, no syntax error.

- [ ] **Step 3: Commit**

```bash
git add users/kyandesutter/mixins/autostart.nix
git commit -m "airpods: autostart librepods daemon on g815"
```

---

### Task 2: librepods-anc wrapper + Noctalia bar widget

**Files:**
- Modify: `users/kyandesutter/mixins/noctalia.nix` (add wrapper to `let`; extend `home.packages`; edit `bar.main.end`; add `widget.airpods` table)

**Interfaces:**
- Consumes: the running daemon from Task 1; `pkgs.librepods` binaries `librepods-ctl`.
- Produces: `librepodsAnc` (a package exposing `bin/librepods-anc` with subcommands `cycle`, `prev`, `set <off|anc|transparency|adaptive>`).

- [ ] **Step 1: Add the `librepodsAnc` wrapper to the `let` block**

In `users/kyandesutter/mixins/noctalia.nix`, inside the top `let … in`, after the `flexokiScheme` definition, add:

```nix
  # AirPods noise-control from the bar. librepods-ctl is write-only (no readback
  # exists in v0.2.5), so the current mode is tracked optimistically in a state
  # file and becomes authoritative after the first action. Each change fires a
  # synchronous-replace OSD so repeated toggles don't stack. Runs from noctalia's
  # user service (limited PATH) → librepods-ctl/notify-send via runtimeInputs.
  librepodsAnc = pkgs.writeShellApplication {
    name = "librepods-anc";
    runtimeInputs = [
      pkgs.librepods
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      modes=(off anc transparency adaptive)
      labels=(Off "Noise Cancellation" Transparency Adaptive)
      state="''${XDG_RUNTIME_DIR:-/tmp}/librepods-anc.mode"

      notify() {
        notify-send -a AirPods -h string:x-canonical-private-synchronous:airpods "AirPods" "$1"
      }

      current() {
        local i
        i="$(cat "$state" 2>/dev/null || echo 0)"
        case "$i" in 0|1|2|3) echo "$i" ;; *) echo 0 ;; esac
      }

      set_mode() {
        local idx="$1"
        if librepods-ctl "noise:''${modes[$idx]}" 2>/dev/null; then
          echo "$idx" > "$state"
          notify "Noise: ''${labels[$idx]}"
        else
          notify "librepods not running"
          return 1
        fi
      }

      cmd="''${1:-cycle}"
      case "$cmd" in
        cycle) set_mode "$(( ( $(current) + 1 ) % 4 ))" ;;
        prev)  set_mode "$(( ( $(current) + 3 ) % 4 ))" ;;
        set)
          case "''${2:-}" in
            off)          set_mode 0 ;;
            anc)          set_mode 1 ;;
            transparency) set_mode 2 ;;
            adaptive)     set_mode 3 ;;
            *) echo "usage: librepods-anc set <off|anc|transparency|adaptive>" >&2; exit 1 ;;
          esac
          ;;
        *) echo "usage: librepods-anc <cycle|prev|set <mode>>" >&2; exit 1 ;;
      esac
    '';
  };
```

- [ ] **Step 2: Install the wrapper + librepods on PATH**

Change the existing line:

```nix
  home.packages = [ auraRepaint ];
```

to:

```nix
  home.packages = [
    auraRepaint
    librepodsAnc
    pkgs.librepods
  ];
```

- [ ] **Step 3: Add `"airpods"` to the bar's end cluster**

In `settings.shell` → `bar.main.end`, insert `"airpods"` right after `"bluetooth"`:

```nix
        end = [
          "tray"
          "spacer_2"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "airpods"
          "volume"
          "brightness"
          "battery"
          "clock"
        ];
```

- [ ] **Step 4: Add the `widget.airpods` table**

Immediately after the `widget.spacer_2.type = "spacer";` line, add:

```nix
      # AirPods noise-control button (see librepodsAnc in the let block above and
      # docs/superpowers/specs/2026-07-02-librepods-noctalia-airpods-design.md).
      # custom_button is static (no live text) — mode feedback is the OSD from
      # the wrapper; battery lives only in librepods' own window (right-click).
      # All commands are absolute store paths (limited PATH in the user service).
      widget.airpods = {
        type = "custom_button";
        glyph = "headphones";
        tooltip = "AirPods noise — click cycle · scroll adjust · middle transparency · right open";
        command = "${librepodsAnc}/bin/librepods-anc cycle";
        scroll_up_command = "${librepodsAnc}/bin/librepods-anc cycle";
        scroll_down_command = "${librepodsAnc}/bin/librepods-anc prev";
        middle_command = "${librepodsAnc}/bin/librepods-anc set transparency";
        right_command = "${pkgs.librepods}/bin/librepods-ctl reopen";
      };
```

- [ ] **Step 5: Parse-check**

Run: `nix-instantiate --parse users/kyandesutter/mixins/noctalia.nix`
Expected: prints the parsed expression, no syntax error.

- [ ] **Step 6: Stage (so the flake sees the changes) and commit**

```bash
git add users/kyandesutter/mixins/noctalia.nix docs/superpowers/specs/2026-07-02-librepods-noctalia-airpods-design.md docs/superpowers/plans/2026-07-02-librepods-noctalia-airpods.md
git commit -m "airpods: Noctalia bar button for librepods noise control"
```

---

### Task 3: Build + runtime verification

**Files:** none (verification only)

- [ ] **Step 1: Ensure everything is staged**

Run: `git status --short`
Expected: no untracked `.nix` files needed by the build (flake only sees tracked files).

- [ ] **Step 2: Rebuild g815**

Run the repo's rebuild recipe (e.g. `just r` / `nixos-rebuild switch`). This runs `noctalia config validate` on the new `widget.airpods` table — a bad key fails the build here.
Expected: build succeeds; if it blocks on a sudo password, hand this step to the owner.

- [ ] **Step 3: Verify the daemon is up**

Run: `systemctl --user status librepods`
Expected: `active (running)`.

- [ ] **Step 4: Smoke-test the wrapper**

Run: `librepods-anc cycle`
Expected: an "AirPods — Noise: …" OSD appears and the AirPods audibly change mode. Repeat to cycle through all four.

- [ ] **Step 5: Verify the widget**

Confirm the headphones button appears in the bar after `bluetooth`; left-click cycles, scroll adjusts, middle → transparency, right-click opens the librepods window.

---

## Self-Review

- **Spec coverage:** daemon autostart (Task 1) ✓; wrapper with cycle/prev/set + OSD + not-running handling (Task 2 Step 1) ✓; PATH install (Step 2) ✓; bar placement after bluetooth (Step 3) ✓; widget table with exact custom_button keys + all four bindings (Step 4) ✓; verification incl. `noctalia config validate` via rebuild (Task 3) ✓. Battery/state display explicitly out of scope ✓.
- **Placeholder scan:** none — all code is concrete.
- **Type consistency:** wrapper subcommands `cycle`/`prev`/`set <mode>` match the widget command strings; `custom_button` keys match the verified factory (`glyph`, `command`, `right_command`, `middle_command`, `scroll_up_command`, `scroll_down_command`, `tooltip`).
