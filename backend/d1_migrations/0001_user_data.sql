CREATE TABLE app_users (
  id TEXT PRIMARY KEY NOT NULL,
  auth_provider TEXT NOT NULL,
  auth_subject TEXT NOT NULL,
  email TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (auth_provider, auth_subject)
);

CREATE TABLE user_profiles (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  goals TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(goals)),
  eating_pattern TEXT NOT NULL DEFAULT 'Omnivore',
  exclusions TEXT NOT NULL DEFAULT '',
  allergies TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(allergies)),
  health_context TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(health_context)),
  cuisines TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(cuisines)),
  other_goal TEXT NOT NULL DEFAULT '',
  other_allergy TEXT NOT NULL DEFAULT '',
  other_health TEXT NOT NULL DEFAULT '',
  other_cuisine TEXT NOT NULL DEFAULT '',
  coverage TEXT NOT NULL DEFAULT 'Breakfast, lunch & dinner',
  budget_inr INTEGER NOT NULL DEFAULT 2000 CHECK (budget_inr >= 0),
  cooking_minutes INTEGER NOT NULL DEFAULT 30 CHECK (cooking_minutes >= 0),
  planning_time TEXT NOT NULL DEFAULT 'Evening',
  acknowledged INTEGER NOT NULL DEFAULT 0 CHECK (acknowledged IN (0,1)),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE user_preferences (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  locale TEXT NOT NULL DEFAULT 'en-IN',
  currency TEXT NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  notifications_enabled INTEGER NOT NULL DEFAULT 1 CHECK (notifications_enabled IN (0,1)),
  notification_frequency TEXT NOT NULL DEFAULT 'Daily',
  notification_categories TEXT NOT NULL DEFAULT '["Plan ready","Pantry check","Meal check-in"]' CHECK (json_valid(notification_categories)),
  quiet_start TEXT NOT NULL DEFAULT '22:00:00',
  quiet_end TEXT NOT NULL DEFAULT '07:00:00',
  time_zone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE memory_facts (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  fact_key TEXT NOT NULL,
  label TEXT NOT NULL,
  value TEXT NOT NULL,
  source TEXT NOT NULL,
  safety_relevant INTEGER NOT NULL DEFAULT 0 CHECK (safety_relevant IN (0,1)),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (user_id, fact_key)
);

CREATE INDEX memory_facts_user_created_idx ON memory_facts(user_id, created_at);

CREATE TABLE user_ai_settings (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  cloud_ai_enabled INTEGER NOT NULL DEFAULT 0 CHECK (cloud_ai_enabled IN (0,1)),
  consent_updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
