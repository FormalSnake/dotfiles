# Homebrew stays Homebrew; the store carries what has no formula or cask.

FORMULAE = [
    # shell and terminal
    "fish", "tmux", "mosh", "bat", "btop", "lsd", "fd", "fzf", "ripgrep", "zoxide", "yazi", "fastfetch",
    "direnv", "just", "jq", "wget", "coreutils", "stow", "chafa", "watchman", "terminal-notifier",
    # git and dev
    "git", "git-lfs", "gh", "lazygit", "lazydocker", "neovim", "cmake", "go", "zig", "deno", "bun",
    "node@24", "uv", "python@3.14", "pillow", "lua", "opencode", "herdr", "dipc", "ffmpeg", "imagemagick",
    "cocoapods", "fastlane", "xcbeautify", "mas", "libadwaita",
    # nvim's language servers, formatters and parser builds
    "lua-language-server", "rust-analyzer", "gopls", "marksman", "taplo", "nixfmt", "yaml-language-server",
    "tailwindcss-language-server", "vscode-langservers-extracted", "dockerfile-language-server", "vtsls",
    "tree-sitter-cli", "ghostscript",
    # clipssh's clipboard images; an older remote's locked fspec
    "pngpaste", "oras",
    # network, remote iPhone, VPN
    "tailscale", "wireguard-tools", "libimobiledevice", "ideviceinstaller", "openssl@3",
    # Obsidian LiveSync's backend
    "couchdb",
]

CASKS = [
    "1password", "1password-cli", "aldente", "android-studio", "betterdisplay", "bluebubbles",
    "clop", "codex", "font-sf-pro", "ghostty", "google-chrome", "gstreamer-runtime",
    "jump-desktop-connect", "nordvpn", "orbstack", "parsec", "syncthing-app", "t3-code",
    "terminal-browser", "the-unarchiver", "zulu@21",
]

BREW = (
    [pkg(n, source = brew()) for n in FORMULAE] +
    [pkg(n, source = brew(cask = True)) for n in CASKS] +
    [pkg("markdown-preview", source = brew(cask = True, tap = "pluk-inc/tap"))]
)

def sh(*steps):
    return ["sh", "-c", " && ".join(["set -e", 'cd "$FSPEC_SRC"'] + list(steps))]

def nd_app(name, title, repo, rev, icon):
    """A NativeDesktop app built from source and wrapped in the bundle its nix package makes."""
    plist = "".join([
        '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>',
        "<key>CFBundleDevelopmentRegion</key><string>en</string>",
        "<key>CFBundleExecutable</key><string>%s</string>" % name,
        "<key>CFBundleIdentifier</key><string>dev.formalsnake.%s</string>" % name,
        "<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>",
        "<key>CFBundleName</key><string>%s</string>" % title,
        "<key>CFBundleDisplayName</key><string>%s</string>" % title,
        "<key>CFBundlePackageType</key><string>APPL</string>",
        "<key>CFBundleShortVersionString</key><string>0.1.0</string>",
        "<key>CFBundleVersion</key><string>0.1.0</string>",
        "<key>CFBundleIconFile</key><string>AppIcon</string>",
        "<key>LSMinimumSystemVersion</key><string>14.0</string>",
        "<key>NSPrincipalClass</key><string>NSApplication</string>",
        "<key>NSHighResolutionCapable</key><true/>",
        # A Dock launch has no Homebrew on PATH, and the apps shell out to ffmpeg.
        "<key>LSEnvironment</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>",
        "</dict></plist>",
    ])
    app = "$FSPEC_OUT/%s.app/Contents" % title
    return pkg(
        name,
        source = git("https://github.com/" + repo, rev = rev),
        build = sh(
            "cargo build --release --locked --package " + name,
            "mkdir -p \"%s/MacOS\" \"%s/Resources\" \"$FSPEC_OUT/bin\"" % (app, app),
            "printf '%%s' '%s' > \"%s/Info.plist\"" % (plist, app),
            "printf 'APPL????' > \"%s/PkgInfo\"" % app,
            # macOS 26's sips fails writing a 1024px PNG straight to icns; iconutil takes an iconset.
            "mkdir -p \"$FSPEC_SRC.iconset\"",
            "for s in 16 32 128 256 512; do sips -z $s $s %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}.png\" > /dev/null; sips -z $((s*2)) $((s*2)) %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}@2x.png\" > /dev/null; done" % (icon, icon),
            "iconutil -c icns \"$FSPEC_SRC.iconset\" -o \"%s/Resources/AppIcon.icns\"" % app,
            "cp target/release/%s \"%s/MacOS/%s\"" % (name, app, name),
            "ln -s ../%s.app/Contents/MacOS/%s \"$FSPEC_OUT/bin/%s\"" % (title, name, name),
        ),
        apps = [title + ".app"],
    )

