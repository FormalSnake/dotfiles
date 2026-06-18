# Mac remote-work server + NixOS thin client — design

Date: 2026-06-18
Hosts: `macbook` (nix-darwin, "remote work server") and `g815` (NixOS, work + gaming, thin client)

## Goals

1. Reach the `macbook` from the `g815` laptop anywhere (work from the laptop, code lives on the Mac).
2. Fast, resilient interactive shell to the Mac (`mosh` over an SSH handshake).
3. Serve the iOS Simulator to the laptop browser via **serve-sim**, reached over an SSH tunnel.
4. NordVPN as the laptop's privacy/geo VPN exit.
5. 1Password (GUI + integrated CLI) on the laptop, optionally serving as the SSH agent for the key-based login to the Mac.
6. Keep the laptop a **thin client** — no new local dev toolchain, no file sync.

## Decisions (locked, from brainstorming)

- **Transport split:** **Tailscale** is the laptop↔Mac device mesh; **NordVPN** is the laptop VPN exit only. They run separate jobs so NordVPN's killswitch never severs the link to the Mac. (NordVPN Meshnet is therefore *not* used — Tailscale replaces it.)
- **Project files:** edit over SSH (files stay on the Mac). No sshfs, no Syncthing.
- **serve-sim:** reached by **SSH `LocalForward`** (forwarding both serve-sim ports), not bound to the mesh interface.
- **Laptop scope:** thin client. Gaming stack and shared dev env untouched.

## Non-goals (deliberately excluded)

- NordVPN Meshnet (Tailscale is the mesh).
- sshfs / Syncthing project-file sync (edit-over-SSH chosen).
- Local dev toolchain additions on the laptop (thin client).
- `tailscale ssh` as the Mac's SSH server — **not supported on macOS** (Linux/BSD only), which is why the Mac uses native Remote Login + `sshd`.
- An SSH *server* on the laptop (it is a client only).

## Background / facts verified

- **nix-darwin has `services.tailscale`** (`enable`, `package`, `overrideLocalDns`) — it runs `tailscaled` as a launchd daemon (`com.tailscale.tailscaled`). `tailscale up` to authenticate is still imperative.
- **NixOS** has `services.tailscale.enable` (well-established).
- **NordVPN on NixOS** has no first-party nixpkgs module. The community **`connerohnesorge/nordvpn-flake`** provides the `nordvpn` package + a NixOS module exposing `services.nordvpn.enable` and `services.nordvpn.users` (adds users to the `nordvpn` group; opens TCP 443 / UDP 1194; sets `networking.firewall.checkReversePath = false`). Meshnet/login are runtime daemon actions.
- **serve-sim runs two ports:** preview UI on **3200** (`http://localhost:3200`) and the Swift stream helper (MJPEG/WS) on **3100**. The stream server **binds `0.0.0.0` with no authentication** — so tunneling to laptop-localhost is the safe access path, and the tunnel must forward **both** 3100 and 3200 or the video won't load.
- **mosh does not forward ports.** mosh = the resilient shell; port tunnels ride a separate `ssh -fN` connection (the `macbook` host entry).
- Existing `users/kyandesutter/mixins/ssh.nix` already holds host entries (including `mac-codeserver` with `LocalForward 8080`) and is a **shared** home mixin (imported by `users/kyandesutter/default.nix`), so a new `macbook` entry lands on both hosts (harmless/unused on the Mac).
- Mac already has: `nordvpn` cask (unused for mesh now), `mosh`, Node 24, the Xcode/Swift toolchain, and the serve-sim skill. Laptop already has `mosh` + SSH client.

## Design

### Mac side (nix-darwin)

**1. `modules/darwin/mixins/tailscale.nix` (new)** — wired into `modules/darwin/default.nix` imports.

```nix
{ ... }:
{
  services.tailscale.enable = true;
}
```

