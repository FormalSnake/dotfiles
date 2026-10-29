load("//lib/tree.star", "tree")
load("//modules/home/apps.star", "FLATPAKS", "NVIM", "TOOLS")
load("//modules/home/claude.star", "claude")
load("//modules/home/discord.star", "DISCORD")
load("//modules/home/kde.star", "KDE")
load("//modules/home/services.star", "SERVICES")
load("//modules/t3code/t3code.star", "t3code")

# Where macOS keeps what Linux keeps in ~/.config.
DARWIN_PATHS = {
    ".config/go/env": "Library/Application Support/go/env",
    ".config/lazydocker/config.yml": "Library/Application Support/jesseduffield/lazydocker/config.yml",
}

def home(linked = []):
    """Every host's home: home/, the Linux layer on Linux, then hosts/<name>/home/.

    `linked` names repo paths that link into the checkout instead, so an edit lands in the repo.
    """
    def module(host):
        linux = host.platform.is_linux
        roots = ["home/"] + (["modules/linux/home/"] if linux else []) + ["hosts/%s/home/" % host.name]
        dests = {src: _dest(roots, src) for src in linked}
        files = tree(roots, dest = "~/", skip = dests.values(), rename = {} if linux else DARWIN_PATHS)
        files += [file("~/" + d, src = src, mode = "link") for src, d in dests.items()]
        files += claude(host)
        if linux:
            files += SERVICES + KDE + FLATPAKS + DISCORD + t3code(host.name) + TOOLS + NVIM
        return files
    return module

def _dest(roots, src):
    for root in roots:
        if src.startswith(root):
            return src.removeprefix(root)
    fail("linked path %s is in none of %s" % (src, roots))
