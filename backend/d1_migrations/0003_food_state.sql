CREATE TABLE food_states (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  version INTEGER NOT NULL CHECK (version > 0),
  payload TEXT NOT NULL CHECK (json_valid(payload)),
  mutation_id TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