**2. `modules/darwin/mixins/remote-access.nix` (new)** — wired into `modules/darwin/default.nix` imports. Declarative `sshd` hardening (macOS `sshd_config` includes `/etc/ssh/sshd_config.d/*`), plus a best-effort Remote Login toggle.

```nix
{ ... }:
{
  # macOS sshd reads /etc/ssh/sshd_config.d/* (Include is near the top of the
  # stock sshd_config, so these win). Key-only, no root login.
  environment.etc."ssh/sshd_config.d/100-kyan.conf".text = ''
    PermitRootLogin no
    PasswordAuthentication no
    KbdInteractiveAuthentication no
  '';

  # Best-effort: enable Remote Login (sshd) on activation. May no-op under TCC;
  # the runbook has the manual fallback (Settings -> General -> Sharing).
  system.activationScripts.remoteLogin.text = ''
    /usr/sbin/systemsetup -setremotelogin on >/dev/null 2>&1 || true
  '';
}
```

> Safety: the laptop's SSH **public key must be in the Mac's `~/.ssh/authorized_keys` before** `PasswordAuthentication no` takes effect, or you lock yourself out. This is step 3 of the runbook.

### Laptop side (NixOS `g815`)

**3. `flake.nix`** — add the input:

```nix
nordvpn-flake.url = "github:connerohnesorge/nordvpn-flake";
```

**4. `modules/nixos/mixins/tailscale.nix` (new)** — wired into `modules/nixos/default.nix`.

```nix
{ ... }:
{
  services.tailscale.enable = true;
}
```

**5. `modules/nixos/mixins/nordvpn.nix` (new)** — wired into `modules/nixos/default.nix`. Imports the flake module and enables the daemon for the user.

```nix
{ inputs, ... }:
{
  imports = [ inputs.nordvpn-flake.nixosModules.default ];

  services.nordvpn = {
    enable = true;
    users = [ "kyandesutter" ];
  };
}
```

> Verify `nixpkgs.config.allowUnfree` is already set (Steam/Helium/Spotify imply it). `nordvpn` is unfree.

**5b. `modules/nixos/mixins/onepassword.nix` (new)** — wired into `modules/nixos/default.nix`. The proper NixOS way (the GUI needs the setuid helper + polkit for system/browser unlock and biometric `op` integration).

```nix
{ ... }:
{
  programs._1password.enable = true; # integrated `op` CLI (setuid wrapper)
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "kyandesutter" ];
  };
}
```

> **Gotcha:** `_1password-cli` currently sits in the *shared* `users/kyandesutter/programs.nix` `home.packages`. On Linux the user-profile `op` would **shadow** the system setuid `op`, breaking the GUI↔CLI integration (biometric unlock). Fix: move `_1password-cli` into the `lib.optionals stdenv.isDarwin` block of `programs.nix` so the laptop gets `op` from `programs._1password` instead. Mac behaviour is unchanged.

> **Optional — 1Password as the SSH agent (opt-in):** enable the app's SSH agent (Settings → Developer → *Use the SSH agent*, writes `~/.config/1Password/ssh/agent.sock`), set `IdentityAgent = "~/.config/1Password/ssh/agent.sock";` on the `macbook` ssh host, and put the 1Password-held public key into the Mac's `authorized_keys` instead of a raw private key on disk. **Decision (2026-06-18): not used** — owner won't always be near the Mac; a normal `~/.ssh` key is fine.

**5c. Remote desktop (VNC) — `remmina` on the laptop.** For seeing/clicking GUI & permission dialogs on the Mac when serve-sim/SSH isn't enough. Decision: **built-in macOS Screen Sharing** (no third-party host app), client = `remmina` added to the laptop via a `lib.optionals stdenv.isLinux` block in `programs.nix`. Reached directly at `macbook:5900` over Tailscale (already encrypted — no SSH tunnel).

