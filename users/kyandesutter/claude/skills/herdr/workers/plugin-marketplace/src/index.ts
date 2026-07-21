const SNAPSHOT_KEY = "plugins/index.json";
const SNAPSHOT_CACHE_CONTROL = "public, max-age=300, s-maxage=1800, stale-while-revalidate=3600";
const GITHUB_QUERY = "topic:herdr-plugin is:public";
const GITHUB_API_VERSION = "2022-11-28";
const GITHUB_SEARCH_URL = "https://api.github.com/search/repositories";
const BLACKLIST_REPO_KEY_PREFIX = "repo:";
const PER_PAGE = 100;
const MAX_REPOS = 1000;
const REQUEST_TIMEOUT_MS = 10_000;

type R2Bucket = {
  put(
    key: string,
    value: string,
    options?: {
      httpMetadata?: {
        contentType?: string;
        cacheControl?: string;
      };
    },
  ): Promise<unknown>;
};

type KVNamespace = {
  list(options?: { prefix?: string; cursor?: string }): Promise<{
    keys: Array<{ name: string }>;
    cursor?: string;
  }>;
};

type ExecutionContext = {
  waitUntil(promise: Promise<unknown>): void;
};

type ScheduledController = unknown;

export type Env = {
  PLUGIN_MARKETPLACE_BUCKET: R2Bucket;
  PLUGIN_MARKETPLACE_BLACKLIST?: KVNamespace;
  GITHUB_TOKEN?: string;
};

type FetchLike = typeof fetch;

type RefreshOptions = {
  fetch?: FetchLike;
  now?: Date;
  logger?: Pick<Console, "error">;
};

type GitHubRepository = Record<string, unknown>;

export type PluginListing = {
  id: number;
  fullName: string;
  owner: string;
  name: string;
  description: string | null;
  url: string;
  stars: number;
  forks: number;
  openIssues: number;
  language: string | null;
  topics: string[];
  createdAt: string | null;
  updatedAt: string | null;
  pushedAt: string | null;
};

export type PluginSnapshot = {
  schemaVersion: 1;
  generatedAt: string;
  source: {
    provider: "github";
    query: string;
    totalCount: number;
    collectedCount: number;
    truncated: boolean;
    warnings?: string[];
  };
  plugins: PluginListing[];
};

export type RefreshResult =
  | { ok: true; snapshot: PluginSnapshot }
  | { ok: false; error: string };

export default {
  fetch(): Response {
    return jsonResponse({ error: "Not found" }, 404, "no-store");
  },

  scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext): void {
    ctx.waitUntil(refreshPlugins(env));
  },
};

export async function refreshPlugins(
  env: Env,
  options: RefreshOptions = {},
): Promise<RefreshResult> {
  const logger = options.logger ?? console;
  try {
    const token = env.GITHUB_TOKEN?.trim();
    if (!token) {
      throw new Error("GITHUB_TOKEN is not configured");
    }

    const fetchFn = options.fetch ?? fetch;
    const result = await fetchGitHubRepositories(fetchFn, token);
    const normalizedPlugins = normalizeRepositories(result.repositories);
    if (normalizedPlugins.length === 0) {
      throw new Error("GitHub returned no listable plugin repositories");
    }

    const blockedRepositories = await readBlacklistedRepositories(env);
    const plugins =
      blockedRepositories.size === 0
        ? normalizedPlugins
        : normalizedPlugins.filter(
            (plugin) => !blockedRepositories.has(plugin.fullName.toLowerCase()),
          );

    const snapshot: PluginSnapshot = {
      schemaVersion: 1,
      generatedAt: (options.now ?? new Date()).toISOString(),
      source: {
        provider: "github",
        query: GITHUB_QUERY,
        totalCount: result.totalCount,
        collectedCount: result.repositories.length,
        truncated: result.truncated,
      },
      plugins,
    };

    if (result.truncated) {
      snapshot.source.warnings = [
        `GitHub returned ${result.totalCount} results; only the first ${result.repositories.length} were collected.`,
      ];
    }

    await env.PLUGIN_MARKETPLACE_BUCKET.put(SNAPSHOT_KEY, JSON.stringify(snapshot), {
      httpMetadata: {
        contentType: "application/json; charset=utf-8",
        cacheControl: SNAPSHOT_CACHE_CONTROL,
      },
    });
    return { ok: true, snapshot };
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown refresh error";
    logger.error(`plugin marketplace refresh failed: ${message}`);
    return { ok: false, error: message };
  }
}

