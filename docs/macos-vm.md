# macOS 10.9 Mavericks guest on the g815 — runbook

Declarative side: `modules/nixos/mixins/macos-vm.nix`, enabled with
`kyan.macosVm.enable = true` in `systems/g815/default.nix`. It adds two
commands, a desktop entry, and `ignore_msrs=1` on the kvm module.

- `macos-vm-fetch` — downloads Apple's Mavericks `InstallESD.dmg` and converts
  it to a raw disk. Run once, ~5 GB.
- `macos-vm` — boots the guest in a window. Fullscreen it with Hyprland's own
  binding, not QEMU's: QEMU's `-full-screen` grabs the keyboard and then eats
  its own Ctrl+Alt+Q, which leaves no way out. **Ctrl+Alt+G** grabs and releases
  input on demand, **Ctrl+Alt+Q** quits, and `pkill -f '^qemu-system'` is the
  hard stop.
- App grid entry: **macOS Mavericks**.

State (not in the flake, delete to start over):
`~/.local/share/macos-vm/{InstallESD.dmg,installer.img,disk.img,OVMF_VARS.fd}`.

## What this is and is not

There is no graphics driver. Mavericks has no kext for any QEMU display device,
so it runs on the framebuffer OpenCore hands over: Quartz Extreme is off and
every pixel is composited on the CPU. Window drags and Mission Control are
visibly slower than the same OS on 2013 hardware. Everything else (CPU, disk,
network, audio) is at native speed.

GPU passthrough is not an option on this chassis: the dGPU is an RTX 5070
(Blackwell), and 10.9 tops out at Kepler / GCN 1.0. It would also fight
`dgpu-reconcile` and the login-frozen `AQ_DRM_DEVICES` set.

## Install

1. `macos-vm-fetch` (once, ~5 GB from Apple's recovery servers, then a few
   minutes of converting and patching; it uses `sudo -n` to mount HFS+).
2. `macos-vm`. OpenCore's picker lists `basesystem` — pick it. It boots to the
   **OS X Utilities** window in about a minute.
3. **Disk Utility** → the 64 GB `QEMU HARDDISK` → Partition tab → 1 partition,
   **GUID Partition Map**, format **Mac OS Extended (Journaled)**, name it.
   Quit Disk Utility.
4. **Reinstall OS X** installs from the attached ESD volume (no download). It
   reboots itself once.
5. After the reboot, pick the new volume in OpenCore's picker and press
   Ctrl+Enter to make it the default.
6. Once it boots on its own, `rm ~/.local/share/macos-vm/{InstallESD.dmg,esd.*,basesystem.*}`
   frees ~12 GB.

## Post-install

