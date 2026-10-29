# Claude Code settings for every host. claude.star adds the platform's SHELL.

SETTINGS = {
    "$schema": "https://json.schemastore.org/claude-code-settings.json",
    "agentPushNotifEnabled": True,
    "alwaysThinkingEnabled": True,
    "autoCompactWindow": 400000,
    "awaySummaryEnabled": False,
    "effortLevel": "high",
    "enabledPlugins": {
        "accessibility-expert@claude-code-marketplace": False,
        "ai-engineer@claude-code-marketplace": False,
        "api-integration-specialist@claude-code-marketplace": False,
        "api-tester@claude-code-marketplace": False,
        "app-store-optimizer@claude-code-marketplace": False,
        "audit@claude-code-marketplace": False,
        "backend-architect@claude-code-marketplace": False,
        "brand-guardian@claude-code-marketplace": False,
        "bug-detective@claude-code-marketplace": False,
        "bug-fix@claude-code-marketplace": False,
        "canarycoders@canarycoders-skills": True,
        "clangd-lsp@claude-plugins-official": True,
        "claude-code-setup@claude-plugins-official": False,
        "claude-md-management@claude-plugins-official": False,
        "code-review@claude-plugins-official": False,
        "code-simplifier@claude-plugins-official": False,
        "codebase-documenter@claude-code-marketplace": False,
        "context7@claude-plugins-official": False,
        "desktop-notifications@claude-plugin-desktop-notifications": True,
        "expo@expo-plugins": True,
        "feature-dev@claude-plugins-official": False,
        "frontend-design@claude-plugins-official": False,
        "playwright@claude-plugins-official": True,
        "pr-review-toolkit@claude-plugins-official": False,
        "ralph-loop@claude-plugins-official": True,
        "security-guidance@claude-plugins-official": True,
        "skill-creator@claude-plugins-official": False,
        "superpowers@claude-plugins-official": False,
        "swift-lsp@claude-plugins-official": True,
        "tmux-agent-notifications@claude-plugin-tmux-notifications": True,
        "typescript-lsp@claude-plugins-official": True,
        "cloudflare@cloudflare": True,
    },
    "env": {},
    "extraKnownMarketplaces": {
        "canarycoders-skills": {
            "source": {
                "repo": "CanaryCoders/skills",
                "source": "github",
            },
        },
        "expo-plugins": {
            "source": {
                "repo": "expo/skills",
                "source": "github",
            },
        },
        "cloudflare": {
            "source": {
                "repo": "cloudflare/skills",
                "source": "github",
            },
        },
    },
    "feedbackSurveyState": {
        "lastShownTime": 1754320637645,
    },
    "hooks": {
        "Notification": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude notification || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
        "PostToolUse": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude tool_use || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
        "PreToolUse": [
            {
                "hooks": [
                    {
                        "command": "sh ~/.claude/hooks/no-em-dash.sh",
                        "timeout": 10,
                        "type": "command",
                    },
                ],
                "matcher": "Write|Edit|NotebookEdit",
            },
            {
                "hooks": [
                    {
                        "command": "sh ~/.claude/hooks/no-ai-attribution.sh",
                        "timeout": 10,
                        "type": "command",
                    },
                ],
                "matcher": "Bash",
            },
        ],
        "SessionEnd": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude session_end || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
        "SessionStart": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude session_start || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
        "Stop": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude stop || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
        "SubagentStop": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude stop || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
        "UserPromptSubmit": [
            {
                "hooks": [
                    {
                        "command": "[ -f ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh ] && bash ~/.config/tmux/plugins/tmux-agent-sidebar/hook.sh claude prompt_submit || true",
                        "type": "command",
                    },
                ],
                "matcher": "",
            },
        ],
    },
    "model": "opus",
    "permissions": {
        "defaultMode": "bypassPermissions",
        "deny": [
            "Bash(git config user.*)",
            "Bash(git config --global user.*)",
            "Bash(git config --local user.*)",
            "Bash(git config --system user.*)",
            "Bash(git config --worktree user.*)",
            "Bash(git config * user.*)",
            "Bash(git config set user.*)",
            "Bash(git config unset user.*)",
            "Bash(git -c user.*)",
            "Bash(git commit *--author*)",
            "Bash(git rebase *--author*)",
            "Bash(GIT_AUTHOR_NAME=*)",
            "Bash(GIT_AUTHOR_EMAIL=*)",
            "Bash(GIT_COMMITTER_NAME=*)",
            "Bash(GIT_COMMITTER_EMAIL=*)",
            "Bash(export GIT_AUTHOR_*)",
            "Bash(export GIT_COMMITTER_*)",
            "Bash(env GIT_AUTHOR_*)",
            "Bash(env GIT_COMMITTER_*)",
            "Bash(gh auth login*)",
            "Bash(gh auth switch*)",
            "Bash(gh auth logout*)",
        ],
    },
    "skipAutoPermissionPrompt": True,
    "skipDangerousModePermissionPrompt": True,
    "spinnerVerbs": {
        "mode": "append",
        "verbs": ["Gooning", "Jorking it"],
    },
    "tui": "fullscreen",
    "statusLine": {
        "type": "command",
        "command": "sh \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/statusline-usage.sh\"",
    },
}
