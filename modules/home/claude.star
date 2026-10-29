load("//lib/paths.star", "home_of")
load("//modules/home/claude_settings.star", "SETTINGS")

# What the second profile, ~/.claude-pulse, shares with the first; it signs in separately.
PULSE = ["CLAUDE.md", "AGENTS.md", "settings.json", "agents", "commands", "hooks", "rules", "skills", "plugins"]

def claude(host):
    shell = "/bin/zsh" if host.platform.is_darwin else "/usr/bin/bash"
    return [
        file("~/.claude/settings.json", content = dict(SETTINGS, env = {"SHELL": shell}), format = "json"),
        file("~/.claude/rules/host.md", content = "YOU ARE ON THIS HOST: %s\n" % host.name),
        file("~/.pi/agent/CLAUDE.md", mode = "link", target = "~/.claude/CLAUDE.md"),
        # Seeded with only the trust flag, since patch keys split on dots and the path has one.
        file(
            "~/.claude-pulse/.claude.json",
            mode = "seed",
            perms = "0600",
            content = '{"mcpServers": {}, "projects": {"%s/.config/formalspec": {"hasTrustDialogAccepted": true}}}\n' % home_of(host),
        ),
    ] + [file("~/.claude-pulse/" + p, mode = "link", target = "~/.claude/" + p) for p in PULSE]