- `kyan.macosVm.bootArgs = ""` and rebuild — drops the verbose boot text.
- Browser: [Momiji](https://github.com/aobaharuki2005/momiji-web-browser), a
  Firefox fork that still runs on 10.9. Safari 9 cannot do modern TLS.
- The rest of the 2016-onwards patch set (Aqua Proxy for TLS, security patches,
  emoji) is on <https://mavericksforever.com/>.
- **No security updates since 2016.** Treat the guest as untrusted: it is on a
  user-mode NAT (`-netdev user`) with no host ports forwarded and no access to
  the host filesystem, and it should stay that way.

## Knobs

All under `kyan.macosVm` in `systems/g815/default.nix`:

| Option | Default | Note |
| --- | --- | --- |
| `memory` | `8192` | MiB |
| `cores` | `4` | must fit inside `cpuset` |
| `cpuset` | `0-7` | P-cores; an E-core vCPU shows up as UI stutter |
| `diskSize` | `64G` | sparse, only affects a freshly created `disk.img` |
| `resolution` | `Max` | fixed for the session; higher costs smoothness |
| `systemProductName` | `iMac14,2` | must be a Mac that shipped with 10.9 |
| `bootArgs` | `-v` | |

`resolution` is the one worth tuning. There is no guest driver, so macOS sees
exactly one mode and the Displays pane offers nothing else. `Max` gives the
panel's 2560x1600 (sharp at 1:1, but 3x the compositing work of 1080p); a fixed
`1920x1200` keeps the 16:10 aspect and is noticeably smoother.

The GTK window scales the guest screen to fit (`zoom-to-fit=on`), so nothing is
ever cropped, but any non-1:1 scale looks soft. For a sharp 2560x1600 guest you
need the window at the panel's full size: Hyprland's real fullscreen
(`fullscreen 0`) covers the bar, while a maximize-style fullscreen leaves the
bar's reserved space and forces a slight downscale.

## Debugging

The launcher always opens a QEMU monitor socket:

```
nc -U ~/.local/share/macos-vm/monitor.sock
```

`screendump /tmp/vm.ppm` in that monitor captures the framebuffer, which is the
only way to read a panic if the display is wedged. For a headless run:
`MACOS_VM_DISPLAY=none macos-vm` (this also drops `-full-screen`).

Black screen instead of the OpenCore picker: swap `-device vmware-svga` for
`-device VGA,vgamem_mb=128` in the mixin. Both give an unaccelerated
framebuffer; which one OVMF drives cleanly has changed across QEMU versions.

## Walkthrough: install to first boot

1. `macos-vm` (or the **macOS Mavericks** app-grid entry). Fullscreen with
   Hyprland if you want it, not with QEMU.
2. OpenCore's picker: `basesystem`. First boot to the **OS X Utilities** window
   takes about a minute on a verbose boot.
3. **Disk Utility** → select `QEMU HARDDISK` (the 64 GB one, not `basesystem` or
   `OS X Install ESD`) → **Partition** tab → 1 Partition → **Options…** →
   **GUID Partition Map** → format **Mac OS Extended (Journaled)** → name it →
   Apply. Quit Disk Utility.
4. **Reinstall OS X** → Continue → agree → pick the volume you just made. It
   installs from the attached ESD (no download) and reboots itself.
5. Back at OpenCore's picker, select the new volume and press **Ctrl+Enter** to
   make it the default so future boots go straight there.
6. Setup Assistant: skip the Apple ID (10.9-era iCloud auth is dead), create a
   local account, skip registration.
7. Once it boots on its own:
   `rm ~/.local/share/macos-vm/{InstallESD.dmg,esd.*,basesystem.*}` frees ~12 GB.

## Post-install: the mavericksforever patch set

Source: <https://mavericksforever.com/>. The guest has working NAT internet over
the e1000 NIC, so it downloads everything itself. There is no host folder
sharing (10.9 has no virtio-9p driver); if you need a file in, serve it over the
LAN or use `scp` from inside the guest.

Do these in order:

1. **System Preferences → Security & Privacy → General → Allow apps downloaded
   from: Anywhere.** The patches below are unsigned; the article is explicit that
   this must stay set to Anywhere.
2. Terminal: `curl mavericksforever.com/postinstall.sh | sh` — updates Mavericks
   to the last release, restores some Snow Leopard defaults, removes features
   that no longer work.
3. Browser: **Momiji**, a maintained Firefox fork for 10.9. Safari 9 cannot do
   modern TLS, so this is not optional.
   <https://mavericksforever.com/downloads/Momiji%20Downloader.dmg>
   (upstream: <https://github.com/aobaharuki2005/momiji-web-browser>)
4. **Aqua Proxy** — lets the rest of the system's old SSL/TLS stack reach modern
   HTTPS. <https://mavericksforever.com/downloads/Aqua%20Proxy.dmg>
5. The three security patches, since Apple stopped in 2016:
   - Mail Security Patch (CVE-2020-9922, zero-click in Apple Mail)
   - Font Security Patch (CVE-2023-41990)
   - OpenSSH 9.9p2 (replaces the built-in copy)
   All under <https://mavericksforever.com/> → same `downloads/` directory.

Optional, from the same page: emoji update, QuickTime Player X 10.2 mod plus
Flip4Mac / WFH Components / XiphQT for modern codecs, SIMBL and its plugin packs
(Archive Utility Plus, Preview Plus), Media Subscriptions, Download Video
Service, Snow Leopard Window Controls.

Do not delete System Preferences or anything in Utilities.

Two VM-specific notes: video playback through the codec components is CPU-only
here, so expect 1080p to struggle and 4K to fail outright; and audio arrives as a
USB audio device, which 10.9 drives with its in-box AppleUSBAudio.
