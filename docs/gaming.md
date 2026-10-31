# Gaming on g815

The setup lives in `modules/gaming/`. g815 loads it with `gaming(fps = 138)` in
`hosts/g815/host.star`. Change the cap there and `fspec apply --host g815`.

## Frame pacing

- DXVK and VKD3D cap every D3D game at 138 fps (`/etc/environment.d/80-gaming.conf`), under the
  VRR ceiling, so the panel stays in its VRR range instead of falling back to vsync.
- `/etc/dxvk.conf` queues one frame instead of three, which cuts input latency.
- MangoHud (`~/.config/MangoHud/MangoHud.conf`, since games run in Steam's runtime container
  and never see the host's `/etc`) uses the early limiter, which holds frametime flat. It also
  covers native Vulkan and OpenGL games, which the DXVK cap misses.
- `PROTON_ENABLE_NVAPI=1` turns on DLSS and Reflex. If a game offers Reflex, use it and turn
  off the in-game frame cap.

| Key | What it does |
| --- | --- |
| `Shift_R+F12` | Hide or show the MangoHud strip (on by default, it shows the active cap) |
| `Shift_L+F1` | Cycle the cap: 138, 120, 90, 72 (half of 144 Hz), 60, unlimited (the DXVK cap still holds 138) |
| `Alt+Z` | GPU Screen Recorder overlay, replay buffer and clips |

## Steam launch options

Steam has no global launch options, so set them for each game (Properties, Launch options):

```
gamemoderun mangohud %command%
```

Add these only when a game needs them:

- `gamescope -W 2560 -H 1600 -r 138 -f --force-grab-cursor -- %command%`: for a forced
  resolution, FSR (`-F fsr`), or a cursor that escapes to the other monitor.
- `SDL_VIDEODRIVER=wayland`: for native SDL games that start in XWayland.
- `PROTON_LOG=1`: writes `~/steam-<appid>.log` when a game will not start.

Force a Proton version: Properties, Compatibility, then pick `GE-Proton11-7` or Valve's Proton.
Before buying, check the game's report and anti-cheat status on https://www.protondb.com.

## Commands

| Command | What it shows or does |
| --- | --- |
| `gamemoded -s` | Whether GameMode is active right now |
| `nvidia-smi` | GPU load, clocks, VRAM, and which processes run on the dGPU |
| `cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode` | `0` means the panel runs on the dGPU |
| `protontricks <appid> <verb>` | Winetricks inside a game's prefix (`protontricks -l` lists ids) |
| `protontricks -c 'wine winecfg' <appid>` | Wine settings for one game |
| `fspec update proton-ge` | After bumping `PROTON_GE` in `modules/gaming/gaming.star` |
| `sysctl vm.max_map_count fs.inotify.max_user_watches` | The kernel limits games depend on |

## Already tuned

These are set in `modules/linux/rootfs/etc/sysctl.d/90-kyan.conf`:

- `vm.max_map_count = 1048576`
- `inotify.max_user_watches = 524288`
- `inotify.max_user_instances = 524288`

`vm.swappiness = 100` is deliberate: swap is zram first, and zram wants a high value. The usual
advice to lower swappiness assumes swap on disk.

The ntsync module is loaded and the logged-in user can open `/dev/ntsync`, which is what Proton
needs to use it.

Proton prefixes for every library (including the Windows partition) share one directory,
`~/.local/share/Steam/steamapps/compatdata`, through `hosts/g815/rootfs/etc/tmpfiles.d`.
