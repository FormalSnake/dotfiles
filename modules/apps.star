# The apps installed from the shell. `fspec app` keeps the list in //apps.star; a host gets
# its own entries by adding `apps` to its modules.
load("//apps.star", "APPS")

def _source(a):
    s, r = a["source"], a["ref"]
    if s == "flatpak":
        return flatpak(r)
    if s == "zypper":
        return zypper(r)
    if s == "pacman":
        return pacman(r)
    if s == "apt":
        return apt(r)
    if s == "dnf":
        return dnf(r)
    if s == "aqua":
        return aqua(r)
    if s == "github":
        return github(r)
    if s == "npm":
        return npm(r)
    if s == "cargo":
        return cargo(r)
    if s == "brew":
        return brew(r)
    if s == "cask":
        return brew(r, cask = True)
    fail("apps.star: no source " + s)

def apps(host):
    return [pkg(a["name"], source = _source(a)) for a in APPS.get(host.name, [])]
