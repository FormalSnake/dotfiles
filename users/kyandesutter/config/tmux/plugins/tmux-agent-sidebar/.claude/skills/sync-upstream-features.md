---
name: sync-upstream-features
description: Claude Code / Codex CLI の最新 hook イベントや機能が、tmux-agent-sidebar の現在の実装でカバーされているか調査し、ギャップをレポートする。「upstream との差分を確認して」「新しい hook が追加されてないか調べて」「チェンジログを確認して未対応を洗い出して」といったリクエストで使う。実装はしない。
---

# Sync Upstream Features — Gap Reporter

Claude Code と Codex CLI の最新ドキュメント・チェンジログを取得し、このプロジェクトの実装との差分をレポートするスキル。実装は行わず、ギャップの一覧を出力する。

## このプロジェクトの仕組み

レポート前に、このプロジェクト固有のアーキテクチャを理解しておく必要がある。

### Hook イベントの受信方式

このプロジェクトは Claude Code / Codex の **settings.json hooks** を利用してイベントを受信する。`hook.sh` が stdin から JSON を受け取り、Rust バイナリの `hook` サブコマンドに渡す。

上流の hook イベントと、このプロジェクトで使っている内部イベント名の対応：

| 上流 hook イベント | 内部イベント名 | 備考 |
|-------------------|--------------|------|
| `SessionStart` | `session-start` | |
| `SessionEnd` | `session-end` | |
| `UserPromptSubmit` | `user-prompt-submit` | |
| `Notification` | `notification` | |
| `Stop` | `stop` | |
| `StopFailure` | `stop-failure` | |
| `SubagentStart` | `subagent-start` | |
| `SubagentStop` | `subagent-stop` | |
| `PostToolUse` | `activity-log` | **重要**: `PreToolUse`/`PostToolUse` は直接使わない。代わりに独自の `activity-log` イベントとして `PostToolUse` hook から `tool_name`, `tool_input`, `tool_response` を渡している |

### レポート対象外にすべきもの

以下は sidebar の監視 TUI には関係ないため、ギャップとして報告しない：

- **`PreToolUse` / `PostToolUse` / `PostToolUseFailure`**: `activity-log` で代替済み。これらを直接ハンドルする必要はない
- **`PermissionRequest`**: パーミッション UI の制御用。sidebar は表示するだけなので不要
- **`PreCompact` / `PostCompact`**: コンパクションは sidebar に影響しない
- **`InstructionsLoaded`**: CLAUDE.md の読み込みは sidebar に関係ない
- **`ConfigChange`**: 設定変更の監視は sidebar のスコープ外
- **`FileChanged`**: ファイル変更監視は sidebar のスコープ外
- **`Elicitation` / `ElicitationResult`**: MCP elicitation は sidebar のスコープ外
- **`session_id`**, **`transcript_path`** フィールド: sidebar で使わない情報

**注意**: `WorktreeCreate` / `WorktreeRemove` は除外しないこと。sidebar は worktree 情報を表示するため、これらのイベントは監視に有用。

### レポートすべきもの

sidebar のエージェント監視に関係するギャップのみ報告する：

- **新しいステータス変化を起こすイベント**: エージェントの状態（running/waiting/idle/error）に影響するもの
- **パーミッションモード**: `PermissionMode` enum に欠けているバリアント
- **Notification タイプ**: 新しい通知種別で、ステータス表示に影響するもの
- **ツール追跡**: `activity.rs` のカラーマッピングや `label.rs` のラベル抽出に不足があるもの
- **Codex adapter**: Codex CLI で新しくサポートされたイベント（ただし Codex 側が実際にそのイベントを送信していることが確認できる場合のみ）
- **JSON フィールド**: 既に対応済みイベントで、sidebar の表示改善に直結するフィールドの読み落とし
- **新しい hook イベント**: エージェントのライフサイクルや状態追跡に関わるもの（例: `TaskCreated`, `TaskCompleted`, `PermissionDenied`, `TeammateIdle`）

## 手順

### 1. 上流のドキュメントを取得

以下の URL から最新情報を取得する：

| ソース | URL | 注目ポイント |
|--------|-----|-------------|
| Claude Code Changelog | `https://code.claude.com/docs/en/changelog` | 新しい hook イベント、パーミッションモード、ツール |
| Claude Code Hooks Reference | `https://code.claude.com/docs/en/hooks` | 各 hook イベントの JSON スキーマ |
| Codex CLI Features | `https://developers.openai.com/codex/cli/features` | 実行モード、フラグ |
| Codex Releases | `https://github.com/openai/codex/releases` | 新機能、新イベント |

### 2. 現在の実装を読み取る

以下のファイルから、対応済みの機能を把握する：

