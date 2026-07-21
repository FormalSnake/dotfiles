import { describe, expect, test } from "bun:test";
import worker, { normalizeRepositories, refreshPlugins, type Env } from "./index";

class MemoryR2 {
  objects = new Map<string, { value: string; options: unknown }>();

  async put(key: string, value: string, options?: unknown): Promise<void> {
    this.objects.set(key, { value, options });
  }
}

class MemoryKV {
  constructor(private readonly keyNames: string[]) {}

  async list(options?: { prefix?: string }): Promise<{
    keys: Array<{ name: string }>;
  }> {
    return {
      keys: this.keyNames
        .filter((name) => !options?.prefix || name.startsWith(options.prefix))
        .map((name) => ({ name })),
    };
  }
}

function repo(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 1,
    full_name: "ogulcancelik/herdr-plugin-example",
    owner: { login: "ogulcancelik" },
    name: "herdr-plugin-example",
    description: "Example plugin",
    html_url: "https://github.com/ogulcancelik/herdr-plugin-example",
    stargazers_count: 5,
    forks_count: 1,
    open_issues_count: 0,
    language: "TypeScript",
    topics: ["herdr-plugin"],
    created_at: "2026-06-01T00:00:00Z",
    updated_at: "2026-06-02T00:00:00Z",
    pushed_at: "2026-06-03T00:00:00Z",
    archived: false,
    fork: false,
    disabled: false,
    private: false,
    visibility: "public",
    ...overrides,
  };
}

function env(bucket = new MemoryR2(), blacklist?: MemoryKV): Env {
  return {
    PLUGIN_MARKETPLACE_BUCKET: bucket,
    PLUGIN_MARKETPLACE_BLACKLIST: blacklist,
    GITHUB_TOKEN: "token",
  };
}

describe("normalizeRepositories", () => {
  test("normalizes repository fields into the public snapshot schema", () => {
    const [plugin] = normalizeRepositories([repo()]);

    expect(plugin).toEqual({
      id: 1,
      fullName: "ogulcancelik/herdr-plugin-example",
      owner: "ogulcancelik",
      name: "herdr-plugin-example",
      description: "Example plugin",
      url: "https://github.com/ogulcancelik/herdr-plugin-example",
      stars: 5,
      forks: 1,
      openIssues: 0,
      language: "TypeScript",
      topics: ["herdr-plugin"],
      createdAt: "2026-06-01T00:00:00Z",
      updatedAt: "2026-06-02T00:00:00Z",
      pushedAt: "2026-06-03T00:00:00Z",
    });
  });

  test("sorts by stars, pushed date, and full name", () => {
    const plugins = normalizeRepositories([
      repo({
        id: 1,
        full_name: "z/z",
        owner: { login: "z" },
        name: "z",
        html_url: "https://github.com/z/z",
        stargazers_count: 3,
        pushed_at: "2026-06-01T00:00:00Z",
      }),
      repo({
        id: 2,
        full_name: "a/a",
        owner: { login: "a" },
        name: "a",
        html_url: "https://github.com/a/a",
        stargazers_count: 3,
        pushed_at: "2026-06-02T00:00:00Z",
      }),
      repo({
        id: 3,
        full_name: "m/m",
        owner: { login: "m" },
        name: "m",
        html_url: "https://github.com/m/m",
        stargazers_count: 10,
      }),
    ]);

    expect(plugins.map((plugin) => plugin.fullName)).toEqual(["m/m", "a/a", "z/z"]);
  });

  test("drops unsafe urls, archived repositories, forks, disabled repositories, and private repositories", () => {
    const plugins = normalizeRepositories([
      repo({ html_url: "https://example.com/ogulcancelik/herdr-plugin-example" }),
      repo({ archived: true }),
      repo({ fork: true }),
      repo({ disabled: true }),
      repo({ private: true }),
      repo({ visibility: "private" }),
      repo({ id: 5 }),
    ]);

    expect(plugins.map((plugin) => plugin.id)).toEqual([5]);
  });

  test("uses safe defaults for missing nullable fields", () => {
    const [plugin] = normalizeRepositories([
      repo({
        id: undefined,
        description: undefined,
        stargazers_count: undefined,
        forks_count: undefined,
        open_issues_count: undefined,
        language: undefined,
        topics: undefined,
        created_at: "not a date",
        updated_at: undefined,
        pushed_at: undefined,
      }),
    ]);

    expect(plugin.id).toBe(0);
    expect(plugin.description).toBeNull();
    expect(plugin.stars).toBe(0);
    expect(plugin.forks).toBe(0);
    expect(plugin.openIssues).toBe(0);
    expect(plugin.language).toBeNull();
    expect(plugin.topics).toEqual([]);
    expect(plugin.createdAt).toBeNull();
    expect(plugin.updatedAt).toBeNull();
    expect(plugin.pushedAt).toBeNull();
  });
});

