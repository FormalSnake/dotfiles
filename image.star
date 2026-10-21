# The bootc image the e1504g's Fedora Atomic root was built from, before that root became
# openSUSE Tumbleweed (spec.star, system.star). Nothing loads this file.

# Fedora 44 is the newest stable release (45 is not out yet); base-main is the desktop-ready
# Fedora Atomic base, rebuilt daily.
BASE = "ghcr.io/ublue-os/base-main:44"

# The commits ~/.config/nix runs, so both roots behave the same.
FORMALSHELL_REV = "e8a800d3da54f586f187a328916785ff691f8759"
MESHTOP_REV = "main"

STAGES = [
    # FormalShell's own non-nix release build: bookworm is the glibc floor its tarball targets.
    """FROM docker.io/library/debian:bookworm AS formalshell
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git
RUN git clone https://github.com/FormalSnake/FormalShell /src && git -C /src checkout %s
RUN /src/dev/tarball.sh /out""" % FORMALSHELL_REV,
    # librepods 1.0.2 (omarchy-pods) with the three patches the nix build carries.
    """FROM registry.fedoraproject.org/fedora:44 AS librepods
RUN dnf install -y git cmake gcc-c++ pkgconf-pkg-config qt6-qtbase-devel qt6-qtconnectivity-devel \\
    qt6-qtdeclarative-devel qt6-qttools-devel pulseaudio-libs-devel openssl-devel patch
RUN git clone --depth 1 --branch v1.0.2 https://github.com/thisisgm/omarchy-pods /src
COPY patches/ /patches/
RUN cd /src && for p in /patches/librepods-*.patch; do patch -p1 < "$p"; done && cd /src/daemon \\
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && cmake --build build -j \\
    && DESTDIR=/out cmake --install build""",
    """FROM registry.fedoraproject.org/fedora:44 AS meshtop
RUN dnf install -y git cargo gcc
RUN git clone https://github.com/FormalSnake/meshtop /src && git -C /src checkout %s
RUN cd /src && cargo build --release --locked && install -Dm755 target/release/meshtop /out/usr/bin/meshtop""" % MESHTOP_REV,
    # Tools with no Fedora 44 package, at the versions the NixOS root runs.
    """FROM registry.fedoraproject.org/fedora:44 AS tools
RUN dnf install -y cargo gcc git golang meson ninja-build systemd-devel dbus-devel hidapi-devel python3-pip unzip xz
RUN cargo install --locked --root /out/usr --git https://github.com/Linus789/wl-clip-persist --tag v0.5.0 \\
    && cargo install --locked --root /out/usr wl-gammarelay-rs \\
    && cargo install --locked --root /out/usr --git https://github.com/oxalica/nil --tag 2026-07-23 nil && rm -f /out/usr/.crates*
# nil and gopls publish no Linux binaries; nvim runs both.
RUN GOBIN=/out/usr/bin GOFLAGS=-trimpath go install golang.org/x/tools/gopls@v0.23.0
RUN git clone --depth 1 --branch v0.7 https://github.com/nowrep/dualsensectl /src/dualsensectl \\
    && meson setup --prefix=/usr /src/dualsensectl/build /src/dualsensectl && meson install -C /src/dualsensectl/build --destdir /out
# 0.9.8 lacks the Discord edition of the Stream Deck Mini (PID 0x00b3).
RUN pip install --no-deps --root /out --prefix /usr git+https://github.com/abcminiuser/python-elgato-streamdeck@ac67de1f70
RUN curl -fLo /out/usr/bin/herdr --create-dirs https://github.com/ogulcancelik/herdr/releases/download/v0.9.3/herdr-linux-x86_64 \\
    && chmod 755 /out/usr/bin/herdr
RUN curl -fLo /tmp/bun.zip https://github.com/oven-sh/bun/releases/download/bun-v1.4.2/bun-linux-x64.zip \\
    && unzip -j /tmp/bun.zip bun-linux-x64/bun -d /out/usr/bin && ln -s bun /out/usr/bin/bunx
RUN mkdir -p /out/usr/lib/helium && curl -fL https://github.com/imputnet/helium-linux/releases/download/0.19.4.1/helium-0.19.4.1-x86_64_linux.tar.xz \\
    | tar -xJ -C /out/usr/lib/helium --strip-components=1 \\
    && ln -s ../lib/helium/helium-wrapper /out/usr/bin/helium \\
    && install -Dm644 /out/usr/lib/helium/helium.desktop /out/usr/share/applications/helium.desktop \\
    && sed -i 's|^Exec=[^ ]*|Exec=/usr/bin/helium|' /out/usr/share/applications/helium.desktop \\
    && install -Dm644 /out/usr/lib/helium/product_logo_256.png /out/usr/share/icons/hicolor/256x256/apps/helium.png
RUN mkdir -p /out/usr/share/icons /out/usr/share/fonts/geist-mono-nerd \\
    && curl -fL https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz | tar -xJ -C /out/usr/share/icons \\
    && curl -fL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/GeistMono.tar.xz | tar -xJ -C /out/usr/share/fonts/geist-mono-nerd
# terminal-browser's launcher sits three levels deep in its tarball, past what fspec links.
RUN mkdir -p /out/usr/lib/terminal-browser && curl -fL https://github.com/zenbu-labs/terminal-browser/releases/download/v0.11.1/terminal-browser-linux-x64.tar.gz \\
    | tar -xz -C /out/usr/lib/terminal-browser --strip-components=1 \\
    && ln -sf /usr/lib64/libvulkan.so.1 /out/usr/lib/terminal-browser/electron/libvulkan.so.1 \\
    && ln -s ../lib/terminal-browser/bin/terminal-browser /out/usr/bin/terminal-browser
RUN git clone --depth 1 --branch 2026-08-10 https://github.com/vinceliuice/Colloid-icon-theme /src/colloid \\
    && /src/colloid/install.sh -d /out/usr/share/icons
# The CBDT build NixOS ships (noto-fonts-color-emoji 2.051): Fedora only packages the COLRv1 one,
# which Pillow renders blank, and streamdeck-keys draws emoji from its 109px strike.
RUN curl -fLo /out/usr/share/fonts/noto-color-emoji/NotoColorEmoji.ttf --create-dirs \\
    https://raw.githubusercontent.com/googlefonts/noto-emoji/v2.051/fonts/NotoColorEmoji.ttf""",
    # Beeper ships only an AppImage, so it is unpacked here and needs no FUSE; extracted, its
    # updater stays off, like the nixpkgs build.
    """FROM registry.fedoraproject.org/fedora:44 AS beeper
RUN curl -fLo /tmp/beeper.AppImage https://beeper-desktop.download.beeper.com/builds/Beeper-4.3.73-x86_64.AppImage \\
    && echo "8fa1d34ea53bfb3f00276d2162089aeb0387d3f9f7831ad4a1c0a930f9a042f4  /tmp/beeper.AppImage" | sha256sum -c \\
    && chmod +x /tmp/beeper.AppImage && cd /tmp && ./beeper.AppImage --appimage-extract >/dev/null \\
    && mkdir -p /out/usr/lib /out/usr/bin && mv /tmp/squashfs-root /out/usr/lib/beeper && chmod -R a+rX /out/usr/lib/beeper \\
    && printf '#!/bin/sh\\nexec /usr/lib/beeper/AppRun "$@"\\n' > /out/usr/bin/beeper && chmod 755 /out/usr/bin/beeper""",
    # boxxy needs gtk4 4.22 and libadwaita 1.9, newer than the CI runner's, so it builds here.
    """FROM registry.fedoraproject.org/fedora:44 AS boxxy
RUN dnf install -y git cargo gcc cmake perl pkgconf-pkg-config gtk4-devel libadwaita-devel gtksourceview5-devel \\
    gstreamer1-devel gstreamer1-plugins-base-devel
RUN git clone https://github.com/miifrommera/boxxy /src && git -C /src checkout 17dfb73270bfa1ea7d0ff0bb59ed98cb7db90816 \\
    && cd /src && cargo build --release --locked -p boxxy-app -p boxxy-agent --features boxxy-app/disable-self-update \\
    && install -Dm755 target/release/boxxy-terminal /out/usr/bin/boxxy-terminal \\
    && install -Dm755 target/release/boxxy-agent /out/usr/bin/boxxy-agent \\
    && install -Dm644 flatpak/dev.boxxy.BoxxyTerminal.desktop /out/usr/share/applications/dev.boxxy.BoxxyTerminal.desktop \\
    && install -Dm644 resources/icons/dev.boxxy.BoxxyTerminal.png /out/usr/share/icons/hicolor/256x256/apps/dev.boxxy.BoxxyTerminal.png""",
    # dualsense-osk's on-screen keyboard; Fedora 44 has no wvkbd.
    """FROM registry.fedoraproject.org/fedora:44 AS wvkbd
RUN dnf install -y git gcc make scdoc pkgconf-pkg-config wayland-devel wayland-protocols-devel libxkbcommon-devel pango-devel cairo-devel
RUN git clone --depth 1 --branch v0.20 https://github.com/jjsullivan5196/wvkbd /src && make -C /src LAYOUT=mobintl PREFIX=/usr DESTDIR=/out install""",
    # Discord 1.0.164, built the way flathub/com.discordapp.Discord does it: the linux tar.gz is only an
    # updater bootstrap, so the host and modules come from the distro archives with the new updater off.
    # moonlight v2026.10.0 is injected per its manual install docs (app.asar -> _app.asar plus resources/app).
    """FROM registry.fedoraproject.org/fedora:44 AS discord
RUN dnf install -y brotli jq unzip
RUN curl -fLo /tmp/bun.zip https://github.com/oven-sh/bun/releases/download/bun-v1.4.2/bun-linux-x64.zip \\
    && unzip -j /tmp/bun.zip bun-linux-x64/bun -d /usr/local/bin
RUN set -eu; d=https://stable.dl2.discordapp.net/distro/app/stable/linux/x64/1.0.164; o=/out/usr/lib/discord \\
    && mkdir -p $o/modules/discord_krisp/KMS/logs \\
    && curl -fLo /tmp/host.br $d/full.distro \\
    && echo "328a07aaaf61d2af4a52c6593e88169ee7b7b71d0567bc808aa4931b7863e64f  /tmp/host.br" | sha256sum -c \\
    && brotli -cd /tmp/host.br | tar -x -C $o --strip-components 1 \\
    && for m in discord_desktop_core:709b4f37ea6d2f6334e817aadccc92eb37fa0f7ad492b5f89a9b660e17ecb4cc \\
        discord_erlpack:f41f248c3c916ff4ff8f39e8a311d420f97f0296db855338171acabd2ba694d6 \\
        discord_game_utils:1dadb2b37212bc59debf4362446b096015d775acb6c39c813cb0f8e3d2175b51 \\
        discord_krisp:88aa3242ee23a072eb1d834a0c7da32812bbf545e270d994595253e8609ffadd \\
        discord_rpc:c3814a3273ea5e8f3460211f581f7ca6fe40d5f5db834cd806f3354bef0b5d53 \\
        discord_spellcheck:f2dedd3e58fe79f3756222811189d578ef9fb4cfd15938d31cb102ea1b13e8db \\
        discord_utils:4d3995ee2f8f4689619a50bc6fdaae28c12c635d9b7eeabe3bd515e3471084d3 \\
        discord_voice:b1f7d252ec909c584ec77e0a73b9c36030d4a33488c40a5a1315b4a4a7addc87 \\
        discord_zstd:c2ba5080cfd3efdeaa3164f4a849906a45e8a143a3aff3bb224dbe4b4c96b823; do \\
        n=${m%%:*}; curl -fLo /tmp/$n.br $d/$n/1/full.distro \\
        && echo "${m#*:}  /tmp/$n.br" | sha256sum -c \\
        && mkdir -p $o/modules/$n && brotli -cd /tmp/$n.br | tar -x -C $o/modules/$n --strip-components 1; done \\
    && jq '.newUpdater = false | .localModulesRoot = "/usr/lib/discord/modules"' $o/resources/build_info.json > /tmp/bi.json \\
    && mv /tmp/bi.json $o/resources/build_info.json
RUN mkdir -p /out/usr/lib/moonlight && curl -fLo /tmp/moonlight.tar.gz https://github.com/moonlight-mod/moonlight/releases/download/v2026.10.0/dist.tar.gz \\
    && echo "d66c9fad8d855d2c2b2747ef5b6ea37fa29f4717b2a443ebf03b1ff1399038be  /tmp/moonlight.tar.gz" | sha256sum -c \\
    && tar -xzf /tmp/moonlight.tar.gz -C /out/usr/lib/moonlight \\
    && cd /out/usr/lib/discord/resources && mv app.asar _app.asar && mkdir app \\
    && printf '{"name":"discord","main":"./injector.js","private":true}\\n' > app/package.json \\
    && printf 'require("/usr/lib/moonlight/injector").inject(require("path").join(__dirname, "../_app.asar"));\\n' > app/injector.js
# extensions-dist only publishes the current build at a fixed URL: an upstream release fails this check.
RUN for e in moonlight-css:d0e68e1b6398e4e0c0e0bcc204732a8716fb238d786805ac3f737a97d92fec74 \\
        lastFmRpc:2e59681c3cf1def5ce9866504e71327b4cd60478ccde8c2842eb44bb9554528c; do \\
        n=${e%%:*}; curl -fLo /tmp/$n.asar https://moonlight-mod.github.io/extensions-dist/$n.asar \\
        && echo "${e#*:}  /tmp/$n.asar" | sha256sum -c \\
        && bun x @electron/asar@4.3.1 extract /tmp/$n.asar /out/usr/lib/moonlight-extensions/$n; done
RUN mkdir -p /out/usr/bin \\
    && printf '#!/bin/sh\\nexec /usr/lib/discord/Discord --disable-features=WebRtcAllowInputVolumeAdjustment "$@"\\n' > /out/usr/bin/discord \\
    && chmod 755 /out/usr/bin/discord""",
]

