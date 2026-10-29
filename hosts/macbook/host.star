load("//lib/keys.star", "AUTHORIZED_KEYS")
load("//lib/tree.star", "tree")
load("//modules/fastfetch/fastfetch.star", "fastfetch")
load("//modules/home/home.star", "home")
load("//modules/secrets.star", "secrets")
load("//modules/storage-gc/storage-gc.star", "storage_gc")
load("//modules/tools.star", "tools")
load("//hosts/macbook/defaults.star", "SYSTEM")
load("//hosts/macbook/packages.star", "BREW", "STORE")
load("//hosts/macbook/services.star", "SERVICES")

# The dev server the laptops reach over ssh and mosh.

ROOT = "hosts/macbook/"

# What apps or Kyan edit in place, linked into the repo so the edit lands here.
LINKED = [
    ROOT + "home/.config/lynk-browser",
    "home/.pi/agent/extensions/mcp-bridge",
    "home/.pi/agent/extensions/mode-cycle",
    "home/.pi/agent/settings.json",
    "home/.pi/agent/keybindings.json",
    "home/.claude/agents",
    "home/.claude/commands",
    "home/.claude/hooks",
    "home/.claude/CLAUDE.md",
    "home/.claude/AGENTS.md",
    "home/.claude/CLAUDE-cloudflare.md",
    "home/.claude/CLAUDE-cloudflare-mini.md",
]

# On the external SSD; the links dangle while it is unmounted.
DRIVE = "/Volumes/Kyan Drive"
ON_DRIVE = {"Movies": "Movies", ".gradle": "gradle", "Library/Developer/CoreSimulator": "CoreSimulator"}

HOME_FILES = [file("~/" + p, mode = "link", target = DRIVE + "/" + sub) for p, sub in ON_DRIVE.items()] + [
    # The shared ssh config names the agent by the path 1Password uses on Linux.
    file("~/.1password/agent.sock", mode = "link", target = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"),
]

ROOT_FILES = tree([ROOT + "rootfs/"], perms = {"/etc/sudoers.d/10-fspec": "0440"}) + [
    file("/etc/ssh/authorized_keys.d/kyandesutter", content = AUTHORIZED_KEYS, perms = "0644"),
    # Not the builder key, which would get passwordless sudo.
    file("/etc/ssh/sudo_authorized_keys", content = AUTHORIZED_KEYS, perms = "0444"),
    # /etc/pam.d/sudo includes sudo_local.
    file("/etc/pam.d/sudo_local", content = "auth       sufficient     /opt/fspec/current/pkgs/pam_ssh_agent_auth/lib/pam_ssh_agent_auth.so file=/etc/ssh/sudo_authorized_keys\n"),
    # MagicDNS for *.ts.net, which the open-source tailscaled does not write.
    file("/etc/resolver/ts.net", content = "nameserver 100.100.100.100\n"),
]

SECRETS = secrets(
    "macbook",
    dir = "/var/run/fspec/secrets",
    owner = "kyandesutter:staff",
    identities = ["~/.config/age/keys.txt"],
) + [
    # /var/run is emptied at boot.
    service("secrets", exec = "/usr/local/bin/fspec secret install"),
]

macbook = host(
    name = "macbook",
    platform = "aarch64-darwin",
    users = [user("kyandesutter", uid = 502, shell = "/opt/homebrew/bin/fish")],
    modules = [tools, BREW, STORE, home(linked = LINKED), HOME_FILES, fastfetch, ROOT_FILES, SECRETS, SYSTEM, SERVICES, storage_gc()],
)