async function fetchGitHubRepositories(
  fetchFn: FetchLike,
  token: string,
  timeoutMs = REQUEST_TIMEOUT_MS,
): Promise<{ repositories: GitHubRepository[]; totalCount: number; truncated: boolean }> {
  const repositories: GitHubRepository[] = [];
  let totalCount = 0;

  for (let page = 1; repositories.length < MAX_REPOS; page += 1) {
    const url = new URL(GITHUB_SEARCH_URL);
    url.searchParams.set("q", GITHUB_QUERY);
    url.searchParams.set("per_page", String(PER_PAGE));
    url.searchParams.set("page", String(page));
    url.searchParams.set("sort", "stars");
    url.searchParams.set("order", "desc");

    const response = await fetchWithTimeout(
      fetchFn,
      url,
      {
        headers: {
          Accept: "application/vnd.github+json",
          Authorization: `Bearer ${token}`,
          "User-Agent": "herdr-plugin-marketplace",
          "X-GitHub-Api-Version": GITHUB_API_VERSION,
        },
      },
      timeoutMs,
    );

    if (!response.ok) {
      throw new Error(`GitHub search failed with status ${response.status}`);
    }

    const body = await response.json();
    if (!isObject(body) || typeof body.total_count !== "number" || !Array.isArray(body.items)) {
      throw new Error("GitHub search returned malformed JSON");
    }
    if (body.incomplete_results === true) {
      throw new Error("GitHub search returned incomplete results");
    }

    totalCount = body.total_count;
    repositories.push(...body.items.slice(0, MAX_REPOS - repositories.length));

    if (repositories.length >= totalCount || body.items.length === 0) {
      break;
    }
  }

  return {
    repositories,
    totalCount,
    truncated: totalCount > repositories.length,
  };
}

async function fetchWithTimeout(
  fetchFn: FetchLike,
  url: URL,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchFn(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

export function normalizeRepositories(repositories: GitHubRepository[]): PluginListing[] {
  return repositories
    .map(normalizeRepository)
    .filter((plugin): plugin is PluginListing => plugin !== null)
    .sort(comparePlugins);
}

async function readBlacklistedRepositories(env: Env): Promise<Set<string>> {
  const kv = env.PLUGIN_MARKETPLACE_BLACKLIST;
  const blockedRepositories = new Set<string>();
  if (!kv) {
    return blockedRepositories;
  }

  let cursor: string | undefined;
  do {
    const page = await kv.list({ prefix: BLACKLIST_REPO_KEY_PREFIX, cursor });
    for (const key of page.keys) {
      const repository = key.name.slice(BLACKLIST_REPO_KEY_PREFIX.length).trim().toLowerCase();
      if (repository.includes("/")) {
        blockedRepositories.add(repository);
      }
    }
    cursor = page.cursor;
  } while (cursor);

  return blockedRepositories;
}

function normalizeRepository(repo: GitHubRepository): PluginListing | null {
  if (
    readBoolean(repo.disabled) ||
    readBoolean(repo.archived) ||
    readBoolean(repo.fork) ||
    readBoolean(repo.private) ||
    readString(repo.visibility) === "private"
  ) {
    return null;
  }

  const fullNameParts = splitFullName(readString(repo.full_name));
  const ownerObject = isObject(repo.owner) ? repo.owner : {};
  const owner = firstString(readString(ownerObject.login), fullNameParts.owner);
  const name = firstString(readString(repo.name), fullNameParts.name);
  if (!owner || !name) {
    return null;
  }

  const fullName = readString(repo.full_name) ?? `${owner}/${name}`;
  const url = readString(repo.html_url);
  if (!url || !isValidGitHubRepoUrl(url, owner, name)) {
    return null;
  }

  return {
    id: readInteger(repo.id) ?? 0,
    fullName,
    owner,
    name,
    description: readNullableString(repo.description),
    url,
    stars: readNonNegativeInteger(repo.stargazers_count),
    forks: readNonNegativeInteger(repo.forks_count),
    openIssues: readNonNegativeInteger(repo.open_issues_count),
    language: readNullableString(repo.language),
    topics: readStringArray(repo.topics),
    createdAt: readIsoString(repo.created_at),
    updatedAt: readIsoString(repo.updated_at),
    pushedAt: readIsoString(repo.pushed_at),
  };
}

function comparePlugins(a: PluginListing, b: PluginListing): number {
  return (
    b.stars - a.stars ||
    dateMs(b.pushedAt) - dateMs(a.pushedAt) ||
    a.fullName.localeCompare(b.fullName)
  );
}

function jsonResponse(body: unknown, status: number, cacheControl: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": cacheControl,
    },
  });
}

function isValidGitHubRepoUrl(url: string, owner: string, name: string): boolean {
  try {
    const parsed = new URL(url);
    const segments = parsed.pathname.split("/").filter(Boolean);
    return (
      parsed.protocol === "https:" &&
      parsed.hostname === "github.com" &&
      segments.length === 2 &&
      segments[0].toLowerCase() === owner.toLowerCase() &&
      segments[1].toLowerCase() === name.toLowerCase()
    );
  } catch {
    return false;
  }
}

function splitFullName(fullName: string | null): { owner: string | null; name: string | null } {
  if (!fullName) {
    return { owner: null, name: null };
  }
  const [owner, name, extra] = fullName.split("/");
  if (!owner || !name || extra) {
    return { owner: null, name: null };
  }
  return { owner, name };
}

function firstString(...values: Array<string | null>): string | null {
  return values.find((value) => value !== null) ?? null;
}

function readString(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function readNullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function readStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function readInteger(value: unknown): number | null {
  return typeof value === "number" && Number.isInteger(value) ? value : null;
}

function readNonNegativeInteger(value: unknown): number {
  const integer = readInteger(value);
  return integer !== null && integer >= 0 ? integer : 0;
}

function readBoolean(value: unknown): boolean {
  return value === true;
}

function readIsoString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  return Number.isNaN(Date.parse(value)) ? null : value;
}

function dateMs(value: string | null): number {
  return value ? Date.parse(value) || 0 : 0;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
