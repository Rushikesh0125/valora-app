import type { Env } from "./types.js";

export function database(env: Env): D1Database { return env.DB; }
