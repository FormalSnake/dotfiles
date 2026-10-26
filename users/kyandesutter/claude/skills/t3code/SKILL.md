---
name: t3code
description: "Use the T3 Code host to its full extent when running inside it: the Device panel (iOS Simulators, Android emulators and physical devices driven through agent-device), the collaborative browser preview, inline HTML renders, delegated subagents on any provider, top-level threads bound to worktrees, thread fork/merge-back, message queue and steering, PR watching, scheduled and webhook tasks, and secrets. Load it whenever the mcp__t3-code__* tools are present and the work touches a simulator or device, a web page or dev server, a chart or mockup, parallel or cross-model agents, worktrees, PRs, or recurring work. Inside T3 it replaces serve-sim, playwriter and ad-hoc background watchers."
---

# T3 Code

T3 Code is the app hosting this agent. It exposes its features as MCP tools named `mcp__t3-code__*` (the harness may add a prefix). If those tools are absent from the catalog, run one ToolSearch for `t3-code` before concluding you are not inside T3; servers attach lazily. Most tool schemas are deferred: load them with `ToolSearch select:<name>,<name>` before the first call.

The `t3` binary on PATH is the server launcher (`t3 serve`, `t3 service`, `t3 update`, `t3 doctor`). It is not the control surface for this session; use the MCP tools.

Orient with:

- `t3_environment_read`: environment id, label, server version, preferences.
- `orchestrator_capabilities`: providers, models and inherited options for delegation. Pass `search` for models not in the short list.
- `t3_worktree_status`: whether this thread is bound to a worktree, and which.

## Devices: simulators, emulators and phones

T3 has device streaming built in. Prefer it to `serve-sim` and raw `simctl`/`adb` screenshots: the user watches the device live in the thread's Device panel while you drive it.

1. `device_list` lists every iOS Simulator, Android emulator and attached physical Android device on each host, with `booted` and which are already open in this thread.
2. `device_open {deviceId, hostId}` boots the device if needed, starts the stream and opens the panel. It returns `agentDevice.command` and `agentDevice.targetArgs`. If it fails with "Could not communicate with device support", call it once more: the first call installs the device tooling.
3. Drive the device with the returned executable and every one of the returned flags (`--platform`, `--serial` or udid, `--config`, `--session`) on every command. Use the absolute path; login shells reset PATH.
4. `device_screenshot` shows you what the user sees. Use it for looking, the CLI for acting.
5. `device_close {deviceId, hostId}` removes it from the panel when done. `shutdown: true` also powers it off; only do that for a device you booted.

agent-device loop, from its own help:

```bash
AD=<agentDevice.command>; ARGS="<targetArgs joined>"
$AD open <bundle-or-package-id> --foreground $ARGS   # returns a snapshot with @eN refs
$AD click @e3 --settle $ARGS                          # acts, waits, prints the UI diff
$AD fill @e5 "text" --settle $ARGS
$AD wait text "Expected" $ARGS
$AD install <app> <path-to-.app-or-.apk> $ARGS
$AD close $ARGS
```

Rules: prefer refs, then selectors, coordinates last. Refs go stale after any mutation; continue from the diff that `--settle` prints. A screenshot is not verification; use `wait text`, `is`, `get` or `find`. Run `$AD help <topic>` (`workflow`, `react-native`, `react-devtools`, `foldable`, `physical-device`, `debugging`) before guessing a flag. Builds, installs and Metro port forwarding are still yours; T3 only streams and controls.

## Browser preview

A collaborative Chromium tab shown inline in the thread. Use it for dev servers, deployed sites and visual checks instead of playwriter or a screenshot script.

- `preview_open {url}` opens or reuses this session's tab and returns `tabId`. `open: false` keeps it in the background. Parallel subagents each pass `reuseExistingTab: false` and their own `tabId` on every call. `profileId` picks a saved browser profile (`preview_status` lists them; `incognito` exists).
- `preview_snapshot` returns page state, an accessibility tree with refs, console diagnostics and action history. Target elements with `locator: "aria-ref=<ref>"`. `includeImage: true` only when you need to see it; `save: true` writes a PNG and returns `screenshotPath`, which is the only way to show the user a screenshot (embed it as `![alt](path)`).
- Act with `preview_click`, `preview_type`, `preview_press`, `preview_select`, `preview_hover`, `preview_drag`, `preview_scroll`, `preview_upload`, `preview_dialog`; wait with `preview_wait_for` (locator, text or URL), never sleep.
- `preview_resize` with `mode: "preset"` (`iphone-14-pro-max`, `pixel-7`, `ipad-pro`, ...) or `freeform` checks breakpoints. `preview_set_appearance` flips light/dark without touching the OS.
- `preview_recording_start` / `preview_recording_stop` produce a video file as evidence of a flow.
- `preview_evaluate` runs JS in the page. It needs control: if the user is driving the tab, read it with `preview_snapshot` instead.
- `t3_preview_list` / `t3_preview_close {tabId}` manage the thread's tabs. Close the ones you opened when finished.

The user can take control of a tab at any time. After a control handoff or navigation, take a fresh snapshot; old refs are invalid.

## Showing results inline

