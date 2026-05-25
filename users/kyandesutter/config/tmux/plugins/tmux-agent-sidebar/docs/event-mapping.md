# Event Mapping Reference

## Internal Events → External Event Names

| Internal Event | Claude Code | Codex | JSON fields used |
|---|---|---|---|
| `SessionStart` | `session-start` | `session-start` | `cwd`, `permission_mode` |
| `SessionEnd` | `session-end` | `session-end` | _(none)_ |
| `UserPromptSubmit` | `user-prompt-submit` | `user-prompt-submit` | `cwd`, `permission_mode`, `prompt` |
| `Notification` | `notification` | _(not supported)_ | `cwd`, `permission_mode`, `notification_type` |
| `Stop` | `stop` | `stop` | `cwd`, `permission_mode`, `last_assistant_message` |
| `StopFailure` | `stop-failure` | _(not supported)_ | `cwd`, `permission_mode`, `error`, `error_details` |
| `SubagentStart` | `subagent-start` | _(not supported)_ | `agent_type` |
| `SubagentStop` | `subagent-stop` | _(not supported)_ | `agent_type` |
| `ActivityLog` | `activity-log` | _(not supported)_ | `tool_name`, `tool_input`, `tool_response` |

## Per-Agent Support Matrix

| Internal Event | Claude Code | Codex | Notes |
|---|---|---|---|
| `SessionStart` | Yes | Yes | |
| `SessionEnd` | Yes | Yes | |
| `UserPromptSubmit` | Yes | Yes | |
| `Notification` | Yes | No | Codex has no notification hook |
| `Stop` | Yes | Yes | Codex returns `{"continue":true}` via `response` |
| `StopFailure` | Yes | No | |
| `SubagentStart` | Yes | No | |
| `SubagentStop` | Yes | No | |
| `ActivityLog` | Yes | No | Codex has no PostToolUse hook |

## Adapter-Specific Behaviors

| Behavior | Claude | Codex |
|---|---|---|
| `notification` with `idle_prompt` | Ignored (`None`) | N/A |
| `stop` response to stdout | None | `{"continue":true}` |
| Unknown event names | Ignored (`None`) | Ignored (`None`) |
