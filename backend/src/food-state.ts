import { z } from "zod";

const slot = z.object({
  option: z.number().int().min(0).max(4),
  servings: z.number().int().min(1).max(4), removed: z.boolean(),
}).strict();
const text = z.string().trim().min(1).max(200);
export const foodStateSchema = z.object({
  schemaVersion: z.literal(1),
  pantry: z.array(z.object({
    id: z.number().int().min(1).max(2147483647), name: text, amount: text,
    kind: z.enum(["ingredient", "leftover"]),
  }).strict()).max(500).refine(items => new Set(items.map(item => item.id)).size === items.length, "Duplicate pantry IDs"),
  intake: z.array(z.object({
    name: text, portion: text, at: z.iso.datetime({ offset: true }),
    sourceName: text.nullable(), remaining: text.nullable(),
  }).strict().refine(item => item.sourceName !== null || item.remaining === null, "Remaining amount requires a source")).max(5000),
  plan: z.object({
    recipeSet: z.literal("example-v1"), startDate: z.iso.date(),
    days: z.array(z.object({ breakfast: slot, lunch: slot, dinner: slot }).strict()).length(5),
  }).strict(),
}).strict();

export const foodWriteSchema = z.object({
  expectedVersion: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER - 1),
  mutationId: z.string().regex(/^[a-f0-9]{32}$/), state: foodStateSchema,
}).strict();
type FoodWrite = z.infer<typeof foodWriteSchema>;
interface FoodRow { version: number; payload: string; updated_at: string }

export class FoodStateConflict extends Error {}

export class D1FoodRepository {
  constructor(private readonly db: D1Database) {}

  async get(userId: string) {
    const row = await this.db.prepare("SELECT version, payload, updated_at FROM food_states WHERE user_id=?")
      .bind(userId).first<FoodRow>();
    return row ? { version: row.version, state: foodStateSchema.parse(JSON.parse(row.payload)), updatedAt: row.updated_at }
      : { version: 0, state: null, updatedAt: null };
  }

  async save(userId: string, write: FoodWrite) {
    const payload = JSON.stringify(write.state);
    // One statement commits the log, pantry and plan together. A retry of the
    // same mutation returns its original version without applying it twice.
    const row = await this.db.prepare(`
      INSERT INTO food_states (user_id, version, payload, mutation_id)
      SELECT ?1, 1, ?2, ?3 WHERE ?4=0 OR EXISTS (SELECT 1 FROM food_states WHERE user_id=?1)
      ON CONFLICT(user_id) DO UPDATE SET
        version=CASE WHEN food_states.mutation_id=?3 THEN food_states.version ELSE food_states.version+1 END,
        payload=excluded.payload, mutation_id=excluded.mutation_id,
        updated_at=CASE WHEN food_states.mutation_id=?3 THEN food_states.updated_at ELSE strftime('%Y-%m-%dT%H:%M:%fZ','now') END
      WHERE (food_states.version=?4 AND food_states.mutation_id<>?3)
        OR (food_states.mutation_id=?3 AND food_states.payload=?2)
      RETURNING version, updated_at
    `).bind(userId, payload, write.mutationId, write.expectedVersion).first<{ version: number; updated_at: string }>();
    if (!row) throw new FoodStateConflict();
    return { version: row.version, updatedAt: row.updated_at };
  }
}

/** Bound the aggregate before JSON parsing; Content-Length is not trusted. */
export async function readFoodWrite(request: Request): Promise<unknown> {
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 512 * 1024) {
        await reader.cancel();
        throw new FoodStateTooLarge();
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    try { return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
    catch { return null; }
  } finally { reader.releaseLock(); }
}
export class FoodStateTooLarge extends Error {}
