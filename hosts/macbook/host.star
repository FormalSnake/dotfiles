load("//lib/tree.star", "tree")
load("//modules/fastfetch/fastfetch.star", "fastfetch")
load("//modules/home/apps.star", "claude_pulse")
load("//modules/secrets.star", "secrets")
load("//hosts/macbook/defaults.star", "SYSTEM")
load("//hosts/macbook/packages.star", "BREW", "STORE")
load("//hosts/macbook/services.star", "HOME", "SERVICES")

# The dev server the laptops reach over ssh and mosh.

ROOT = "hosts/macbook/"

# What apps or Kyan edit in place, linked into the repo so the edit lands here.
LINKED = [
    ".config/lynk-browser",
    ".pi/agent/extensions/mcp-bridge",
    ".pi/agent/extensions/mode-cycle",
    ".claude/agents",
    ".claude/commands",
    ".claude/hooks",
    ".pi/agent/settings.json",
    ".pi/agent/keybindings.json",
    ".claude/CLAUDE.md",
    ".claude/AGENTS.md",
    ".claude/CLAUDE-cloudflare.md",
    ".claude/CLAUDE-cloudflare-mini.md",
]

# The second Claude Code profile shares the primary's config; it signs in separately.
PULSE = ["CLAUDE.md", "AGENTS.md", "settings.json", "agents", "commands", "hooks", "rules", "skills", "plugins"]

# On the external SSD; the links dangle while it is unmounted.
DRIVE = "/Volumes/Kyan Drive"
ON_DRIVE = {"Movies": "Movies", ".gradle": "gradle", "Library/Developer/CoreSimulator": "CoreSimulator"}

HOME_FILES = (
    tree([ROOT + "home/"], dest = "~/", skip = LINKED) +
    [file("~/" + p, src = ROOT + "home/" + p, mode = "link") for p in LINKED] +
    [file("~/.claude-pulse/" + p, mode = "link", target = "~/.claude/" + p) for p in PULSE] +
    [file("~/" + p, mode = "link", target = DRIVE + "/" + sub) for p, sub in ON_DRIVE.items()] +
    claude_pulse(HOME) + [
        file("~/.pi/agent/CLAUDE.md", src = ROOT + "home/.claude/CLAUDE.md", mode = "link"),
        # The Linux hosts' Stream Deck, DualSense and FormalShell read T3 Code state from here.
        file("~/.local/bin/t3-agents", src = "home/.local/bin/t3-agents", perms = "0755"),
    ]
)

ROOT_FILES = tree([ROOT + "rootfs/"], perms = {
    "/etc/ssh/authorized_keys.d/kyandesutter": "0644",
    # Not the builder key, which would get passwordless sudo.
    "/etc/ssh/sudo_authorized_keys": "0444",
    "/etc/sudoers.d/10-fspec": "0440",
}) + [
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
    modules = [BREW, STORE, HOME_FILES, fastfetch("macbook"), ROOT_FILES, SECRETS, SYSTEM, SERVICES],
)
