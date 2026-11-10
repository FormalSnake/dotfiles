load("//lib/paths.star", "home_of")
load("//modules/home/claude_settings.star", "SETTINGS")

# What the second profile, ~/.claude-pulse, shares with the first; it signs in separately.
ROLES = {
    "macbook": "an unattended, always-on development server reached over ssh. Nobody sits at it, so its screen, cursor and desktop are not the user's. The user sits at e1504g when meshtop hosts status shows it online, otherwise at g815; both run Linux with Hyprland",
    "g815": "the compiler, tester and GPU host",
    "e1504g": "the weak client and runtime tester. Never compile on it",
}

PULSE = ["CLAUDE.md", "AGENTS.md", "settings.json", "agents", "commands", "hooks", "rules", "skills", "plugins"]

def claude(host):
    shell = "/bin/zsh" if host.platform.is_darwin else "/usr/bin/bash"
    return [
        file("~/.claude/settings.json", content = dict(SETTINGS, env = {"SHELL": shell}), format = "json"),
        file("~/.claude/rules/host.md", content = _host_rule(host)),
        file("~/.pi/agent/CLAUDE.md", mode = "link", target = "~/.claude/CLAUDE.md"),
        # Seeded with only the trust flag, since patch keys split on dots and the path has one.
        file(
            "~/.claude-pulse/.claude.json",
            mode = "seed",
            perms = "0600",
            content = '{"mcpServers": {}, "projects": {"%s/.config/formalspec": {"hasTrustDialogAccepted": true}}}\n' % home_of(host),
        ),
    ] + [file("~/.claude-pulse/" + p, mode = "link", target = "~/.claude/" + p) for p in PULSE]

def _host_rule(host):
    role = ROLES.get(host.name)
    if role:
        return "YOU ARE ON THIS HOST: %s, %s.\n" % (host.name, role)
    return "YOU ARE ON THIS HOST: %s\n" % host.name
