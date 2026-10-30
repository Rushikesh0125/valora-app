import { describe, it, expect, vi, afterEach } from "vitest";
import {
  QlooClient,
  QlooError,
  handleQloo,
  selectRecipes,
  narrowConstraints,
  consumeRate,
  boundedJson,
} from "../src/qloo.js";
import { AiConsentRequired } from "../src/ai.js";
import { recipes } from "../src/discovery-recipes.js";
import type { Env, Principal } from "../src/types.js";
import { testDb } from "./sqlite.js";
const tag = "urn:tag:genre:place:restaurant:indian";
const selection = { id: tag, label: "Indian", kind: "tag" };
const constraints = {
  eatingPattern: "vegetarian" as const,
  budgetInr: 300,
  minutes: 40,
  mild: true,
  soft: false,
};
const user: Principal = {
  userId: "one",
  authProvider: "google",
  authSubject: "one",
  role: "user",
};
const config = {
  APP_ENV: "production",
  QLOO_API_KEY: "test-key",
  QLOO_API_URL: "https://hackathon.api.qloo.com",
} as Env;
afterEach(() => vi.unstubAllGlobals());
function setup() {
  const { db, sqlite } = testDb();
  sqlite.exec("INSERT INTO user_profiles(user_id,acknowledged,cooking_minutes) VALUES('one',1,40)");
  sqlite
    .prepare("INSERT INTO qloo_resolved VALUES(?,?,?,?,unixepoch()+300)")
    .run("one", tag, "tag", "Indian");
  return { db, sqlite, env: { ...config, DB: db } };
}
function request(path: string, body?: unknown, method = body ? "POST" : "GET") {
  return new Request("https://api.example/v1/qloo/" + path, {
    method,
    headers: { "content-type": "application/json" },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
}
function upstream() {
  return vi.fn(async (input: URL) => {
    const url = new URL(input);
    if (url.searchParams.get("filter.type") === "urn:tag")
      return Response.json({
        results: { tags: [{ tag_id: tag, name: "Indian" }] },
      });
    return Response.json({
      results: {
        entities: [
          {
            entity_id: "00000000-0000-4000-8000-000000000001",
            name: "Test venue",
            properties: { price_level: 2 },
          },
        ],
      },
    });
  });
}
describe("Qloo recommendation boundary", () => {
  it("fails truthfully without credentials or fabricated fallback", async () => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    await expect(
      new QlooClient({ ...config, QLOO_API_KEY: undefined }).search(
        "Indian",
        "cuisine",
      ),
    ).rejects.toMatchObject({ message: "qloo_key_pending" });
    expect(fetch).not.toHaveBeenCalled();
  });
  it("resolves cuisine choices without auto-selecting a match", async () => {
    const { env } = setup();
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        Response.json({
          results: {
            tags: [
              { tag_id: tag, name: "Indian" },
              {
                tag_id: "urn:tag:genre:place:restaurant:italian",
                name: "Italian",
              },
            ],
          },
        }),
      ),
    );
    const r = await handleQloo(
      request("search", { query: "Ind", kind: "cuisine" }),
      env,
      user,
    );
    expect(((await r.json()) as any).data).toMatchObject({
      requiresSelection: true,
      choices: expect.any(Array),
    });
  });
  it("only sends taste IDs and search region to Qloo; returns honest unknowns", async () => {
    const { env } = setup();
    const fetch = upstream();
    vi.stubGlobal("fetch", fetch);
    const r = await handleQloo(
      request("recommend", { selections: [selection], constraints }),
      env,
      user,
    );
    const body = (await r.json()) as any;
    expect(body.data.meals).toHaveLength(3);
    expect(body.data.dining[0]).toMatchObject({
      priceInr: null,
      suitability: "unverified",
      budgetStatus: "unverified",
    });
    expect(body.data.toolCalls).toBe(2);
    for (const [url, options] of fetch.mock.calls as any) {
      expect(String(url)).not.toContain("one");
      expect(String(url)).not.toMatch(
        /health|medication|vegetarian|budget|soft|mild/,
      );
      expect(options.headers["X-Api-Key"]).toBe("test-key");
      expect(options.signal).toBeDefined();
    }
    expect(body.data.unmetConstraints.join(" ")).toContain("unverified");
  });
  it("refuses unknown IDs and cross-account saved selections", async () => {
    const { env } = setup();
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    await expect(
      handleQloo(
        request("recommend", { selections: [selection], constraints }),
        env,
        { ...user, userId: "two" },
      ),
    ).rejects.toMatchObject({ message: "selection_needs_resolution" });
    expect(fetch).not.toHaveBeenCalled();
  });
  it("isolates taste persistence and permits explicit deletion", async () => {
    const { env } = setup();
    await handleQloo(
      request("tastes", { selections: [selection] }, "PUT"),
      env,
      user,
    );
    const r = await handleQloo(request("tastes"), env, {
      ...user,
      userId: "two",
    });
    expect(((await r.json()) as any).data.selections).toEqual([]);
    await handleQloo(request("tastes", { selections: [] }, "PUT"), env, user);
    expect(
      ((await (await handleQloo(request("tastes"), env, user)).json()) as any)
        .data.selections,
    ).toEqual([]);
  });
  it("rejects invented fields from the model and never saves a refinement", async () => {
    const { env, sqlite } = setup();
    sqlite.exec(
      "INSERT INTO user_ai_settings(user_id,cloud_ai_enabled) VALUES('one',1)",
    );
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          Response.json({choices:[{message:{content:'{"restaurant":"invented"}'},finish_reason:'stop'}],usage:{prompt_tokens:1,completion_tokens:1}}),
        ),
    );
    await expect(
      handleQloo(
        request("recommend", {
          selections: [selection],
          constraints,
          refinement: "quick",
        }),
        { ...env, NEBIUS_API_KEY: "test" },
        user,
      ),
    ).rejects.toMatchObject({ message: "refinement_needs_clarification" });
    expect(sqlite.prepare("SELECT * FROM qloo_tastes").all()).toEqual([]);
  });
  it("requires Nebius opt-in before interpreting refinement",async()=>{
    const {env,sqlite}=setup();sqlite.exec("INSERT INTO user_ai_settings(user_id,cloud_ai_enabled) VALUES('one',0)");
    const fetch=vi.fn();vi.stubGlobal('fetch',fetch);
    await expect(handleQloo(request('recommend',{selections:[selection],constraints,refinement:'milder and quicker'}),{...env,NEBIUS_API_KEY:'test'},user)).rejects.toBeInstanceOf(AiConsentRequired);
    expect(fetch).not.toHaveBeenCalled();
  });
  it("does not pad empty upstream results", async () => {
    const { env } = setup();
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: URL) =>
        Response.json({
          results:
            new URL(url).searchParams.get("filter.type") === "urn:tag"
              ? { tags: [] }
              : { entities: [] },
        }),
      ),
    );
    const body = (await (
      await handleQloo(
        request("recommend", { selections: [selection], constraints }),
        env,
        user,
      )
    ).json()) as any;
    expect(body.data.dining).toEqual([]);
    expect(body.data.meals).toEqual([]);
  });
  it.each([429, 500])(
    "maps provider HTTP %i into a recoverable error",
    async (status) => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue(new Response("", { status })),
      );
      await expect(
        new QlooClient(config).search("Indian", "cuisine"),
      ).rejects.toBeInstanceOf(QlooError);
    },
  );
  it("rejects malformed responses and reports transport failure", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          Response.json({ results: { tags: [{ name: "missing id" }] } }),
        ),
    );
    await expect(
      new QlooClient(config).search("Indian", "cuisine"),
    ).rejects.toMatchObject({ status: 502 });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockRejectedValue(new DOMException("timeout", "TimeoutError")),
    );
    await expect(
      new QlooClient(config).search("Indian", "cuisine"),
    ).rejects.toMatchObject({ message: "qloo_unavailable" });
  });
  it("accepts minimal live venue data without requiring unrelated metadata", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        Response.json({
          results: {
            entities: [
              {
                entity_id: "515BEAF5-CC2B-4E2F-AEDC-525F5EF9A3A4",
                name: "Public venue fixture",
                types: null,
                properties: { address: null, price_level: null },
                tags: [
                  { id: "urn:tag:genre:place:restaurant", name: "Restaurant" },
                ],
              },
            ],
          },
        }),
      ),
    );
    const venues = await new QlooClient(config).insights(
      [{ id: tag, kind: "tag", label: "Indian" }],
      "places",
    );
    expect(venues).toHaveLength(1);
    expect(venues[0]).toMatchObject({
      name: "Public venue fixture",
      properties: { price_level: null },
    });
    expect(venues[0]).not.toHaveProperty("tags");
  });
  it("normalizes live lookup IDs and excludes same-name hotel tags", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        Response.json({
          results: {
            tags: [
              { id: "urn:tag:genre:place:restaurant:indian", name: "Indian" },
              { id: "urn:tag:genre:place:hotel:indian", name: "Indian" },
            ],
          },
        }),
      ),
    );
    expect(await new QlooClient(config).search("Indian", "cuisine")).toEqual([
      {
        id: "urn:tag:genre:place:restaurant:indian",
        kind: "tag",
        label: "Indian",
      },
    ]);
  });
  it("follows a same-origin endpoint redirect without exposing the key", async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(null, {
          status: 301,
          headers: { location: "/v2/tags/?filter.query=Indian" },
        }),
      )
      .mockResolvedValueOnce(
        Response.json({ results: { tags: [{ tag_id: tag, name: "Indian" }] } }),
      );
    vi.stubGlobal("fetch", fetch);
    const choices = await new QlooClient(config).search("Indian", "cuisine");
    expect(choices[0].label).toBe("Indian");
    expect(new URL(fetch.mock.calls[1][0]).origin).toBe(
      "https://hackathon.api.qloo.com",
    );
    expect(fetch.mock.calls[1][1].headers["X-Api-Key"]).toBe("test-key");
    expect(fetch.mock.calls[0][1].signal).toBe(fetch.mock.calls[1][1].signal);
  });
  it("rejects external redirects before sending credentials to another host", async () => {
    const fetch = vi.fn().mockResolvedValue(
      new Response(null, {
        status: 302,
        headers: { location: "https://example.com/steal" },
      }),
    );
    vi.stubGlobal("fetch", fetch);
    await expect(
      new QlooClient(config).search("Indian", "cuisine"),
    ).rejects.toMatchObject({ message: "qloo_invalid_redirect", status: 502 });
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("bounds redirect loops", async () => {
    const fetch = vi.fn().mockImplementation(
      async () =>
        new Response(null, {
          status: 307,
          headers: { location: "/v2/tags" },
        }),
    );
    vi.stubGlobal("fetch", fetch);
    await expect(
      new QlooClient(config).search("Indian", "cuisine"),
    ).rejects.toMatchObject({ message: "qloo_invalid_redirect" });
    expect(fetch).toHaveBeenCalledTimes(3);
  });
  it("enforces atomic per-account limits and bounds payload size", async () => {
    const { db } = testDb();
    await consumeRate(db, "one", 1);
    await expect(consumeRate(db, "one", 1)).rejects.toMatchObject({
      status: 429,
    });
    await expect(consumeRate(db, "two", 1)).resolves.toBeUndefined();
    await expect(
      consumeRate(db, "one", 1, "recommend"),
    ).resolves.toBeUndefined();
    await expect(
      boundedJson(new Response("x".repeat(20)).body, 10),
    ).rejects.toMatchObject({ status: 413 });
  });
  it("never relaxes restrictions through a refinement", () => {
    expect(
      narrowConstraints(
        { ...constraints, soft: true },
        { mild: false, soft: false, minutes: 120 },
      ),
    ).toEqual({ ...constraints, soft: true });
  });
  it("only matches real returned cuisine tags and reviewed recipes", () => {
    expect(recipes).toHaveLength(23);
    expect(new Set(recipes.map((r) => r.id)).size).toBe(23);
    expect(
      selectRecipes(
        [{ tag_id: "urn:tag:genre:place:restaurant", name: "Indian" }],
        constraints,
      ),
    ).toEqual([]);
    const italian = selectRecipes(
      [{ tag_id: "urn:tag:genre:place:restaurant:italian", name: "Italian" }],
      constraints,
    );
    expect(italian).toHaveLength(3);
    for (const r of italian) {
      expect(r.cuisine).toBe("italian");
      expect(r.priceInr).toBeNull();
      expect(r.steps.length).toBeGreaterThan(0);
      expect(r.ingredients.length).toBeGreaterThan(0);
      expect(r.source).toContain("not clinically");
    }
  });
});
