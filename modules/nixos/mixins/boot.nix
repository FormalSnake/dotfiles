{ lib, pkgs, ... }:
let
  # Fallout Limine theme (https://github.com/Neptune3013/fallout-limine-theme):
  # vault-boy backdrop + retro PHXEGA8 bitmap font. Pinned via fetchFromGitHub so
  # no binaries live in the repo. The upstream install script edits /boot
  # imperatively — useless on NixOS, which regenerates limine.conf on every
  # activation — so the theme is expressed through the module's style.* options
  # instead (see the limine block below).
  fallout-limine = pkgs.fetchFromGitHub {
    owner = "Neptune3013";
    repo = "fallout-limine-theme";
    rev = "9a777b932de07dce60e58b2a1162b7d41ecfd2e9";
    hash = "sha256-ZZb+x/dglrGEGljeDeHgr809qbFi9dc6ipfU53DIHwE=";
  };

in
{
  boot = {
    loader = {
      limine = {
        enable = true;
        # Parity with the old systemd-boot configurationLimit: keep the last few
        # generations selectable in the menu (older ones stay on disk).
        maxGenerations = 3;

        # Theming: the Fallout theme (see fallout-limine in the let block above).
        # Limine renders pre-boot, so — like SDDM — this is the theming model's
        # *static fallback* tier, not the matugen/DMS runtime pipeline
        # (which would mean a full rebuild on every wallpaper change).
        #
        # term_font / term_font_size have no dedicated module option, so the
        # PHXEGA8 bitmap font goes via extraConfig + additionalFiles (copied to
        # /boot/limine/, referenced as boot():/limine/…). Everything else maps
        # onto the module's style.* options below. Colour values are taken
        # verbatim from the theme's Limine.txt.
        extraConfig = ''
          term_font: boot():/limine/PHXEGA8.F14
          term_font_size: 8x14
        '';
        additionalFiles."PHXEGA8.F14" = "${fallout-limine}/Fallout_limine/PHXEGA8.F14";
        style = {
          # High-res (original GRUB) variant — sharper on the laptop panel than
          # the compressed jpg the theme ships by default.
          wallpapers = [ "${fallout-limine}/Fallout_limine/high-res-bg/background.png" ];
          wallpaperStyle = "stretched";
          interface = {
            branding = ""; # drop Limine's "Limine x.y.z (…)" title
            helpHidden = true; # hide the ARROWS/ENTER/S-Firmware key hints
          };
          graphicalTerminal = {
            font.scale = "2x2";
            margin = 0; # term_background covers the whole screen, uniform
            foreground = "67d97a"; # boot-entry text (Pip-Boy green)
            background = "9935453b"; # TTRRGGBB — 99 = ~40% opaque green tint
            brightBackground = "ffffff";
            palette = "000000;5c110c;074224;4d1c0d;00594d;f5c2e7;16de6d;989e9b";
            brightPalette = "2f3030;ff0000;16de6d;f7cd34;0ddeaa;f5c2e7;16de6d;ffffff";
          };
        };
      };
      efi.canTouchEfiVariables = true;
      timeout = 4;
    };

    # CachyOS kernel (provided by the chaotic overlay imported in ../default.nix).
    # mkDefault so a host can fall back to a stock kernel.
    kernelPackages = lib.mkDefault pkgs.linuxPackages_cachyos;

    # Larger /tmp helps big builds (nix, media); back it with tmpfs.
    tmp.useTmpfs = true;
    tmp.tmpfsSize = "50%";

    # Cap the dirty page-cache backlog. The defaults (dirty_ratio=20) let up to
    # ~20% of RAM (~6 GB here) go dirty before the kernel forces synchronous
    # writeback on every writing process. When that backlog targets a slow
    # device — e.g. a big download committing to a USB external SSD — the
    # whole system stalls in bursts. A small absolute cap keeps any single slow device
    # from building a multi-gigabyte backlog. (dirty_bytes overrides
    # dirty_ratio when nonzero.)
    kernel.sysctl = {
      "vm.dirty_bytes" = 268435456; # 256 MB
      "vm.dirty_background_bytes" = 67108864; # 64 MB — start flushing early

      # CachyOS-Settings parity. The CachyOS kernel ships via chaotic, but its
      # companion CachyOS-Settings package (sysctl/udev/tmpfiles) is Arch-only
      # and NOT applied on NixOS, so replicate the load-bearing tweaks here.
      # Values verbatim from CachyOS-Settings 70-cachyos-settings.conf.
      "vm.swappiness" = 100; # zram is fast → lean on it before evicting page cache
      "vm.page-cluster" = 0; # zram: fault one page at a time, no swap readahead
      "vm.vfs_cache_pressure" = 50; # retain dentry/inode cache longer
      "vm.dirty_writeback_centisecs" = 1500; # flush old dirty data less often
      "kernel.nmi_watchdog" = 0; # small perf + power win, one less timer
      "net.core.netdev_max_backlog" = 4096; # deeper RX queue; fewer dropped packets
      "fs.file-max" = 2097152; # raise the global file-handle ceiling
    };
  };

  # Transparent-hugepage defrag policy from CachyOS-Settings (thp.conf). Helps
  # tcmalloc-using apps (Chromium/Electron) without the latency spikes of the
  # default synchronous "madvise"/"always" defrag.
  systemd.tmpfiles.rules = [
    "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
  ];

  # I/O schedulers, matching CachyOS-Settings 60-ioschedulers.rules. NixOS
  # leaves NVMe on "none"; kyber adds light latency-aware ordering. mq-deadline
  # on external USB SSDs (sd*) curbs the writeback bursts that the
  # dirty_bytes cap above also targets.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
  '';

  # zram swap — cheap responsiveness win on a 32 GB laptop.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 5; # used before the disk swapfile below (RAM-speed first)
  };

  # Real overflow tier. zram is *compressed RAM*, not extra capacity — once the
  # 32 GB fills, zram can't help because its compressed pages live in that same
  # RAM. With no disk swap the kernel then OOM-kills processes (it took out
  # Noctalia during a BeamNG-with-traffic session). This 32 GB swapfile on the
  # ext4 root gives genuine spill space so a transient spike pages cold anon
  # memory to NVMe instead of reaping the desktop. Priority 1 (< zram's 5) so
  # it's only touched once zram is exhausted — the slow tier, used last.
  # mkDefault: sized for the 32 GB g815; a smaller host can override wholesale.
  swapDevices = lib.mkDefault [
    {
      device = "/swapfile";
      size = 32 * 1024; # MiB → 32 GiB
      priority = 1;
    }
  ];

  # earlyoom — userspace OOM guard. The kernel's own OOM-killer only fires at
  # ~0 bytes free and picks purely by oom_score, which is how a BeamNG-with-
  # traffic spike got Noctalia/Spotify reaped instead of the game. earlyoom acts
  # earlier (at the free thresholds below) and SIGTERMs the biggest hog, so a
  # memory blowout costs one process, never the desktop session. The swapfile
  # above is the capacity fix; this is the graceful-failure backstop for when
  # even that fills.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10; # SIGTERM when free RAM drops under 10% …
    freeSwapThreshold = 15; # … and free swap under 15% (disk-swap thrash is painful)
    enableNotifications = true; # DMS toast when it kills something
    extraArgs = [
      # NEVER sacrifice the compositor or shell — losing these collapses the whole
      # session. Matched against /proc/*/comm (truncated to 15 chars), so list the
      # wrapped names too — nixpkgs' wrapProgram/wrapQtAppsHook hide the real
      # binary as `.<name>-wrapped` and install the wrapper at the original
      # name, so DMS's actual running comms are `.dms-wrapped` (dms.service's
      # `dms run --session`) and `.quickshell-wra` (its quickshell renderer,
      # `.quickshell-wrapped` truncated) — verified via strace, not the
      # `dms`/`quickshell`/`qs` names the wrapper scripts are installed under.
      # Those bare names are listed anyway, defensively: they don't match today
      # (wrapProgram hides them) but would unprotect the session shell if a
      # future nixpkgs change or a non-wrapped invocation ever exposed them.
      "--avoid"
      "^(niri|\\.dms-wrapped|dms|\\.quickshell-wra|quickshell|qs|polkit-kde-aut|sshd|systemd)$"
    ];
  };

  # Cap crash-dump storage. App/compositor crashes produce large coredumps
  # that are rarely useful here and otherwise grow unbounded under
  # /var/lib/systemd/coredump.
  systemd.coredump.settings.Coredump.MaxUse = "256M";

  # Passwordless one-click for the "BIOS" session button, scoped to the active
  # local wheel session: `systemctl reboot --firmware-setup` sets the
  # boot-to-firmware-UI EFI indication via logind (auth_admin by default). The
  # plain Reboot action is already allowed for the active local session, so
  # only the firmware-setup indication needs a grant. (The Windows-button
  # counterpart is host-specific: systems/g815/windows-dualboot.nix.)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.set-reboot-to-firmware-setup" &&
          subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
