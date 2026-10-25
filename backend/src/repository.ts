import type { MemoryFact, PreferencesRecord, Principal, ProfileRecord } from "./types.js";

export interface UserRepository {
  resolvePrincipal(principal: Principal): Promise<Principal>;
  getProfile(userId: string): Promise<ProfileRecord | null>;
  saveProfile(userId: string, profile: Omit<ProfileRecord, "userId" | "updatedAt">): Promise<ProfileRecord>;
  getPreferences(userId: string): Promise<PreferencesRecord | null>;
  savePreferences(userId: string, preferences: Omit<PreferencesRecord, "userId" | "updatedAt">): Promise<PreferencesRecord>;
  listMemory(userId: string): Promise<MemoryFact[]>;
  upsertMemory(userId: string, fact: Pick<MemoryFact, "key" | "label" | "value" | "source" | "safetyRelevant" | "status">): Promise<MemoryFact>;
  updateMemoryStatus(userId: string, factId: string, status: MemoryFact["status"]): Promise<MemoryFact | null>;
  deleteMemory(userId: string, factId: string): Promise<boolean>;
}

export class D1UserRepository implements UserRepository {
  constructor(private readonly db: D1Database) {}

  async resolvePrincipal(principal: Principal): Promise<Principal> {
    const id = principal.authProvider === "development" ? principal.userId : crypto.randomUUID();
    const user = principal.authProvider === "development"
      ? await this.db.prepare(
        `INSERT INTO app_users (id, auth_provider, auth_subject) VALUES (?,?,?)
         ON CONFLICT (auth_provider, auth_subject) DO UPDATE SET updated_at=${updatedAtSql}
         RETURNING id, role`,
      ).bind(id, principal.authProvider, principal.authSubject).first<UserIdentityRow>()
      : await this.db.prepare(
        `INSERT INTO app_users (id, auth_provider, auth_subject, email) VALUES (?,?,?,?)
         ON CONFLICT (auth_provider, auth_subject) DO UPDATE SET
           email=COALESCE(excluded.email, app_users.email), updated_at=${updatedAtSql}
         RETURNING id, role`,
      ).bind(id, principal.authProvider, principal.authSubject, principal.email ?? null).first<UserIdentityRow>();
    if (!user) throw new Error("user_upsert_failed");
    return { ...principal, userId:user.id, role:user.role === "admin" ? "admin" : "user" };
  }

  async getProfile(userId: string): Promise<ProfileRecord | null> {
    const row = await this.db.prepare("SELECT * FROM user_profiles WHERE user_id = ?").bind(userId).first<ProfileRow>();
    return row ? profileFromRow(row) : null;
  }

  async saveProfile(userId: string, p: Omit<ProfileRecord, "userId" | "updatedAt">): Promise<ProfileRecord> {
    const row = await this.db.prepare(
      `INSERT INTO user_profiles (user_id, goals, eating_pattern, exclusions, allergies, health_context, cuisines,
        other_goal, other_allergy, other_health, other_cuisine, coverage, budget_inr, cooking_minutes, planning_time, acknowledged)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
       ON CONFLICT (user_id) DO UPDATE SET goals=excluded.goals, eating_pattern=excluded.eating_pattern,
        exclusions=excluded.exclusions, allergies=excluded.allergies, health_context=excluded.health_context,
        cuisines=excluded.cuisines, other_goal=excluded.other_goal, other_allergy=excluded.other_allergy,
        other_health=excluded.other_health, other_cuisine=excluded.other_cuisine, coverage=excluded.coverage,
        budget_inr=excluded.budget_inr, cooking_minutes=excluded.cooking_minutes, planning_time=excluded.planning_time,
        acknowledged=excluded.acknowledged, updated_at=${updatedAtSql} RETURNING *`,
    ).bind(
      userId, JSON.stringify(p.goals), p.eatingPattern, p.exclusions, JSON.stringify(p.allergies), JSON.stringify(p.healthContext),
      JSON.stringify(p.cuisines), p.otherGoal, p.otherAllergy, p.otherHealth, p.otherCuisine, p.coverage, p.weeklyBudgetInr,
      p.cookingMinutes, p.planningTime, p.acknowledged ? 1 : 0,
    ).first<ProfileRow>();
    if (!row) throw new Error("profile_upsert_failed");
    return profileFromRow(row);
  }

  async getPreferences(userId: string): Promise<PreferencesRecord | null> {
    const row = await this.db.prepare("SELECT * FROM user_preferences WHERE user_id = ?").bind(userId).first<PreferencesRow>();
    return row ? preferencesFromRow(row) : null;
  }