> **Field finding (2026-06-18):** the Mac's Screen Sharing toggle reads "managed by an external party." Root cause: **Jump Desktop Connect** has switched macOS into Apple Remote Management mode (writes `com.apple.RemoteManagement`, runs `ARDAgent`, `screensharingd` on 5900). **No MDM and no configuration profile** — confirmed. Decision: **keep Jump, VNC through it** — don't reclaim native control; remmina connects to 5900 with the existing legacy VNC password. The Mac needs **no nix change** for this. Security: legacy VNC auth is weak (`allowInsecureDH`) — only over the Tailscale tunnel, never exposed to LAN/internet.

### Shared home

**6. `users/kyandesutter/mixins/ssh.nix`** — add a `macbook` host on the Tailscale MagicDNS name, forwarding the serve-sim ports (3200 + 3100) and the existing code-server port (8080). `mosh macbook` reuses this entry for the shell; a separate `ssh -fN macbook` holds the tunnels.

```nix
"macbook" = {
  HostName = "macbook";   # Tailscale MagicDNS short name; confirm the tailnet machine name
  User = "kyandesutter";
  LocalForward = [
    "3200 127.0.0.1:3200"  # serve-sim preview UI
    "3100 127.0.0.1:3100"  # serve-sim stream (MJPEG/WS)
    "8080 127.0.0.1:8080"  # code-server (existing pattern)
  ];
};
```

> `programs.ssh.settings.<host>.LocalForward` as a list renders repeated `LocalForward` lines; confirmed against home-manager's settings renderer during implementation (fall back to `matchBlocks.localForwards` if the list form is rejected).

### Docs

**7. `docs/remote-server.md` (new)** — owner runbook (mirrors `docs/g815-nixos.md` style): the manual steps and gotchas below.

## Owner-only manual steps (imperative by nature; owner runs all rebuilds)

1. **Mac:** enable Remote Login (Settings → General → Sharing → Remote Login, or `sudo systemsetup -setremotelogin on`), then `sudo tailscale up`.
2. **Laptop:** `sudo tailscale up`; `nordvpn login` (NordVPN *service credentials*, not email/password) and connect.
3. Install the **laptop's SSH public key into the Mac's `~/.ssh/authorized_keys`** *before* the key-only hardening is active.

## Critical gotchas (also in the runbook)

- **NordVPN killswitch vs Tailscale:** NordVPN's firewall can blackhole the Tailscale interface and cut you off from the Mac. Allowlist the CGNAT range used by Tailscale: `nordvpn allowlist add subnet 100.64.0.0/10` (older CLI: `nordvpn whitelist add subnet ...`).
- **mosh can't forward ports:** use `mosh macbook` for the shell and a separate `ssh -fN macbook` for the serve-sim/code-server tunnels.
- **serve-sim needs both 3100 + 3200** forwarded or the stream won't render; the auth-less `0.0.0.0` stream stays unreachable off-tunnel.
- **mosh firewall on the Mac:** if mosh stalls at "Connecting…", allow `mosh-server` incoming in the macOS application firewall (or it's off by default). mosh's UDP (60000–61000) rides the Tailscale tunnel.
- **Tailscale SSH is not a macOS server** — native Remote Login + `sshd` is used instead.

## serve-sim workflow (end state)

On the Mac: `npx serve-sim --detach` (boots/attaches a simulator, serves 3200 + 3100).
On the laptop: `ssh -fN macbook` (opens the tunnels), then open `http://localhost:3200` in Helium.

## Verification (owner, on hardware — I cannot rebuild)

- `tailscale status` on both shows each other; `ssh macbook` connects key-only; `mosh macbook` gives a resilient shell.
- `ssh -fN macbook` + `http://localhost:3200` renders the live simulator in the laptop browser.
- `nordvpn connect` works *and* `ssh macbook` still works (allowlist proven).
- `nix eval .#darwinConfigurations.macbook.system` and `.#nixosConfigurations.g815.config.system.build.toplevel` evaluate without error.

## Out of scope

NordVPN Meshnet, file sync, laptop local toolchain, laptop SSH server, gaming changes.
