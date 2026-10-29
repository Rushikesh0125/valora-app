CREATE TABLE meal_plan_proposals (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  base_payload TEXT NOT NULL CHECK(json_valid(base_payload)),
  next_payload TEXT NOT NULL CHECK(json_valid(next_payload)),
  fingerprint TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX meal_plan_proposals_user ON meal_plan_proposals(user_id);