DESKTOP = [
    "hyprland", "uwsm", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "greetd", "sway",
    "swayidle", "wl-clipboard", "grim", "slurp", "wf-recorder", "brightnessctl", "ddcutil", "wlsunset",
    "cava", "playerctl", "mpv", "qrencode", "wtype", "tesseract", "tesseract-langpack-eng", "xdg-utils",
    "evolution-data-server", "geoclue2", "uxplay", "gtk4", "libadwaita", "python3-gobject",
    "hyprlock", "hypridle", "hyprpicker", "matugen", "ghostty", "adwaita-icon-theme", "hidapi",
    "python3-evdev", "python3-fonttools", "xrdb",
    "gnome-keyring", "gvfs", "tumbler", "nautilus", "adw-gtk3-theme", "qt6ct", "qt5ct",
    "adwaita-sans-fonts", "adwaita-mono-fonts", "google-noto-sans-symbols-2-fonts",
    "google-noto-sans-cjk-fonts", "liberation-fonts", "easyeffects", "pipewire-utils",
    # The mimeapps.list targets; Apostrophe is retired in Fedora and comes from Flathub.
    "papers", "loupe", "gnome-text-editor", "celluloid",
    # Messages: video thumbnails through ffmpeg, notifications, its Vulkan renderer and media playback.
    "ffmpeg-free", "libnotify", "vulkan-loader", "gstreamer1-plugins-good", "gstreamer1-plugins-bad-free",
    "gstreamer1-plugin-libav",
    # dillo has a Fedora build of the NixOS version; dcal runs on quickshell; the rest are what the
    # fspec-installed kopuz, formalmusic and terminal-browser (Electron) load at runtime.
    "dillo", "quickshell", "webkit2gtk4.1", "gtk3", "libsoup3", "glib-networking", "alsa-lib", "libxdo",
    "libayatana-appindicator-gtk3", "opus", "mesa-libgbm", "libxkbfile", "gtksourceview5", "nss",
    "at-spi2-atk", "cups-libs", "libXcomposite", "libXdamage", "libXrandr", "libsecret", "pipewire-libs",
    "libxshmfence",
]

