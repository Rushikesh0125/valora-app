CREATE TABLE IF NOT EXISTS app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_provider text NOT NULL,
  auth_subject text NOT NULL,
  email text,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (auth_provider, auth_subject)
);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id uuid PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE,
  goals text[] NOT NULL DEFAULT '{}',
  eating_pattern text NOT NULL DEFAULT 'Omnivore',
  exclusions text NOT NULL DEFAULT '',
  allergies text[] NOT NULL DEFAULT '{}',
  health_context text[] NOT NULL DEFAULT '{}',
  cuisines text[] NOT NULL DEFAULT '{}',
  other_goal text NOT NULL DEFAULT '',
  other_allergy text NOT NULL DEFAULT '',
  other_health text NOT NULL DEFAULT '',
  other_cuisine text NOT NULL DEFAULT '',
  coverage text NOT NULL DEFAULT 'Breakfast, lunch & dinner',
  budget_inr integer NOT NULL DEFAULT 2000 CHECK (budget_inr >= 0),
  cooking_minutes integer NOT NULL DEFAULT 30 CHECK (cooking_minutes >= 0),
  planning_time text NOT NULL DEFAULT 'Evening',
  acknowledged boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id uuid PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE,
  locale text NOT NULL DEFAULT 'en-IN',
  currency char(3) NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  notifications_enabled boolean NOT NULL DEFAULT true,
  notification_frequency text NOT NULL DEFAULT 'Daily',
  notification_categories text[] NOT NULL DEFAULT ARRAY['Plan ready','Pantry check','Meal check-in'],
  quiet_start time NOT NULL DEFAULT '22:00',
  quiet_end time NOT NULL DEFAULT '07:00',
  time_zone text NOT NULL DEFAULT 'Asia/Kolkata',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memory_facts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  fact_key text NOT NULL,
  label text NOT NULL,
  value text NOT NULL,
  source text NOT NULL,
  safety_relevant boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, fact_key)
);

CREATE INDEX IF NOT EXISTS memory_facts_user_created_idx ON memory_facts(user_id, created_at);

CREATE TABLE IF NOT EXISTS user_ai_settings (
  user_id uuid PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE,
  cloud_ai_enabled boolean NOT NULL DEFAULT false,
  consent_updated_at timestamptz NOT NULL DEFAULT now()
);

-- Remove obsolete accounting and request-window tables from databases that
-- were migrated by an earlier AI prototype.
DROP TABLE IF EXISTS ai_usage_reservations;
DROP TABLE IF EXISTS ai_monthly_usage;
DROP TABLE IF EXISTS ai_request_windows;

