/**
 * Mode Cycle Extension
 *
 * Cycles through three agent modes with Shift+Tab:
 *
 *   normal -> plan -> auto -> normal ...
 *
 * - normal : default behaviour. Tools available, edits/writes confirmed by pi's
 *            usual flow. (No auto-approval, no restrictions.)
 * - plan   : read-only exploration. edit/write disabled, bash restricted to a
 *            read-only allowlist. The model is told to produce a plan, not apply
 *            changes.
 * - auto   : full tool access AND destructive bash confirmations are
 *            auto-approved so the agent can run end-to-end without prompts.
 *
 * The active mode is shown in the footer and persists across /resume.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isSafeCommand } from "./utils.ts";

type Mode = "normal" | "plan" | "auto";

const ORDER: Mode[] = ["normal", "plan", "auto"];

// Read-only toolset used while in plan mode.
const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls"];
// Full toolset used in normal / auto mode. Adjust if you add custom tools you
// always want available.
const FULL_TOOLS = ["read", "bash", "edit", "write", "grep", "find", "ls"];

export default function modeCycleExtension(pi: ExtensionAPI): void {
	let mode: Mode = "normal";

	function applyTools(): void {
		if (mode === "plan") {
			pi.setActiveTools(PLAN_MODE_TOOLS);
		} else {
			pi.setActiveTools(FULL_TOOLS);
		}
	}

	function label(m: Mode): string {
		switch (m) {
			case "plan":
				return "⏸ plan";
			case "auto":
				return "⏩ auto";
			default:
				return "● normal";
		}
	}

	function color(m: Mode): "warning" | "accent" | "success" {
		switch (m) {
			case "plan":
				return "warning";
			case "auto":
				return "accent";
			default:
				return "success";
		}
	}

	function updateStatus(ctx: ExtensionContext): void {
		ctx.ui.setStatus("mode-cycle", ctx.ui.theme.fg(color(mode), label(mode)));
	}

	function persist(): void {
		pi.appendEntry("mode-cycle", { mode });
	}

	function setMode(next: Mode, ctx: ExtensionContext, notify = true): void {
		mode = next;
		applyTools();
		updateStatus(ctx);
		persist();
		if (notify) {
			ctx.ui.notify(`Mode: ${label(mode).replace(/^[^ ]+ /, "")}`, "info");
		}
	}

	function cycle(ctx: ExtensionContext): void {
		const idx = ORDER.indexOf(mode);
		setMode(ORDER[(idx + 1) % ORDER.length], ctx);
	}

	// --- Shift+Tab cycles the mode ----------------------------------------
	pi.registerShortcut("shift+tab", {
		description: "Cycle agent mode (normal → plan → auto)",
		handler: async (ctx) => cycle(ctx),
	});

	// --- /mode command + direct selectors ---------------------------------
	pi.registerCommand("mode", {
		description: "Cycle or set agent mode (normal | plan | auto)",
		getArgumentCompletions: (prefix) => {
			const items = ORDER.map((m) => ({ value: m, label: m }));
			const filtered = items.filter((i) => i.value.startsWith(prefix));
			return filtered.length > 0 ? filtered : null;
		},
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();
			if (arg === "" ) {
				cycle(ctx);
				return;
			}
			if ((ORDER as string[]).includes(arg)) {
				setMode(arg as Mode, ctx);
			} else {
				ctx.ui.notify(`Unknown mode '${arg}'. Use: ${ORDER.join(", ")}`, "error");
			}
		},
	});

	// --- Plan mode: restrict bash to read-only allowlist ------------------
	pi.on("tool_call", async (event) => {
		if (mode !== "plan" || event.toolName !== "bash") return;
		const command = event.input.command as string;
		if (!isSafeCommand(command)) {
			return {
				block: true,
				reason: `Plan mode: command blocked (not allowlisted). Switch mode with Shift+Tab first.\nCommand: ${command}`,
			};
		}
	});

	// --- Inject per-mode guidance for the model ---------------------------
	pi.on("before_agent_start", async () => {
		if (mode === "plan") {
			return {
				message: {
					customType: "mode-cycle-context",
					content: `[PLAN MODE ACTIVE]
You are in read-only plan mode. You can only use: read, bash, grep, find, ls.
You CANNOT edit or write files, and bash is restricted to read-only commands.
Investigate, then produce a clear numbered plan under a "Plan:" header.
Do NOT attempt to make changes — describe what you would do.`,
					display: false,
				},
			};
		}
		if (mode === "auto") {
			return {
				message: {
					customType: "mode-cycle-context",
					content: `[AUTO MODE ACTIVE]
Full tool access is enabled and confirmations are auto-approved.
Work end-to-end without asking for permission on each step. Still be careful
and avoid irreversible/destructive actions unless clearly required by the task.`,
					display: false,
				},
			};
		}
	});

	// --- Drop stale mode context when not in that mode --------------------
	pi.on("context", async (event) => {
		if (mode !== "normal") return;
		return {
			messages: event.messages.filter((m) => {
				const msg = m as { customType?: string };
				return msg.customType !== "mode-cycle-context";
			}),
		};
	});

	// --- Restore mode on session start / resume ---------------------------
	pi.on("session_start", async (_event, ctx) => {
		const entries = ctx.sessionManager.getEntries();
		const last = entries
			.filter((e: { type: string; customType?: string }) => e.type === "custom" && e.customType === "mode-cycle")
			.pop() as { data?: { mode?: Mode } } | undefined;
		if (last?.data?.mode && (ORDER as string[]).includes(last.data.mode)) {
			mode = last.data.mode;
		}
		applyTools();
		updateStatus(ctx);
	});
}
