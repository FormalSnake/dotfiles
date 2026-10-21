load("//home.star", "home")
load("//system.star", "PACKAGES", "system")

# Kyan's Linux hosts, ported from ~/.config/nix. The e1504g runs openSUSE Tumbleweed beside its
# NixOS root; GAPS.md lists what is not ported and why.

# agenix's secrets (the same .age files as ~/.config/nix/secrets). NixOS puts them in /run/agenix;
# here they persist under /etc.
SECRETS = ["openai", "anthropic", "gemini", "deepseek", "nucleo-license", "npm-github-token",
           "npm-registry-token", "wstunnel-path-prefix", "wstunnel-endpoint", "couchdb-admin",
           "lastfm-api-key"]

def secrets():
    return [secret("/etc/fspec/secrets/" + n, src = "secrets/%s.age" % n, owner = "kyandesutter") for n in SECRETS]

e1504g = host(
    name = "e1504g",
    platform = "x86_64-linux",
    system = tumbleweed(packages = PACKAGES),
    users = [user("kyandesutter", uid = 1000, shell = "fish", groups = ["wheel", "video", "audio", "input", "docker", "uinput", "nordvpn"])],
    modules = secrets() + [system, home],
)

hosts = [e1504g]