  async savePreferences(userId: string, p: Omit<PreferencesRecord, "userId" | "updatedAt">): Promise<PreferencesRecord> {
    const row = await this.db.prepare(
      `INSERT INTO user_preferences (user_id, locale, currency, notifications_enabled, notification_frequency,
        notification_categories, quiet_start, quiet_end, time_zone) VALUES (?,?,?,?,?,?,?,?,?)
       ON CONFLICT (user_id) DO UPDATE SET locale=excluded.locale, currency=excluded.currency,
        notifications_enabled=excluded.notifications_enabled, notification_frequency=excluded.notification_frequency,
        notification_categories=excluded.notification_categories, quiet_start=excluded.quiet_start,
        quiet_end=excluded.quiet_end, time_zone=excluded.time_zone, updated_at=${updatedAtSql} RETURNING *`,
    ).bind(
      userId, p.locale, p.currency, p.notificationsEnabled ? 1 : 0, p.notificationFrequency,
      JSON.stringify(p.notificationCategories), sqlTime(p.quietStart), sqlTime(p.quietEnd), p.timeZone,
    ).first<PreferencesRow>();
    if (!row) throw new Error("preferences_upsert_failed");
    return preferencesFromRow(row);
  }

  async listMemory(userId: string): Promise<MemoryFact[]> {
    const { results } = await this.db.prepare("SELECT * FROM memory_facts WHERE user_id = ? ORDER BY created_at").bind(userId).all<MemoryRow>();
    return results.map(memoryFromRow);
  }

  async upsertMemory(userId: string, f: Pick<MemoryFact, "key" | "label" | "value" | "source" | "safetyRelevant" | "status">): Promise<MemoryFact> {
    const row = await this.db.prepare(
      `INSERT INTO memory_facts (id, user_id, fact_key, label, value, source, safety_relevant, status)
       VALUES (?,?,?,?,?,?,?,?) ON CONFLICT (user_id, fact_key) DO UPDATE SET label=excluded.label,
       value=excluded.value, source=excluded.source, safety_relevant=excluded.safety_relevant,
       status=excluded.status, updated_at=${updatedAtSql} RETURNING *`,
    ).bind(crypto.randomUUID(),userId,f.key,f.label,f.value,f.source,f.safetyRelevant ? 1 : 0,f.status).first<MemoryRow>();
    if (!row) throw new Error("memory_upsert_failed");
    return memoryFromRow(row);
  }

  async updateMemoryStatus(userId: string, factId: string, status: MemoryFact["status"]): Promise<MemoryFact | null> {
    const row = await this.db.prepare(
      `UPDATE memory_facts SET status=?, updated_at=${updatedAtSql} WHERE user_id=? AND id=? RETURNING *`,
    ).bind(status,userId,factId).first<MemoryRow>();
    return row ? memoryFromRow(row) : null;
  }

  async deleteMemory(userId: string, factId: string): Promise<boolean> {
    const result = await this.db.prepare("DELETE FROM memory_facts WHERE user_id=? AND id=?").bind(userId,factId).run();
    return result.meta.changes === 1;
  }
}

const updatedAtSql = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";
interface UserIdentityRow { id:string; role:string }
interface ProfileRow {
  user_id:string; goals:string; eating_pattern:string; exclusions:string; allergies:string; health_context:string; cuisines:string;
  other_goal:string; other_allergy:string; other_health:string; other_cuisine:string; coverage:string; budget_inr:number;
  cooking_minutes:number; planning_time:string; acknowledged:number; updated_at:string;
}
interface PreferencesRow {
  user_id:string; locale:string; currency:string; notifications_enabled:number; notification_frequency:string;
  notification_categories:string; quiet_start:string; quiet_end:string; time_zone:string; updated_at:string;
}
interface MemoryRow {
  id:string; fact_key:string; label:string; value:string; source:string; safety_relevant:number; status:"active"|"paused";
  created_at:string; updated_at:string;
}

function stringArray(value: string): string[] {
  const parsed: unknown = JSON.parse(value);
  if (!Array.isArray(parsed) || !parsed.every(item => typeof item === "string")) throw new Error("invalid_array_in_database");
  return parsed;
}
function profileFromRow(r: ProfileRow): ProfileRecord {
  return { userId:r.user_id, goals:stringArray(r.goals), eatingPattern:r.eating_pattern, exclusions:r.exclusions,
    allergies:stringArray(r.allergies), healthContext:stringArray(r.health_context), cuisines:stringArray(r.cuisines),
    otherGoal:r.other_goal, otherAllergy:r.other_allergy, otherHealth:r.other_health, otherCuisine:r.other_cuisine,
    coverage:r.coverage, weeklyBudgetInr:r.budget_inr, cookingMinutes:r.cooking_minutes, planningTime:r.planning_time,
    acknowledged:r.acknowledged === 1, updatedAt:new Date(r.updated_at).toISOString() };
}
function preferencesFromRow(r: PreferencesRow): PreferencesRecord {
  return { userId:r.user_id, locale:r.locale, currency:r.currency, notificationsEnabled:r.notifications_enabled === 1,
    notificationFrequency:r.notification_frequency, notificationCategories:stringArray(r.notification_categories),
    quietStart:r.quiet_start, quietEnd:r.quiet_end, timeZone:r.time_zone, updatedAt:new Date(r.updated_at).toISOString() };
}
function memoryFromRow(r: MemoryRow): MemoryFact {
  return { id:r.id, key:r.fact_key, label:r.label, value:r.value, source:r.source, safetyRelevant:r.safety_relevant === 1,
    status:r.status, createdAt:new Date(r.created_at).toISOString(), updatedAt:new Date(r.updated_at).toISOString() };
}
function sqlTime(value: string): string { return value.length === 5 ? `${value}:00` : value; }
