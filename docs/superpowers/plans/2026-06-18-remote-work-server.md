# Mac remote-work server + NixOS thin client — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `macbook` reachable from the `g815` NixOS laptop anywhere — fast SSH/mosh shell, serve-sim over an SSH tunnel — with Tailscale as the device mesh and NordVPN as the laptop's VPN exit.

**Architecture:** Declarative pieces only. Tailscale runs on both hosts (`services.tailscale`); the Mac gets declarative `sshd` hardening; the laptop gets NordVPN via the `connerohnesorge/nordvpn-flake` module; the shared `ssh.nix` gets a `macbook` host that forwards the serve-sim ports. All `tailscale up` / `nordvpn login` / Remote-Login enabling are imperative **owner** steps captured in a runbook. **The owner runs every rebuild — this plan never does.**

**Tech Stack:** nix-darwin, NixOS, home-manager, flake-parts, Tailscale, NordVPN (community flake), serve-sim, mosh/ssh.

---

## Conventions for this plan

- **"Test" = `nix eval`.** There are no unit tests in a Nix config. Each task's verification forces full module evaluation of the affected configuration (`.drvPath`), which catches option typos, type errors, and bad imports **without building or activating anything**. This is the same technique the prior g815 work used.
- **`git add` before every eval.** Flakes only see git-tracked files, so new files must be staged before `nix eval` can see them.
- **Commits are owner-gated.** Each task stages its files. A single final commit is offered at the end; do not auto-commit without the owner's go-ahead. Never run `darwin-rebuild` / `nixos-rebuild` / `just`.
- Run all commands from the repo root: `/Users/kyandesutter/.config/nix`.

---

## File structure

