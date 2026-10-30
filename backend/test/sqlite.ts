import { DatabaseSync } from "node:sqlite";
import { readFileSync, readdirSync } from "node:fs";
export function testDb() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec("PRAGMA foreign_keys=ON");
  for (const file of readdirSync("d1_migrations")
    .filter((f) => f.endsWith(".sql"))
    .sort())
    sqlite.exec(readFileSync(`d1_migrations/${file}`, "utf8"));
  const db = {
    prepare(sql: string) {
      let values: (string | number | null)[] = [];
      const numbered = () => Object.fromEntries(values.map((value,index)=>[String(index+1),value]));
      const statement = {
        bind(...v: (string | number | null)[]) {
          values = v;
          return statement;
        },
        async first() {
          return (/\?[1-9]/.test(sql) ? sqlite.prepare(sql).get(numbered()) : sqlite.prepare(sql).get(...values)) ?? null;
        },
        async run() {
          const result = /\?[1-9]/.test(sql) ? sqlite.prepare(sql).run(numbered()) : sqlite.prepare(sql).run(...values);
          return { success: true, meta: { changes: Number(result.changes) } };
        },
        async all() {
          return { success: true, results: /\?[1-9]/.test(sql) ? sqlite.prepare(sql).all(numbered()) : sqlite.prepare(sql).all(...values) };
        },
      };
      return statement;
    },
  } as unknown as D1Database;
  sqlite.exec(
    "INSERT INTO app_users(id,auth_provider,auth_subject) VALUES('one','google','one'),('two','google','two')",
  );
  return { db, sqlite };
}
