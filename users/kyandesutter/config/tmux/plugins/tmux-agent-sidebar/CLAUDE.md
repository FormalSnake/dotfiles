# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A tmux sidebar TUI (built with Ratatui + Crossterm) that monitors AI coding agents (Claude Code, Codex) across all tmux sessions/windows/panes in real-time. Distributed as a single binary via tmux plugin managers.

## Build & Development Commands

```bash
cargo build                    # Debug build
cargo build --release          # Release build (strip + lto enabled)
cargo test                     # Run all tests
cargo test <test_name>         # Run a single test
cargo clippy                   # Lint
cargo fmt                      # Format code
cargo fmt --check              # Check formatting (used in CI)
```

CI runs `cargo test`, `cargo clippy`, and `cargo fmt --check` on every push/PR.

## Architecture

### Entry Points

The binary has two modes controlled by CLI args (`src/cli/mod.rs`):
1. **TUI mode** (`src/main.rs`) — default, renders the sidebar UI
2. **CLI subcommands** — `hook`, `toggle`, `auto-close`, `set-status`, `--version`

### Core Data Flow

```
Agent hooks (hook.sh) → CLI `hook` subcommand → writes to /tmp/tmux-agent-sidebar-*
                                                        ↓
TUI event loop (main.rs) → AppState::sync_global_state() → reads tmux panes + /tmp files
                                                        ↓
                                            ui::draw() renders frame
```

### Key Modules

- **`state.rs`** — `AppState` central struct: sessions, repo groups, filters, scroll positions, focus management. All UI is computed from this state.
- **`tmux.rs`** — Tmux integration: queries all panes via single `list-panes -a` call, defines `PaneInfo`/`PaneStatus`/`AgentType`/`PermissionMode`.
- **`cli/hook.rs`** — Receives real-time status updates from agent hooks, writes state to `/tmp/` files for the TUI to read.
- **`git.rs`** — Git operations (branch, ahead/behind, PR numbers via `gh` CLI, diff stats). Runs in a background polling thread.
- **`activity.rs`** — Parses `/tmp/tmux-agent-activity*.log` files, maps tool types to colors.
- **`group.rs`** — Groups panes by repository path.
- **`ui/`** — Rendering layer: `agents.rs` (agent list), `bottom.rs` (activity/git tabs), `colors.rs` (256-color theme), `text.rs` (text formatting/truncation).

### State Management

- `Focus` enum: Filter, Agents, ActivityLog — controls keyboard input routing
- `AgentFilter`: All, Running, Waiting, Idle, Error
- `BottomTab`: Activity, GitStatus
- SIGUSR1 signal triggers instant refresh on tmux pane focus change

### Testing

Tests are in `/tests/` using Ratatui's `TestBackend` for UI rendering assertions. `test_helpers.rs` provides buffer-to-string conversion utilities. Heavy use of snapshot-style tests for UI regression prevention.

## Debugging (Local tmux Plugin)

ローカルでデバッグするには、release ビルド後にビルド成果物を tmux plugin ディレクトリへコピーし、サイドバーを再起動する。

```bash
cargo build --release
cp target/release/tmux-agent-sidebar ~/.tmux/plugins/tmux-agent-sidebar/target/release/tmux-agent-sidebar
# サイドバーを再起動（tmux のキーバインドで toggle off → on）
```

**worktree で作業する場合**: worktree 内でビルドすると成果物は worktree 側の `target/release/` に出力される。コピー先は同じ。

```bash
cp <worktree-path>/target/release/tmux-agent-sidebar ~/.tmux/plugins/tmux-agent-sidebar/target/release/tmux-agent-sidebar
```

## Rust Edition

This project uses Rust edition 2024 (`Cargo.toml`).