| 確認項目 | ファイル | 見るべき箇所 |
|---------|---------|-------------|
| 対応済み hook イベント | `src/adapter/claude.rs` | `parse()` の match アーム |
| Codex 対応イベント | `src/adapter/codex.rs` | `parse()` の match アーム |
| 内部イベント定義 | `src/event.rs` | `AgentEvent` enum のバリアント |
| パーミッションモード | `src/tmux.rs` | `PermissionMode` enum と `from_str()` |
| 追跡中ツール | `src/activity.rs` | `tool_color_index()` の match アーム |
| ラベル対応ツール | `src/cli/label.rs` | `extract_tool_label()` の match アーム |
| イベントハンドラ | `src/cli/hook.rs` | `handle_event()` の match アーム |

### 3. 差分をレポート

「レポートすべきもの」に該当するギャップのみ、以下のカテゴリで報告する。「レポート対象外にすべきもの」に該当する項目は含めない。

#### カテゴリ

- **Hook イベント**: 上流にあって adapter にない、sidebar の監視に有用なイベント
- **パーミッションモード**: `PermissionMode` enum に欠けているバリアント
- **Notification タイプ**: 新しい通知種別
- **JSON フィールド**: 対応済みイベントで、表示改善に使えるフィールドの読み落とし
- **ツール**: `activity.rs` / `label.rs` で未対応のツール
- **Codex 固有**: Codex adapter の不足（実際にイベントが送信されると確認できるもののみ）

### 4. 優先度付け

各ギャップに優先度を付ける：

- **High**: ステータス表示が間違う・情報が欠落する（例: パーミッションモードの欠落、エラー種別の読み落とし）
- **Medium**: 表示は正しいが追加情報があれば改善できる（例: 新しい hook イベント対応、新ツールの色）
- **Low**: あれば良いが影響が小さい（例: ラベル抽出の追加、まだ普及していない機能）

### 5. 出力フォーマット

レポートは以下の構成で出力する。

#### 5.1 対応状況テーブル

まず、上流の全 hook イベントと、現在の対応状況を一覧テーブルで出力する。「レポート対象外」のイベントも含め、上流に存在する全イベントを網羅すること。

フォーマット：

| Hook イベント | 追加バージョン | 対応状況 | 備考 |
|--------------|--------------|---------|------|
| `SessionStart` | (初期) | 対応済み | |
| `TaskCreated` | v2.1.84 | 未対応 | ... |
| `PreToolUse` | (初期) | 対象外 | activity-log で代替 |

- **追加バージョン**: そのイベントが Claude Code に追加されたバージョン。changelog から特定する。初期から存在するものは `(初期)` と書く。特定できない場合は `不明` と書く。
- **対応状況**: `対応済み` / `未対応` / `部分対応` / `対象外`
  - `対応済み`: adapter の `parse()` に match アームが存在する
  - `未対応`: adapter に match アームがなく、sidebar の監視に有用なイベント
  - `部分対応`: match アームはあるが、フィールドの読み落としやフィールド名ずれがある
  - `対象外`: sidebar の監視に関係ないためハンドル不要（「レポート対象外にすべきもの」に該当）

同様に、以下のテーブルも出力する：

**パーミッションモード:**

| モード | 対応状況 | 備考 |
|--------|---------|------|
| `default` | 対応済み | |
| `dontAsk` | 未対応 | Default にフォールバック |

**ツール（カラーマッピング + ラベル抽出）:**

未対応・部分対応のツールのみ表示する。

| ツール | 追加バージョン | カラー | ラベル | 備考 |
|--------|--------------|--------|--------|------|
| `PowerShell` | v2.1.84 | 未対応 | 未対応 | Windows 用 |
| `TaskList` | (初期) | 対応済み | 未対応 | |

#### 5.2 ギャップ詳細

対応状況テーブルで `未対応` / `部分対応` のもの（`対象外` を除く）について、優先度別に詳細を出力する。

各ギャップには以下を含める：
- **項目名**
- **追加バージョン**
- **上流の仕様**: 簡潔な説明
- **現在の状態**
- **影響ファイル**

#### 5.3 サマリー

対応状況テーブルの正確性に関するルール：

1. **adapter の match アームを列挙してから書く**: テーブルを書く前に、`src/adapter/claude.rs` の `parse()` にある match アームの文字列リテラル（`"session-start"`, `"session-end"` 等）を全て列挙すること。この列挙にないイベントを「対応済み」にしてはならない。
2. **テーブル間の整合性チェック**: 対応状況テーブルとギャップ詳細の間で矛盾がないか確認すること。
3. **全カテゴリの漏れチェック**: パーミッションモードやツールのギャップが漏れていないか確認すること。