| File | Responsibility |
|---|---|
| `modules/darwin/mixins/tailscale.nix` *(new)* | Enable `tailscaled` on the Mac |
| `modules/darwin/mixins/remote-access.nix` *(new)* | Declarative `sshd` hardening + best-effort Remote Login toggle |
| `modules/darwin/default.nix` *(modify)* | Import the two new darwin mixins |
| `flake.nix` *(modify)* | Add the `nordvpn-flake` input |
| `flake.lock` *(generated)* | Lock the new input |
| `modules/nixos/mixins/tailscale.nix` *(new)* | Enable `tailscaled` on the laptop |
| `modules/nixos/mixins/nordvpn.nix` *(new)* | NordVPN daemon via the community flake module |
| `modules/nixos/mixins/onepassword.nix` *(new)* | 1Password GUI + integrated CLI on the laptop |
| `modules/nixos/default.nix` *(modify)* | Import the three new nixos mixins |
| `users/kyandesutter/programs.nix` *(modify)* | Move `_1password-cli` to Darwin-only (avoid shadowing the laptop's setuid `op`) |
| `users/kyandesutter/mixins/ssh.nix` *(modify)* | `macbook` host entry forwarding serve-sim (3200+3100) and 8080 |
| `docs/remote-server.md` *(new)* | Owner runbook (manual steps + gotchas) |

---

## Task 1: Tailscale on the Mac

**Files:**
- Create: `modules/darwin/mixins/tailscale.nix`
- Modify: `modules/darwin/default.nix` (imports list)

- [ ] **Step 1: Create the mixin**

`modules/darwin/mixins/tailscale.nix`:

```nix
{ ... }:
{
  # Tailscale device mesh — reach this Mac (the "remote work server") from the
  # g815 laptop anywhere. nix-darwin runs tailscaled as a launchd daemon
  # (com.tailscale.tailscaled). `sudo tailscale up` to authenticate is a manual
  # owner step — see docs/remote-server.md.
  services.tailscale.enable = true;
}
```

- [ ] **Step 2: Wire it into the darwin module**

In `modules/darwin/default.nix`, add `./mixins/tailscale.nix` to the imports list (after `./mixins/agenix.nix`):

```nix
      ./mixins/agenix.nix
      ./mixins/tailscale.nix
      ./profiles
```

- [ ] **Step 3: Stage the files**

```bash
git add modules/darwin/mixins/tailscale.nix modules/darwin/default.nix
```

- [ ] **Step 4: Evaluate the Mac config**

Run: `nix eval .#darwinConfigurations.macbook.config.services.tailscale.enable`
Expected: `true`

(If this errors with "attribute 'tailscale' missing", the nix-darwin pin predates the module — bump `nix-darwin` in `flake.nix`. Verified present as of June 2026.)

---

## Task 2: SSH server hardening on the Mac

**Files:**
- Create: `modules/darwin/mixins/remote-access.nix`
- Modify: `modules/darwin/default.nix` (imports list)

- [ ] **Step 1: Create the mixin**

`modules/darwin/mixins/remote-access.nix`:

```nix
{ ... }:
{
  # SSH server hardening for the remote-work-server role. macOS's sshd reads
  # /etc/ssh/sshd_config.d/* (the Include sits near the top of the stock
  # sshd_config, so these directives win). Key-only auth, no root login.
  #
  # SAFETY: the laptop's SSH *public* key must already be in this Mac's
  # ~/.ssh/authorized_keys BEFORE PasswordAuthentication flips to "no", or you
  # lock yourself out. See docs/remote-server.md step 3.
  environment.etc."ssh/sshd_config.d/100-kyan.conf".text = ''
    PermitRootLogin no
    PasswordAuthentication no
    KbdInteractiveAuthentication no
  '';

  # Best-effort enable of Remote Login (sshd) on activation. postActivation.text
  # is type `lines`, so this concatenates with any other contributor. Under
  # macOS TCC the call may silently no-op; the runbook has the manual Settings
  # fallback (System Settings -> General -> Sharing -> Remote Login).
  system.activationScripts.postActivation.text = ''
    /usr/sbin/systemsetup -setremotelogin on >/dev/null 2>&1 || true
  '';
}
```

- [ ] **Step 2: Wire it into the darwin module**

In `modules/darwin/default.nix`, add `./mixins/remote-access.nix` after `./mixins/tailscale.nix`:

```nix
      ./mixins/tailscale.nix
      ./mixins/remote-access.nix
      ./profiles
```

- [ ] **Step 3: Stage the files**

```bash
git add modules/darwin/mixins/remote-access.nix modules/darwin/default.nix
```

- [ ] **Step 4: Evaluate the Mac config fully**

Run: `nix eval .#darwinConfigurations.macbook.system.drvPath`
Expected: a single `/nix/store/...-darwin-system-....drv` path printed, no errors.

(This forces full module eval, confirming both `environment.etc."ssh/..."` and `postActivation.text` are accepted. If `postActivation` errors, it is being set as a non-`lines` type somewhere — fall back to `lib.mkAfter` and add `lib` to the function args.)

---

## Task 3: Tailscale on the laptop

**Files:**
- Create: `modules/nixos/mixins/tailscale.nix`
- Modify: `modules/nixos/default.nix` (imports list)

- [ ] **Step 1: Create the mixin**

`modules/nixos/mixins/tailscale.nix`:

```nix
{ ... }:
{
  # Tailscale device mesh — reach the macbook (remote work server) from this
  # laptop anywhere. `sudo tailscale up` to authenticate is a manual owner step
  # — see docs/remote-server.md.
  services.tailscale.enable = true;
}
```

- [ ] **Step 2: Wire it into the nixos module**

In `modules/nixos/default.nix`, add `./mixins/tailscale.nix` after `./mixins/sober.nix`:

```nix
      ./mixins/sober.nix
      ./mixins/tailscale.nix
      ./profiles
```

- [ ] **Step 3: Stage the files**

```bash
git add modules/nixos/mixins/tailscale.nix modules/nixos/default.nix
```

- [ ] **Step 4: Evaluate the laptop config**

Run: `nix eval .#nixosConfigurations.g815.config.services.tailscale.enable`
Expected: `true`

---

## Task 4: Add the NordVPN flake input

**Files:**
- Modify: `flake.nix` (inputs)
- Generated: `flake.lock`

- [ ] **Step 1: Add the input**

In `flake.nix`, in the `# — NixOS (g815 gaming laptop) inputs —` section, add it right after the `nixos-hardware.url` line:

```nix
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # NordVPN — laptop VPN exit only (the device mesh is Tailscale). No
    # first-party nixpkgs module exists; this community flake provides the
    # package + a NixOS module (services.nordvpn).
    nordvpn-flake.url = "github:connerohnesorge/nordvpn-flake";
```

- [ ] **Step 2: Lock the new input**

Run: `nix flake lock`
Expected: writes a `nordvpn-flake` node into `flake.lock` (and its transitive inputs). No error.

- [ ] **Step 3: (Optional) dedupe nixpkgs**

Run: `nix flake metadata github:connerohnesorge/nordvpn-flake --json | nix run nixpkgs#jq -- -r '.locks.nodes.root.inputs | keys[]'`
If the output includes `nixpkgs`, add `inputs.nixpkgs.follows = "nixpkgs";` to the `nordvpn-flake` input block and re-run `nix flake lock`. If it does not, leave the bare URL (a second nixpkgs is harmless — `nordvpn` is a patched binary, version-insensitive).

- [ ] **Step 4: Stage the files**

```bash
git add flake.nix flake.lock
```

- [ ] **Step 5: Verify the flake still evaluates**

Run: `nix flake metadata --json | nix run nixpkgs#jq -- -r '.locks.nodes.root.inputs."nordvpn-flake"'`
Expected: a non-null lock entry (proves the input resolved and the flake parses).

---

## Task 5: NordVPN on the laptop

**Files:**
- Create: `modules/nixos/mixins/nordvpn.nix`
- Modify: `modules/nixos/default.nix` (imports list)

**Depends on Task 4** (the `inputs.nordvpn-flake` reference fails to evaluate until the input exists).

- [ ] **Step 1: Create the mixin**

`modules/nixos/mixins/nordvpn.nix`:

```nix
{ inputs, ... }:
{
  # NordVPN — laptop privacy/geo VPN exit ONLY. The device mesh to the macbook
  # is Tailscale, kept on a separate job so NordVPN's killswitch can't sever it.
  # This community flake provides the package + the nordvpnd systemd service,
  # the `nordvpn` group, and the firewall rules (TCP 443 / UDP 1194).
  #
  # Runtime (owner): `nordvpn login` with SERVICE credentials, then
  # `nordvpn allowlist add subnet 100.64.0.0/10` so the killswitch never blocks
  # Tailscale. See docs/remote-server.md.
  imports = [ inputs.nordvpn-flake.nixosModules.default ];

  services.nordvpn = {
    enable = true;
    users = [ "kyandesutter" ];
  };
}
```

- [ ] **Step 2: Wire it into the nixos module**

In `modules/nixos/default.nix`, add `./mixins/nordvpn.nix` after `./mixins/tailscale.nix`:

```nix
      ./mixins/tailscale.nix
      ./mixins/nordvpn.nix
      ./profiles
```

- [ ] **Step 3: Stage the files**

```bash
git add modules/nixos/mixins/nordvpn.nix modules/nixos/default.nix
```

- [ ] **Step 4: Evaluate the laptop config fully**

Run: `nix eval .#nixosConfigurations.g815.config.services.nordvpn.enable`
Expected: `true`

Then the comprehensive eval (forces the whole system, incl. the flake module + firewall merge):
Run: `nix eval .#nixosConfigurations.g815.config.system.build.toplevel.drvPath`
Expected: a single `/nix/store/...drv` path, no errors. (May take a while from the Mac — eval only, no build.)

---

## Task 6: `macbook` SSH host entry (serve-sim tunnel)

**Files:**
- Modify: `users/kyandesutter/mixins/ssh.nix` (inside `programs.ssh.settings`)

- [ ] **Step 1: Add the host block**

In `users/kyandesutter/mixins/ssh.nix`, immediately after the `"mac-codeserver"` block, add:

```nix
      # Remote work server over Tailscale (reachable anywhere). `mosh macbook`
      # uses this entry for the resilient shell; a separate `ssh -fN macbook`
      # holds the tunnels (mosh cannot forward ports). serve-sim needs BOTH
      # 3200 (preview UI) and 3100 (MJPEG/WS stream) — see docs/remote-server.md.
      "macbook" = {
        HostName = "macbook"; # Tailscale MagicDNS name — confirm the tailnet machine name
        User = "kyandesutter";
        LocalForward = [
          "3200 127.0.0.1:3200"
          "3100 127.0.0.1:3100"
          "8080 127.0.0.1:8080"
        ];
      };
```

- [ ] **Step 2: Stage the file**

```bash
git add users/kyandesutter/mixins/ssh.nix
```

- [ ] **Step 3: Evaluate (the list-valued LocalForward is the risk here)**

Run: `nix eval .#darwinConfigurations.macbook.system.drvPath`
Expected: a `/nix/store/...drv` path, no errors.

If eval rejects the list value for `LocalForward`, convert this entry to the structured form instead:

```nix
      "macbook" = {
        HostName = "macbook";
        User = "kyandesutter";
        localForwards = [
          { bind.port = 3200; host.address = "127.0.0.1"; host.port = 3200; }
          { bind.port = 3100; host.address = "127.0.0.1"; host.port = 3100; }
          { bind.port = 8080; host.address = "127.0.0.1"; host.port = 8080; }
        ];
      };
```

…and re-stage + re-eval. (Note: `localForwards` belongs in a `matchBlocks` entry; if this repo's `settings` schema rejects it, move just the `macbook` entry into `programs.ssh.matchBlocks."macbook"`.)

- [ ] **Step 4: Confirm the rendered config (optional, stronger check)**

Run: `nix build --no-link --print-out-paths '.#darwinConfigurations.macbook.config.home-manager.users.kyandesutter.home.activationPackage'` then inspect — or simply trust the eval above. The eval is sufficient to catch the rendering-type error.

---

## Task 7: 1Password on the laptop

**Files:**
- Create: `modules/nixos/mixins/onepassword.nix`
- Modify: `modules/nixos/default.nix` (imports list)
- Modify: `users/kyandesutter/programs.nix` (move `_1password-cli` to Darwin-only)

- [ ] **Step 1: Create the mixin**

`modules/nixos/mixins/onepassword.nix`:

```nix
{ ... }:
{
  # 1Password on the laptop. The NixOS modules are the correct path: the GUI
  # needs the setuid helper + polkit for system/browser unlock, and the
  # integrated `op` CLI (programs._1password) talks to the desktop app for
  # biometric unlock. Both packages are unfree (allowUnfree already true).
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "kyandesutter" ];
  };
}
```

- [ ] **Step 2: Wire it into the nixos module**

In `modules/nixos/default.nix`, add `./mixins/onepassword.nix` after `./mixins/nordvpn.nix`:

```nix
      ./mixins/nordvpn.nix
      ./mixins/onepassword.nix
      ./profiles
```

- [ ] **Step 3: Stop the home-profile `op` from shadowing the laptop's setuid `op`**

In `users/kyandesutter/programs.nix`, remove `_1password-cli` from the shared
`home.packages` list (line ~8) and add it to the Darwin-only block so the Mac is
unchanged while the laptop gets `op` from `programs._1password`:

Remove from the shared list:
```nix
      just
      zulu21
      _1password-cli
```
→
```nix
      just
      zulu21
```

Add to the `lib.optionals stdenv.isDarwin [ … ]` block (alphabetical, before `cocoapods`):
```nix
    ++ lib.optionals stdenv.isDarwin [
      _1password-cli
      cocoapods
```

- [ ] **Step 4: Stage the files**

```bash
git add modules/nixos/mixins/onepassword.nix modules/nixos/default.nix users/kyandesutter/programs.nix
```

- [ ] **Step 5: Evaluate both configs**

The laptop gains 1Password; the Mac must still resolve `_1password-cli` (now Darwin-only):

Run: `nix eval .#nixosConfigurations.g815.config.programs._1password-gui.enable`
Expected: `true`

Run: `nix eval .#darwinConfigurations.macbook.system.drvPath`
Expected: a `/nix/store/...drv` path, no errors (confirms the `programs.nix` move didn't break the Mac).

---

## Task 8: Owner runbook

**Files:**
- Create: `docs/remote-server.md`

- [ ] **Step 1: Write the runbook**

`docs/remote-server.md`:

```markdown
# Remote work server (macbook) + thin client (g815) — runbook

`macbook` (nix-darwin) is the remote work server: it holds project files, runs
Xcode/iOS simulators, and serves them via serve-sim. `g815` (NixOS) is a thin
client that reaches it over **Tailscale** (device mesh). **NordVPN** on the
laptop is the privacy/geo VPN exit only — it does not carry laptop↔Mac traffic.

All declarative wiring is in the flake. The steps below are the imperative,
owner-only bits the flake cannot do. The owner runs every rebuild.

## One-time setup

### 1. Rebuild both hosts (owner)
- Mac:    `darwin-rebuild switch --flake ~/.config/nix#macbook`
- Laptop: `sudo nixos-rebuild switch --flake ~/.config/nix#g815`

### 2. Bring up Tailscale on both
- `sudo tailscale up` on the Mac, then on the laptop. Authenticate both into the
  same tailnet. Confirm the Mac's machine name (`tailscale status`) matches the
  `HostName` in `users/kyandesutter/mixins/ssh.nix` (`macbook`); if MagicDNS
  uses a different name, update that entry.

### 3. Install the laptop's SSH key on the Mac (BEFORE relying on key-only auth)
- On the laptop: `ssh-keygen -t ed25519` (if no key yet).
- `ssh-copy-id kyandesutter@macbook` (while password auth still works), or paste
  `~/.ssh/id_ed25519.pub` into the Mac's `~/.ssh/authorized_keys`.
- The Mac's sshd is hardened to **key-only** (`100-kyan.conf`); without the key
  installed first you will be locked out.

### 4. Enable Remote Login on the Mac (if the activation script no-opped)
- The config best-effort runs `systemsetup -setremotelogin on`. If `ssh macbook`
  refuses to connect, enable it manually: System Settings → General → Sharing →
  **Remote Login** = on.

### 5. NordVPN on the laptop
- `nordvpn login` — use **service credentials** (NordVPN account → Set up
  NordVPN manually), not your email/password.
- **Critical:** allowlist the Tailscale CGNAT range so the killswitch never
  blocks the mesh:
  `nordvpn allowlist add subnet 100.64.0.0/10`
  (older CLI: `nordvpn whitelist add subnet 100.64.0.0/10`.)
- `nordvpn connect`. Verify `ssh macbook` still works while connected.

### 6. 1Password on the laptop
- After the rebuild, launch 1Password and sign in.
- The integrated CLI works via `op` (biometric unlock through the desktop app).
  Do **not** install 1Password CLI in the home profile on the laptop — it would
  shadow the setuid `op` and break the integration (the flake already keeps the
  home-profile `_1password-cli` Darwin-only).
- *(Optional) SSH agent:* enable Settings → Developer → **Use the SSH agent**.
  Then add `IdentityAgent = "~/.config/1Password/ssh/agent.sock";` to the
  `macbook` host in `users/kyandesutter/mixins/ssh.nix`, and put the
  1Password-held **public** key into the Mac's `~/.ssh/authorized_keys` (this
  replaces the raw `~/.ssh/id_ed25519` key from step 3).

## Daily use

### Resilient shell
- `mosh macbook` — survives suspend/roaming. Uses the `macbook` ssh entry for
  the handshake. (mosh cannot forward ports.)

### serve-sim in the laptop browser
1. On the Mac: `npx serve-sim --detach` (boots/attaches a simulator; serves the
   preview UI on 3200 and the stream on 3100).
2. On the laptop: `ssh -fN macbook` (opens the 3200/3100/8080 tunnels).
3. Open `http://localhost:3200` in Helium. The preview pulls its stream from
   `localhost:3100` over the same tunnel.
4. Tear down the tunnel: `ssh -O exit macbook` (or kill the `ssh -fN` process).

## Gotchas
- **NordVPN killswitch vs Tailscale:** if the laptop loses the Mac while NordVPN
  is connected, re-check the `100.64.0.0/10` allowlist (step 5).
- **mosh stalls at "Connecting…":** the macOS application firewall is blocking
  `mosh-server`. Allow it (System Settings → Network → Firewall → Options →
  add `mosh-server`), or confirm the firewall is off. mosh UDP (60000–61000)
  rides the Tailscale tunnel.
- **serve-sim video blank:** only 3200 was forwarded — forward 3100 too. The
  stream server binds 0.0.0.0 with no auth, so never expose it off the tunnel.
- **Tailscale SSH** is not supported as a macOS *server*, which is why the Mac
  uses native Remote Login + sshd rather than `tailscale ssh`.
```

- [ ] **Step 2: Stage the file**

```bash
git add docs/remote-server.md
```

(No eval — Markdown only.)

---

## Task 9: Final commit (owner-gated)

- [ ] **Step 1: Confirm both configs evaluate clean**

```bash
nix eval .#darwinConfigurations.macbook.system.drvPath
nix eval .#nixosConfigurations.g815.config.system.build.toplevel.drvPath
```

Expected: each prints a single `/nix/store/...drv` path, no errors.

- [ ] **Step 2: Review what's staged**

```bash
git status --short
git diff --cached --stat
```

Expected staged set: the 6 new files (`modules/darwin/mixins/tailscale.nix`,
`modules/darwin/mixins/remote-access.nix`, `modules/nixos/mixins/tailscale.nix`,
`modules/nixos/mixins/nordvpn.nix`, `modules/nixos/mixins/onepassword.nix`,
`docs/remote-server.md`), plus `modules/darwin/default.nix`,
`modules/nixos/default.nix`, `users/kyandesutter/mixins/ssh.nix`,
`users/kyandesutter/programs.nix`, `flake.nix`, `flake.lock`.
**No `CLAUDE.md` / `CLAUDE-*.md`.**

- [ ] **Step 3: Commit (only on the owner's go-ahead)**

```bash
git commit -m "remote work server: tailscale mesh, mac sshd, laptop nordvpn, serve-sim tunnel"
```

- [ ] **Step 4: Hand off to the owner**

Print: "Config staged/committed. Owner: rebuild `#macbook` then `#g815`, then
follow `docs/remote-server.md` (Tailscale up on both, install the laptop SSH key
on the Mac before key-only auth bites, `nordvpn login` + allowlist
`100.64.0.0/10`)."

---

## Self-review (done while writing)

- **Spec coverage:** Tailscale Mac (T1) ✓, Mac sshd hardening + Remote Login (T2) ✓, Tailscale laptop (T3) ✓, NordVPN input (T4) ✓, NordVPN laptop (T5) ✓, serve-sim tunnel host with 3200+3100+8080 (T6) ✓, 1Password GUI+CLI on the laptop + `op`-shadowing fix (T7) ✓, runbook with all gotchas — killswitch allowlist, mosh-can't-forward, both-ports, mosh firewall, no-macOS-tailscale-ssh, 1Password CLI shadowing (T8) ✓. Manual owner steps (T8) ✓. Out-of-scope items introduce no tasks ✓.
- **Placeholder scan:** no TBD/TODO-as-work; the three intentional "confirm at runtime / opt-in" notes (MagicDNS name, optional nixpkgs follows, optional 1Password SSH agent) have concrete fallback/opt-in commands.
- **Type/name consistency:** `services.tailscale.enable`, `services.nordvpn.{enable,users}`, `inputs.nordvpn-flake.nixosModules.default`, `programs._1password.enable`, `programs._1password-gui.{enable,polkitPolicyOwners}`, `environment.etc."ssh/sshd_config.d/100-kyan.conf"`, `system.activationScripts.postActivation.text`, host key `"macbook"` — consistent across tasks and matching verified upstream option names.
```
