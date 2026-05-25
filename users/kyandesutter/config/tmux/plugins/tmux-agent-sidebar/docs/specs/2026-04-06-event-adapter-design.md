# Event Adapter Design

## Goal

Decouple the hook event handler from agent-specific event names and JSON schemas. Each agent (Claude, Codex, future Gemini, etc.) gets an adapter that normalizes external events into a single internal `AgentEvent` enum. The core handler only operates on `AgentEvent` and never references agent names.

## Architecture

```
hook.sh  (agent_name, event_name, stdin JSON)
  ↓
cmd_hook(args)
  ↓  resolve adapter by agent name
adapter::claude::parse() / adapter::codex::parse()
  ↓  returns Option<AgentEvent>
handle_event(pane, event)   ← agent-agnostic
```

## Internal Event Enum

Defined in `src/event.rs`. All fields are extracted by the adapter — the handler never reads raw JSON.

```rust
pub enum AgentEvent {
    SessionStart {
        agent: String,          // agent type string for tmux meta
        cwd: String,
        permission_mode: String,
    },
    SessionEnd,
    UserPromptSubmit {
        agent: String,
        cwd: String,
        permission_mode: String,
        prompt: String,
    },
    Notification {
        agent: String,
        cwd: String,
        permission_mode: String,
        wait_reason: String,    // e.g. "permission", empty = generic
    },
    Stop {
        agent: String,
        cwd: String,
        permission_mode: String,
        last_message: String,
        response: Option<String>, // stdout response (Codex: {"continue":true})
    },
    StopFailure {
        agent: String,
        cwd: String,
        permission_mode: String,
        error: String,
    },
    SubagentStart {
        agent_type: String,
    },
    SubagentStop {
        agent_type: String,
    },
    ActivityLog {
        tool_name: String,
        tool_input: serde_json::Value,
        tool_response: serde_json::Value,
    },
}
```

### Design decisions

- `agent`, `cwd`, `permission_mode` are repeated in variants that call `set_agent_meta` today. This avoids a shared "meta" struct that would be unused by `SessionEnd`, `SubagentStart/Stop`, `ActivityLog`.
- `response: Option<String>` on `Stop` lets each adapter declare an stdout response. The handler prints it if `Some`. Claude sets `None`, Codex sets `Some("{\"continue\":true}")`.
- `SessionEnd` has no fields — it only needs the pane ID (passed separately).
- Adapter returns `Option<AgentEvent>` — `None` means "ignore this event" (e.g. `idle_prompt` notification, unknown event name).

## Adapter Trait

Defined in `src/event.rs`:

```rust
pub trait EventAdapter {
    fn parse(&self, event_name: &str, input: &serde_json::Value) -> Option<AgentEvent>;
}
```

Each adapter is a unit struct implementing this trait.

## Adapter Modules

```
src/
  event.rs          — AgentEvent enum + EventAdapter trait + resolve_adapter()
  adapter/
    mod.rs          — re-exports
    claude.rs       — ClaudeAdapter
    codex.rs        — CodexAdapter
```

### `resolve_adapter`

```rust
pub fn resolve_adapter(agent_name: &str) -> Option<Box<dyn EventAdapter>> {
    match agent_name {
        "claude" => Some(Box::new(adapter::claude::ClaudeAdapter)),
        "codex" => Some(Box::new(adapter::codex::CodexAdapter)),
        _ => None,
    }
}
```

Adding a new agent = adding a new file in `adapter/` and one match arm.

### Claude Adapter (`adapter/claude.rs`)

Maps 1:1 since our internal events are based on Claude's schema:

| External event | Internal event |
|---|---|
| `notification` | `Notification` (skip if `idle_prompt`) |
| `stop` | `Stop { response: None }` |
| `stop-failure` | `StopFailure` |
| `subagent-start` | `SubagentStart` |
| `subagent-stop` | `SubagentStop` |
| `user-prompt-submit` | `UserPromptSubmit` |
| `session-start` | `SessionStart` |
| `session-end` | `SessionEnd` |
| `activity-log` | `ActivityLog` |

### Codex Adapter (`adapter/codex.rs`)

| External event | Internal event |
|---|---|
| `stop` | `Stop { response: Some("{\"continue\":true}") }` |
| `user-prompt-submit` | `UserPromptSubmit` |
| `session-start` | `SessionStart` |
| `session-end` | `SessionEnd` |
| unknown | `None` (ignored) |

## Refactored `cmd_hook`

```rust
pub(crate) fn cmd_hook(args: &[String]) -> i32 {
    let agent_name = args.first().map(|s| s.as_str()).unwrap_or("");
    let event_name = args.get(1).map(|s| s.as_str()).unwrap_or("");

    let Some(adapter) = resolve_adapter(agent_name) else {
        return 0;
    };

    let pane = tmux_pane();
    if pane.is_empty() {
        return 0;
    }

    let input = read_stdin_json();
    let Some(event) = adapter.parse(event_name, &input) else {
        return 0;
    };

    handle_event(&pane, event)
}
```

`handle_event` contains the same logic as today's match arms, but matches on `AgentEvent` variants instead of string event names. No agent-specific branches exist in this function.

## File changes summary

| File | Action |
|---|---|
| `src/event.rs` | New — `AgentEvent`, `EventAdapter` trait, `resolve_adapter()` |
| `src/adapter/mod.rs` | New — re-exports |
| `src/adapter/claude.rs` | New — `ClaudeAdapter` |
| `src/adapter/codex.rs` | New — `CodexAdapter` |
| `src/cli/hook.rs` | Refactor — replace match-on-strings with adapter + `handle_event` |
| `src/main.rs` or `src/lib.rs` | Add `mod event; mod adapter;` |

## Event Mapping Reference

See [docs/event-mapping.md](../event-mapping.md) for the full mapping table.

## Testing strategy

- **Adapter unit tests**: Each adapter gets tests verifying event name → `AgentEvent` mapping, field extraction, and `None` for unknown events.
- **`handle_event` unit tests**: Test each `AgentEvent` variant in isolation (same assertions as existing `cmd_hook` tests, but via the new function).
- **Existing integration tests**: `cmd_hook` tests remain to verify end-to-end flow still works.
