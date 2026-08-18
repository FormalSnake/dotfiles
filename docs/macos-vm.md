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
panel's 2560x1600 (sharp, but 3x the compositing work of 1080p); a fixed
`1920x1200` is smoother and gets scaled by the host.

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
