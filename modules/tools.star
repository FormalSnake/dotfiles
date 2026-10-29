load("//lib/launchd.star", "BREW")
load("//lib/paths.star", "TUMBLEWEED")

# The tools every host has, each declared once. Where the platforms get one differently, on(linux,
# darwin) picks: Homebrew on the macbook, zypper, flatpak and pinned releases on Linux.

# From the system package manager. A dict names a package that differs.
CLI = [
    "fish", "tmux", "mosh", "bat", "btop", "lsd", "fd", "fzf", "ripgrep", "zoxide", "yazi", "fastfetch",
    "direnv", "just", "jq", "wget", "chafa", "git", "git-lfs", "gh", "lazygit", "neovim", "bun",
    "ghostscript", "gopls", "tailscale",
    # The store pulls CI builds with it.
    "oras",
    {"linux": "ImageMagick", "darwin": "imagemagick"},
    {"linux": "lua54", "darwin": "lua"},
    {"linux": ["nodejs24", "npm24"], "darwin": "node@24"},
]

def cli(platform):
    out = []
    for n in CLI:
        n = n[platform] if type(n) == "dict" else n
        out += n if type(n) == "list" else [n]
    return out

def tools(host):
    mac = host.platform.is_darwin

    def on(linux, darwin):
        return darwin if mac else linux

    def brew_or(name, linux, cask = False):
        return pkg(name, source = brew(cask = cask)) if mac else linux

    apps = [
        on(service("tailscaled"), service("tailscaled", exec = BREW + "/tailscaled", restart = "always")),
        # The CLI's %post runs groupadd, so it installs after shadow.
        brew_or("1password", pkg("1password", source = zypper(repo = "1password")), cask = True),
        brew_or("1password-cli", pkg("1password-cli", source = zypper(repo = "1password")), cask = True),
        brew_or("nordvpn", pkg(
            "nordvpn",
            source = zypper(repo = "nordvpn"),
            services = [service("nordvpnd.socket"), service("nordvpnd"), service("nordvpnd-killswitch")],
        ), cask = True),
        brew_or("parsec", pkg("parsec", source = flatpak("com.parsecgaming.parsec")), cask = True),
        brew_or("uv", pkg("uv", version = "0.13.6", source = aqua("astral-sh/uv"))),
        brew_or("lazydocker", pkg("lazydocker", version = "0.25.2", source = aqua("jesseduffield/lazydocker"))),
        brew_or("herdr", pkg("herdr", version = "0.9.3", source = github("ogulcancelik/herdr", asset = "herdr-linux-*"))),
    ]

    # The language servers and formatters nvim calls.
    nvim = [
        brew_or("lua-language-server", pkg("lua-language-server", version = "3.19.2", source = aqua("LuaLS/lua-language-server"))),
        brew_or("tree-sitter-cli", pkg("tree-sitter", version = "0.27.1", source = aqua("tree-sitter/tree-sitter"))),
        brew_or("taplo", pkg("taplo", version = "0.10.0", source = aqua("tamasfe/taplo"))),
        brew_or("rust-analyzer", pkg("rust-analyzer", version = "2026-09-28", source = aqua("rust-lang/rust-analyzer"))),
        brew_or("marksman", pkg("marksman", version = "2026-02-08", source = aqua("artempyanykh/marksman"))),
        brew_or("nixfmt", pkg("nixfmt", version = "1.5.0", source = github("NixOS/nixfmt", asset = "nixfmt"))),
        brew_or("vtsls", pkg("vtsls", version = "0.3.0", source = npm("@vtsls/language-server"))),
        brew_or("tailwindcss-language-server", pkg("tailwindcss-language-server", version = "0.16.0", source = npm("@tailwindcss/language-server"))),
        brew_or("yaml-language-server", pkg("yaml-language-server", version = "1.24.0", source = npm("yaml-language-server"))),
        brew_or("dockerfile-language-server", pkg("docker-langserver", version = "0.15.0", source = npm("dockerfile-language-server-nodejs"))),
        brew_or("vscode-langservers-extracted", pkg("vscode-langservers-extracted", version = "4.10.0", source = npm("vscode-langservers-extracted"))),
        # astro-ls's SDK fallback; 7.x dropped tsserverlibrary.js.
        pkg("typescript", version = "5.9.3", source = npm("typescript")),
        pkg("astro-ls", version = "2.16.10", source = npm("@astrojs/language-server")),
        pkg("docker-compose-langserver", version = "0.2.0", source = npm("@microsoft/compose-language-service")),
    ]

    store = [
        pkg("t3", version = "0.1.3", source = github("pingdotgg/t3code", asset = on("t3-*-linux-x64.tar.gz", "t3-*-darwin-arm64.tar.gz"))),
        # The platform tarball holds the real binary; the main package's bin is a postinstall stub.
        # On the macbook Claude Code updates itself.
        pkg(
            "claude",
            source = url("https://registry.npmjs.org/@anthropic-ai/claude-code-%s/-/claude-code-%s-2.1.310.tgz" % (on("linux-x64", "darwin-arm64"), on("linux-x64", "darwin-arm64"))),
            mode = on("pinned", "self_managed"),
        ),
        pkg("fut", version = "0.24", source = on(github("mikker/fut"), github("mikker/fut", asset = "fut-macos-arm64.tar.gz"))),
        pkg("fast", source = git("https://github.com/maaslalani/fast", rev = "26d8fc9c189ba748c68f8930af11dee5c2467f7e", **on({}, {"deps": ["go"]}))),
        pkg("fetch", source = git("https://github.com/areofyl/fetch", rev = "7b19d22c2d8e4b7b2295cc625c9fdf87adcabbcd")),
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "69f954dca8ac24b7e5b269f486f3dae3fc2ec7b5")),
        pkg(
            "clipssh",
            source = git("https://github.com/samuellawrentz/clipssh", rev = "c7f4e8ddcf102302c6375ba51534c7505ddc2616"),
            build = ["sh", "-c", on(
                "install -Dm755 $FSPEC_SRC/clipssh $FSPEC_OUT/bin/clipssh",
                "mkdir -p $FSPEC_OUT/bin && install -m755 $FSPEC_SRC/clipssh $FSPEC_OUT/bin/clipssh",
            )],
            bins = ["clipssh"],
        ),
        # Its releases ship Linux binaries only, so the macbook builds it.
        on(
            pkg("tmux-agent-sidebar", version = "0.13.0", source = github("hiroppy/tmux-agent-sidebar", asset = "tmux-agent-sidebar-linux-*")),
            pkg("tmux-agent-sidebar", source = git("https://github.com/hiroppy/tmux-agent-sidebar", rev = "2cff1cb955363394f8dd9c52d040d027536cfbd8")),
        ),
        pkg(
            "kopuzd",
            source = git(
                "https://github.com/Kopuz-org/kopuz",
                rev = "735a22898992c4b09de2a65323039220db32750b",
                **on({
                    "image": TUMBLEWEED,
                    "deps": ["rustup", "gcc", "cmake", "make", "pkgconf", "alsa-devel", "dbus-1-devel", "libopenssl-devel", "git-core", "gcc-c++"],
                }, {})
            ),
            build_flags = ["-p", "kopuz-kopuzd", "-p", "kopuz-ctl"],
            bins = ["kopuzd", "kopuzctl"],
        ),
    ]

    system = [pkg(n, source = brew()) for n in cli("darwin")] if mac else []
    return system + apps + nvim + store