For a chart, table, diagram, collage or mockup, write one self-contained HTML document, check it with `html_preview` (returns a PNG, `contentHeight` and console output; `width: 390` for phones, `appearance: "light"` for light mode), then publish with `html_render {html, title, height: contentHeight}` before the final reply. Leave `html`/`body` backgrounds unset, use T3's injected CSS variables (`--foreground`, `--muted-foreground`, `--border`, `--chart-1`..`--chart-6`, `--radius`, `--font-sans`, `--font-mono`), give charts fixed pixel heights, and never use `vh` units. The reply that follows adds only what the page does not say. Load `dataviz` first for any chart.

## Delegation and threads

Three different things; pick the right one.

| Need | Tool |
| --- | --- |
| Child work owned by this thread, any provider or model | `delegate_task` (track `taskId` with `task_status`, `task_cancel`) |
| Child work in its own checkout | `delegate_task` with `isolation: "worktree"` (starts from the parent's local commit; uncommitted edits do not come along) |
| A new top-level conversation the user asked for | `t3_thread_launch` with an explicit `workspaceStrategy` and the task in `message` |
| Several top-level threads sharing this checkout | `create_threads` |

- Same-provider, same-model work with no options can use the native Agent tool. Anything cross-provider, with model options (`effort`, `fastMode`, Codex `reasoningEffort`), or needing T3 to own it goes through `delegate_task` with `target: {providerInstanceId, model, options}` from `orchestrator_capabilities`. Check the returned selection matches what you asked for.
- Every review round is a fresh `delegate_task` with the full brief, prior findings and objections, and a distinct `clientRequestId` (stable across retries of that round). Do not `t3_thread_send` to a `childThreadId` to start a new round.
- `t3_thread_launch` workspace strategies: `{"type":"worktree","baseRef":"main","branch":"feat/x","startFromOrigin":false}`, `{"type":"existing_worktree","worktreePath":"...","branch":"..."}`, or `{"type":"root"}`. Omitting it means root, not the caller's worktree. It has no idempotency key: if a launch errors or the response is lost, check `t3_thread_list` before retrying.
- Monitor threads with `t3_thread_read` (`view: "activity"` for tool calls and workflows), `t3_thread_wait` (a timeout does not interrupt; call again), `t3_thread_search`.
- Talk to a thread with `t3_thread_send`: `mode` is `auto`, `queue` (next turn), `steer` (into the running turn) or `restart`. `t3_queue_list`, `t3_queue_edit`, `t3_queue_reorder`, `t3_queue_cancel` and `t3_queue_promote_to_steer` manage what is queued. `t3_thread_interrupt` stops a turn.
- `t3_thread_fork {sourcePoint: {type: "latest_stable"}}` branches a conversation to try an alternative; `t3_thread_merge_back {targetThreadId, sourcePoint}` brings the result back. `t3_thread_transfers` shows transfer status.
- `t3_thread_configure` switches a thread's model. `t3_thread_organize` pins, snoozes, settles or archives. `t3_pending_request_list` / `t3_pending_request_respond` answer another thread's question (not permission prompts).
- Link a thread for the user as `[title](t3-thread://v1/<threadId>)`, id verbatim.
- Files to another thread: `t3_attachment_prepare_upload`, POST the bytes to the returned URL, then `t3_thread_send_attachments`.

## Worktrees

`t3_worktree_status` first. `t3_worktree_handoff {branch, baseRef, continuationPrompt}` moves this thread into a new worktree and runs the project setup script; it ends the current turn, so make it the last call and put the remaining work in `continuationPrompt`. `t3_worktree_list` shows branches and their checkout paths. Running `git worktree add` or `cd` yourself does not rebind the thread. The user's worktree rules (last resort, clean up after) still apply; T3 does not remove a worktree when its thread is deleted.

## Pull requests

- Register every PR you create or work on with `link_pull_request {url}`, every layer of a stack. Before finishing, `list_thread_pull_requests` and link anything missing.
- To babysit a PR, `watch_pull_request`, handle existing comments, then end the turn. T3 wakes the thread on failed or passing checks, new comments or reviews, and conflicts. Never poll or sleep. `unwatch_pull_request` before handing back to the user. Subagents cannot watch.
- `write_pull_request_guides` writes a reviewer tour into a PR's Guide tab; `read_pull_request_guide` reads it back.

## Scheduled and webhook work

`schedule_task` with a structured `schedule` object (not JSON text): `{"type":"interval","everyMs":3600000}`, `{"type":"fixed_time","timeOfDay":"09:00","weekdays":[1,2,3,4,5]}`, or `{"type":"webhook"}` (the run reads the request only through `{{body.path}}` placeholders in the prompt). Runs return to this thread unless `bindToCurrentThread: false`. Report the cadence and next run, or the `webhookUrl`. Manage with `list_scheduled_tasks`, `update_scheduled_task`, `run_scheduled_task_now`, `delete_scheduled_task`.

## Secrets and projects

- Need a token from the user: `request_secret`, then pass the returned single-use `secretRef` (for example `signature.secretRef` on a webhook task). Never ask for a secret in chat.
- `t3_project_list` / `t3_project_read` / `t3_project_create` / `t3_project_clone` / `t3_project_update` manage the app's projects. `t3_project_delete` is destructive: confirm first.

## Safety

- Do not close preview tabs, devices, threads or worktrees you did not open unless the user asked.
- Do not shut down a device that was already booted when you arrived.
- Do not archive, delete or interrupt another thread's work without the user naming it.
- Delegated children get the user's uncommitted-work rules pasted into their brief whenever they can reach a git tree.