SYSTEM = [
    "tailscale", "syncthing", "moby-engine", "tuned", "tuned-ppd", "fish",
    "fuse-sshfs", "usbmuxd", "libimobiledevice-utils", "ifuse", "smartmontools",
    # fish's fish_command_not_found calls its /usr/libexec/pk-command-not-found.
    "PackageKit-command-not-found",
]

CLI = [
    "neovim", "ripgrep", "fd-find", "bat", "btop", "zoxide", "fzf", "git", "git-lfs", "gh", "jq",
    "tmux", "direnv", "just", "fastfetch", "lsd", "lazygit", "yazi", "mosh", "wget2-wget", "ImageMagick", "chafa", "lua",
    "python3-pillow", "uv",
    # nvim: npm-sourced language servers run on node and install with npm; nvim-treesitter compiles
    # its parsers with gcc; snacks converts PDFs with ghostscript; rust-analyzer reads rust-src.
    "nodejs24", "nodejs24-npm", "gcc", "ghostscript", "rust-src",
]

e1504g_image = image(
    base = BASE,
    copr = ["sdegler/hyprland", "scottames/ghostty", "atim/lazygit", "lihaohong/yazi"],
    repos = ["https://pkgs.tailscale.com/stable/fedora/tailscale.repo"],
    packages = dnf(DESKTOP + SYSTEM + CLI),
    stages = STAGES,
    steps = [
        "COPY --from=formalshell /out/ /tmp/formalshell/",
        "RUN tar -xzf /tmp/formalshell/formalshell-x86_64-linux.tar.gz -C /usr --strip-components=1 && rm -rf /tmp/formalshell",
        "COPY --from=librepods /out/ /",
        "COPY --from=meshtop /out/ /",
        "COPY --from=tools /out/ /",
        "COPY --from=discord /out/ /",
        "COPY --from=wvkbd /out/ /",
        "COPY --from=beeper /out/ /",
        "COPY --from=boxxy /out/ /",
        # Fedora retired pam_ssh_agent_auth; pam_rssh checks the forwarded agent the same way.
        "RUN dnf install -y https://github.com/z4yx/pam_rssh/releases/download/v1.2.2-rc2/fedora-pam-rssh-1.2.2-1.fc44.x86_64.rpm && dnf clean all",
        # 1Password installs into /opt, which is /var/opt on bootc and never updated from the image.
        """RUN rpm --import https://downloads.1password.com/linux/keys/1password.asc \\
    && printf '[1password]\\nname=1Password\\nbaseurl=https://downloads.1password.com/linux/rpm/stable/$basearch\\nenabled=1\\ngpgcheck=1\\nrepo_gpgcheck=1\\ngpgkey=https://downloads.1password.com/linux/keys/1password.asc\\n' > /etc/yum.repos.d/1password.repo \\
    && mkdir -p /var/opt && dnf install -y 1password 1password-cli && dnf clean all \\
    && mv /var/opt/1Password /usr/lib/1Password && echo 'L /var/opt/1Password - - - - /usr/lib/1Password' > /usr/lib/tmpfiles.d/1password.conf""",
        "COPY e1504g/rootfs/ /",
        # The repo file comes from rootfs; Nord publishes no .repo URL, only install.sh, which writes the same.
        "RUN rpm --import https://repo.nordvpn.com/gpg/nordvpn_public.asc && dnf install -y nordvpn && dnf clean all",
        "RUN systemd-sysusers && fc-cache -f /usr/share/fonts/geist-mono-nerd /usr/share/fonts/noto-color-emoji",
        "RUN sed -i '1a auth sufficient libpam_rssh.so auth_key_file=/etc/ssh/authorized_keys.d/${user}' /etc/pam.d/sudo",
        # The PAM lock file and the greetd session; its user units land in a throwaway home and
        # come from the home layer instead.
        "RUN HOME=/tmp/fs-install /usr/bin/formalshell install --yes && rm -rf /tmp/fs-install",
        "RUN systemctl enable tailscaled.service sshd.service greetd.service tuned.service tuned-ppd.service power-cap.service docker.socket syncthing@kyandesutter.service nordvpnd.socket nordvpnd.service nordvpnd-killswitch.service",
    ],
    kernel_args = ["mitigations=off", "intel_iommu=on", "modprobe.blacklist=ucsi_acpi,intel_ish_ipc"],
)
