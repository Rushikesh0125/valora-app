CREATE TABLE first_day_plans (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  request_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('generating', 'ready', 'failed')),
  fingerprint TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  deadline_at INTEGER NOT NULL,
  lease_until INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 1,
  payload TEXT CHECK (payload IS NULL OR json_valid(payload)),
  error_code TEXT
);