describe("refreshPlugins", () => {
  test("fetches pages and writes a sorted snapshot to R2 with cache metadata", async () => {
    const calls: string[] = [];
    const fetch = async (input: RequestInfo | URL): Promise<Response> => {
      const url = new URL(input.toString());
      calls.push(url.searchParams.get("page") ?? "");
      const page = url.searchParams.get("page");
      const item =
        page === "1"
          ? repo({ id: 1, full_name: "b/b", owner: { login: "b" }, name: "b", html_url: "https://github.com/b/b" })
          : repo({
              id: 2,
              full_name: "a/a",
              owner: { login: "a" },
              name: "a",
              html_url: "https://github.com/a/a",
              stargazers_count: 9,
            });
      return Response.json({ total_count: 2, items: [item] });
    };
    const bucket = new MemoryR2();

    const result = await refreshPlugins(env(bucket), {
      fetch,
      now: new Date("2026-06-20T12:00:00.000Z"),
      logger: { error() {} },
    });

    expect(result.ok).toBe(true);
    expect(calls).toEqual(["1", "2"]);
    const object = bucket.objects.get("plugins/index.json");
    expect(object?.options).toEqual({
      httpMetadata: {
        contentType: "application/json; charset=utf-8",
        cacheControl: "public, max-age=300, s-maxage=1800, stale-while-revalidate=3600",
      },
    });
    const snapshot = JSON.parse(object?.value ?? "");
    expect(snapshot.generatedAt).toBe("2026-06-20T12:00:00.000Z");
    expect(snapshot.source).toMatchObject({
      provider: "github",
      query: "topic:herdr-plugin is:public",
      totalCount: 2,
      collectedCount: 2,
      truncated: false,
    });
    expect(snapshot.plugins.map((plugin: { fullName: string }) => plugin.fullName)).toEqual([
      "a/a",
      "b/b",
    ]);
  });

  test("excludes repositories listed in the KV blacklist", async () => {
    const fetch = async (): Promise<Response> =>
      Response.json({
        total_count: 2,
        items: [
          repo({
            id: 1,
            full_name: "example/not-a-plugin",
            owner: { login: "example" },
            name: "not-a-plugin",
            html_url: "https://github.com/example/not-a-plugin",
          }),
          repo({
            id: 2,
            full_name: "ogulcancelik/herdr-plugin-example",
            owner: { login: "ogulcancelik" },
            name: "herdr-plugin-example",
            html_url: "https://github.com/ogulcancelik/herdr-plugin-example",
          }),
        ],
      });
    const bucket = new MemoryR2();

    const result = await refreshPlugins(env(bucket, new MemoryKV(["repo:example/not-a-plugin"])), {
      fetch,
      logger: { error() {} },
    });

    expect(result.ok).toBe(true);
    const snapshot = JSON.parse(bucket.objects.get("plugins/index.json")?.value ?? "");
    expect(snapshot.plugins.map((plugin: { fullName: string }) => plugin.fullName)).toEqual([
      "ogulcancelik/herdr-plugin-example",
    ]);
  });

  test("writes an empty snapshot when every listable repository is blacklisted", async () => {
    const fetch = async (): Promise<Response> =>
      Response.json({
        total_count: 1,
        items: [
          repo({
            id: 1,
            full_name: "example/not-a-plugin",
            owner: { login: "example" },
            name: "not-a-plugin",
            html_url: "https://github.com/example/not-a-plugin",
          }),
        ],
      });
    const bucket = new MemoryR2();
    await bucket.put("plugins/index.json", '{"schemaVersion":1,"plugins":[{"id":1}]}');

    const result = await refreshPlugins(env(bucket, new MemoryKV(["repo:example/not-a-plugin"])), {
      fetch,
      logger: { error() {} },
    });

    expect(result.ok).toBe(true);
    const snapshot = JSON.parse(bucket.objects.get("plugins/index.json")?.value ?? "");
    expect(snapshot.plugins).toEqual([]);
  });

  test("marks snapshots truncated at the GitHub search cap", async () => {
    const fetch = async (): Promise<Response> => {
      const items = Array.from({ length: 100 }, (_, index) =>
        repo({
          id: index,
          full_name: `owner/repo-${index}`,
          owner: { login: "owner" },
          name: `repo-${index}`,
          html_url: `https://github.com/owner/repo-${index}`,
        }),
      );
      return Response.json({ total_count: 1200, items });
    };

    const result = await refreshPlugins(env(), {
      fetch,
      now: new Date("2026-06-20T12:00:00.000Z"),
      logger: { error() {} },
    });

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.snapshot.source.collectedCount).toBe(1000);
    expect(result.snapshot.source.truncated).toBe(true);
    expect(result.snapshot.source.warnings?.[0]).toContain("1200");
  });

  for (const { name, fetch } of [
    {
      name: "GitHub failure",
      fetch: async (): Promise<Response> => new Response("rate limited", { status: 429 }),
    },
    {
      name: "no listable repositories",
      fetch: async (): Promise<Response> => Response.json({ total_count: 0, items: [] }),
    },
    {
      name: "incomplete search results",
      fetch: async (): Promise<Response> =>
        Response.json({ total_count: 1, incomplete_results: true, items: [repo()] }),
    },
  ]) {
    test(`does not overwrite the R2 snapshot on ${name}`, async () => {
      const bucket = new MemoryR2();
      await bucket.put("plugins/index.json", '{"schemaVersion":1,"plugins":[{"id":1}]}');

      const result = await refreshPlugins(env(bucket), {
        fetch,
        logger: { error() {} },
      });

      expect(result.ok).toBe(false);
      expect(bucket.objects.get("plugins/index.json")?.value).toBe(
        '{"schemaVersion":1,"plugins":[{"id":1}]}',
      );
    });
  }
});

describe("fetch handler", () => {
  test("does not expose a public Worker API", async () => {
    const response = await worker.fetch(new Request("https://herdr.dev/api/plugins"), env());

    expect(response.status).toBe(404);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });
});
