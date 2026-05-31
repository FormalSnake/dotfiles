/**
 * MCP Bridge Extension
 *
 * Reads MCP server definitions from your Claude Code config and exposes every
 * MCP tool to pi as a native tool, named `mcp__<server>__<tool>`.
 *
 * Server sources (merged, later overrides earlier):
 *   1. ~/.claude.json                ("mcpServers")
 *   2. ~/.claude/settings.json       ("mcpServers")
 *   3. ~/.pi/agent/mcp.json          ("mcpServers")  — pi-specific overrides
 *   4. ./.mcp.json                   ("mcpServers")  — project-local
 *
 * Each entry: { command, args?, env?, cwd? } for stdio servers, or
 *             { url, headers? } / { type: "sse"|"http", url } for remote servers.
 *
 * Servers connect lazily on first tool use, then stay connected for the session.
 */

import { homedir } from "node:os";
import { join } from "node:path";
import { readFileSync, existsSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";

type StdioServer = {
	command: string;
	args?: string[];
	env?: Record<string, string>;
	cwd?: string;
};
type RemoteServer = {
	type?: "sse" | "http" | "streamable-http";
	url: string;
	headers?: Record<string, string>;
};
type ServerConfig = StdioServer | RemoteServer;

function isRemote(cfg: ServerConfig): cfg is RemoteServer {
	return typeof (cfg as RemoteServer).url === "string";
}

function readJson(path: string): any | undefined {
	try {
		if (!existsSync(path)) return undefined;
		return JSON.parse(readFileSync(path, "utf8"));
	} catch {
		return undefined;
	}
}

function loadServers(cwd: string): Record<string, ServerConfig> {
	const home = homedir();
	const sources = [
		join(home, ".claude.json"),
		join(home, ".claude", "settings.json"),
		join(home, ".pi", "agent", "mcp.json"),
		join(cwd, ".mcp.json"),
	];
	const merged: Record<string, ServerConfig> = {};
	for (const src of sources) {
		const data = readJson(src);
		const servers = data?.mcpServers;
		if (servers && typeof servers === "object") {
			for (const [name, cfg] of Object.entries(servers)) {
				merged[name] = cfg as ServerConfig;
			}
		}
	}
	return merged;
}

// Sanitise a server/tool name into something safe for a tool id.
function safe(name: string): string {
	return name.replace(/[^a-zA-Z0-9_]/g, "_");
}

export default async function mcpBridge(pi: ExtensionAPI): Promise<void> {
	const cwd = process.cwd();
	const servers = loadServers(cwd);
	const names = Object.keys(servers);

	if (names.length === 0) return;

	// Lazy connection cache: server name -> connected Client (or pending promise).
	const clients = new Map<string, Promise<Client>>();

	function connect(serverName: string): Promise<Client> {
		let existing = clients.get(serverName);
		if (existing) return existing;

		const cfg = servers[serverName];
		const client = new Client({ name: `pi-mcp-bridge/${serverName}`, version: "1.0.0" });

		const transport = isRemote(cfg)
			? cfg.type === "sse"
				? new SSEClientTransport(new URL(cfg.url), {
						requestInit: { headers: cfg.headers },
				  })
				: new StreamableHTTPClientTransport(new URL(cfg.url), {
						requestInit: { headers: cfg.headers },
				  })
			: new StdioClientTransport({
					command: (cfg as StdioServer).command,
					args: (cfg as StdioServer).args ?? [],
					env: { ...process.env, ...((cfg as StdioServer).env ?? {}) } as Record<string, string>,
					cwd: (cfg as StdioServer).cwd,
			  });

		const p = client.connect(transport).then(() => client);
		clients.set(serverName, p);
		p.catch(() => clients.delete(serverName)); // allow retry on failure
		return p;
	}

	let registered = 0;

	// Discover tools from every server up front so the LLM sees them, but keep
	// connections only as long as needed for discovery is not required — we keep
	// them open for reuse during the session.
	for (const serverName of names) {
		try {
			const client = await connect(serverName);
			const { tools } = await client.listTools();

			for (const tool of tools) {
				const toolId = `mcp__${safe(serverName)}__${safe(tool.name)}`;

				pi.registerTool({
					name: toolId,
					label: `${serverName}: ${tool.name}`,
					description: tool.description ?? `MCP tool ${tool.name} from ${serverName}`,
					// Pass the MCP JSON schema straight through. typebox's Type.Unsafe
					// lets us hand pi a raw JSON schema object.
					parameters: Type.Unsafe<Record<string, unknown>>(
						tool.inputSchema ?? { type: "object", properties: {} },
					),
					async execute(_toolCallId, params, signal) {
						const c = await connect(serverName);
						const result = await c.callTool(
							{ name: tool.name, arguments: (params ?? {}) as Record<string, unknown> },
							undefined,
							{ signal },
						);

						const content = Array.isArray(result.content) ? result.content : [];
						const textParts = content
							.filter((c: any) => c.type === "text")
							.map((c: any) => c.text)
							.join("\n");

						return {
							content: textParts
								? [{ type: "text", text: textParts }]
								: [{ type: "text", text: JSON.stringify(result.content ?? result, null, 2) }],
							details: { server: serverName, tool: tool.name, raw: result },
							isError: Boolean(result.isError),
						};
					},
				});
				registered++;
			}
		} catch (err) {
			// A failing server should not take down the whole extension.
			pi.on("session_start", async (_e, ctx) => {
				ctx.ui.notify(`MCP: failed to load '${serverName}': ${(err as Error).message}`, "error");
			});
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		if (registered > 0) {
			ctx.ui.setStatus("mcp-bridge", ctx.ui.theme.fg("muted", `mcp:${registered}`));
		}
	});

	pi.on("session_shutdown", async () => {
		for (const p of clients.values()) {
			try {
				const c = await p;
				await c.close();
			} catch {
				/* ignore */
			}
		}
		clients.clear();
	});
}
