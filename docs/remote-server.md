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

### 7. Screen Sharing on the Mac (remote desktop) — already on, via Jump Desktop Connect
- Screen Sharing is **already enabled** on this Mac, but it is **managed by Jump
  Desktop Connect** (Jump switches macOS into Apple Remote Management mode). That
  is exactly why System Settings → Sharing shows the toggle as "managed by an
  external party" — expected, not a problem, no MDM/profile involved.
  `screensharingd` listens on **5900**.
- remmina connects as a standard (legacy) VNC client. A legacy VNC password is
  already set (`/Library/Preferences/com.apple.VNCSettings.txt`). If you don't
  know it, reset it to one you choose (this does **not** disturb Jump):
  ```sh
  sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
    -configure -clientopts -setvnclegacy -vnclegacy yes -setvncpw -vncpw 'YOUR_PASSWORD'
  ```
- **Security:** legacy VNC auth is weak (`allowInsecureDH`) — only ever reach
  5900 over the encrypted Tailscale tunnel; never forward it to the LAN/internet.

## Daily use

### Remote desktop — click a dialog on the Mac
- The laptop has **remmina** (VNC client). Connect to `vnc://macbook:5900` over
  Tailscale (Tailscale already encrypts it — no SSH tunnel needed), and
  authenticate with the legacy VNC password from setup step 7.
- Use this when serve-sim / an SSH session hits a GUI or permission dialog on
  the Mac that you can only dismiss by seeing the screen.

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
