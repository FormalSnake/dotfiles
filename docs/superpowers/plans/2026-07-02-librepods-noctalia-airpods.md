# librepods AirPods integration Implementation Plan

> **For agentic workers:** implement task-by-task; steps use checkbox (`- [ ]`) syntax.

**Goal:** Install librepods on g815 and autostart its Qt tray app so AirPods control (noise modes, battery) is available via the tray icon that Noctalia's `tray` widget hosts.

**Architecture:** A topical package mixin installs `pkgs.librepods`; a `systemd.user.service` runs `librepods --hide` at login. No custom Noctalia widget — the native tray app is the UI.

**Tech Stack:** NixOS + home-manager, `pkgs.librepods` (v0.2.5, Qt).

## Global Constraints

- Host g815 only; no macbook change.
- Flakes only see git-tracked files — `git add` before building.
- BlueZ `Experimental = true` already set (bluetooth.nix); AirPods already paired.
- Sudo caveat: if `nixos-rebuild switch` blocks on a password, hand it to the owner.

---

### Task 1: Install librepods (airpods.nix) + wire the import

**Files:**
- Create: `users/kyandesutter/mixins/airpods.nix`
- Modify: `users/kyandesutter/linux.nix` (add the import)

- [ ] **Step 1:** Create `airpods.nix` with `home.packages = [ pkgs.librepods ];` and a header comment (mirrors `beeper.nix`).
- [ ] **Step 2:** Add `./mixins/airpods.nix` to the `imports` list in `linux.nix` (after `./mixins/autostart.nix`).
- [ ] **Step 3:** `nix-instantiate --parse users/kyandesutter/mixins/airpods.nix` → OK.

### Task 2: Autostart the tray app (autostart.nix)

**Files:**
- Modify: `users/kyandesutter/mixins/autostart.nix`

- [ ] **Step 1:** Add `systemd.user.services.librepods` bound to `graphical-session.target` (`X-SwitchMethod = "keep-old"`, no `Restart`), `ExecStart = "${pkgs.librepods}/bin/librepods --hide"`.
- [ ] **Step 2:** `nix-instantiate --parse users/kyandesutter/mixins/autostart.nix` → OK.

### Task 3: Build + runtime verification

- [ ] **Step 1:** `git add` the new/changed files.
- [ ] **Step 2:** `nixos-rebuild build --flake .#g815` (no sudo) → succeeds.
- [ ] **Step 3:** `just r` / `nixos-rebuild switch` (hand to owner if sudo blocks), relogin.
- [ ] **Step 4:** `systemctl --user status librepods` → `active (running)`; librepods tray icon appears in the Noctalia bar.