STORE = [
    pkg("fut", version = "0.24", source = github("mikker/fut", asset = "fut-macos-arm64.tar.gz")),
    # Its releases ship Linux binaries only.
    pkg("tmux-agent-sidebar", source = git("https://github.com/hiroppy/tmux-agent-sidebar", rev = "2cff1cb955363394f8dd9c52d040d027536cfbd8")),
    pkg("t3", version = "0.1.3", source = github("pingdotgg/t3code", asset = "t3-*-darwin-arm64.tar.gz")),
    pkg("pi", version = "1.1.0", source = github("badlogic/pi-mono", asset = "pi-darwin-arm64.tar.gz")),
    pkg("stripe", version = "1.43.2", source = github("stripe/stripe-cli", asset = "stripe_*_mac-os_arm64.tar.gz")),
    # Claude Code updates itself from the platform tarball's binary.
    pkg("claude", source = url("https://registry.npmjs.org/@anthropic-ai/claude-code-darwin-arm64/-/claude-code-darwin-arm64-2.1.310.tgz"), mode = "self_managed"),
    pkg("portless", version = "0.15.4", source = npm("portless")),
    # astro-ls's SDK fallback; 7.x dropped tsserverlibrary.js.
    pkg("typescript", version = "5.9.3", source = npm("typescript")),
    pkg("astro-ls", version = "2.16.10", source = npm("@astrojs/language-server")),
    pkg("docker-compose-langserver", version = "0.2.0", source = npm("@microsoft/compose-language-service")),
    pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "69f954dca8ac24b7e5b269f486f3dae3fc2ec7b5")),
    pkg("fetch", source = git("https://github.com/areofyl/fetch", rev = "7b19d22c2d8e4b7b2295cc625c9fdf87adcabbcd")),
    pkg("fast", source = git("https://github.com/maaslalani/fast", rev = "26d8fc9c189ba748c68f8930af11dee5c2467f7e", deps = ["go"])),
    pkg(
        "clipssh",
        source = git("https://github.com/samuellawrentz/clipssh", rev = "c7f4e8ddcf102302c6375ba51534c7505ddc2616"),
        build = ["sh", "-c", "mkdir -p $FSPEC_OUT/bin && install -m755 $FSPEC_SRC/clipssh $FSPEC_OUT/bin/clipssh"],
        bins = ["clipssh"],
    ),
    pkg("kopuz", version = "0.67.0", source = github("Kopuz-org/kopuz", asset = "Kopuz_*_aarch64.dmg"), apps = ["Kopuz.app"]),
    nd_app("messages", "Messages", "FormalStudio/messages", "29ac1eeedd10745377486851075691e0ec45800e", "packaging/linux/dev.formalsnake.messages.png"),
    nd_app("formalmusic", "FormalMusic", "FormalStudio/formalmusic", "4aeef799e584f6a69a40eef9fb69d92f73b1611d", "packaging/icon.png"),
    pkg(
        "kopuzd",
        source = git("https://github.com/Kopuz-org/kopuz", rev = "735a22898992c4b09de2a65323039220db32750b"),
        build_flags = ["-p", "kopuz-kopuzd", "-p", "kopuz-ctl"],
        bins = ["kopuzd", "kopuzctl"],
    ),
    # The macOS release carries only usbfluxctl. Built as nixpkgs does, against Homebrew's
    # libplist with the format constants libplist 2.3 renamed.
    pkg(
        "usbfluxd",
        source = git("https://github.com/corellium/usbfluxd", rev = "422734fd2b01ad4fefeefb9c8c4e65a5abd69f0f"),
        build = sh(
            "brew install -q autoconf automake libtool pkgconf libplist",
            "sed -i '' 's/with_static_libplist=yes/with_static_libplist=no/' configure.ac",
            "sed -i '' -e 's|PLIST_FORMAT_BINARY|//PLIST_FORMAT_BINARY|' -e 's|PLIST_FORMAT_XML,|NOT_PLIST_FORMAT_XML,|' usbfluxd/utils.h",
            "autoreconf -fi",
            "./configure",
            "make",
            "mkdir -p \"$FSPEC_OUT/bin\"",
            "install -m755 usbfluxd/usbfluxd tools/usbfluxctl \"$FSPEC_OUT/bin/\"",
        ),
    ),
    # sudo's PAM module, with nixpkgs' patches against the system OpenPAM. Modern autoconf picks
    # gnu23, which breaks the K&R code in openbsd-compat, and the SDK's fortify macros collide
    # with its replacements.
    pkg(
        "pam_ssh_agent_auth",
        source = git("https://github.com/jbeverly/pam_ssh_agent_auth", rev = "7ff785809f6ecad45051e333c0ffa72e15ba4f2a"),
        patches = glob("patches/pam_ssh_agent_auth-*.patch"),
        build = sh(
            "git clone -q https://github.com/floodyberry/ed25519-donna \"$FSPEC_SRC.donna\"",
            "git -C \"$FSPEC_SRC.donna\" checkout -q 8757bd4cd209cb032853ece0ce413f122eef212c",
            "mkdir -p ed25519-donna && cp -R \"$FSPEC_SRC.donna/.\" ed25519-donna/",
            "brew install -q autoconf automake openssl@3",
            "autoreconf -fi",
            "ssl=$(brew --prefix openssl@3)",
            "CFLAGS=\"-std=gnu99 -D_FORTIFY_SOURCE=0\" ./configure --without-openssl-header-check --with-cflags=\"-I$PWD -I$ssl/include\" --with-ldflags=\"-L$ssl/lib\"",
            "make LD=cc",
            "mkdir -p \"$FSPEC_OUT/lib\"",
            "install -m755 pam_ssh_agent_auth.so \"$FSPEC_OUT/lib/pam_ssh_agent_auth.so\"",
        ),
    ),
]
