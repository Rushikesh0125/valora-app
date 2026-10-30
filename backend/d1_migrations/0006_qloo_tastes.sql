CREATE TABLE qloo_tastes (user_id TEXT PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE, selections TEXT NOT NULL);
CREATE TABLE qloo_resolved (user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE, signal_id TEXT NOT NULL, kind TEXT NOT NULL, label TEXT NOT NULL, expires_at INTEGER NOT NULL, PRIMARY KEY(user_id,signal_id));
CREATE TABLE qloo_rate (user_id TEXT NOT NULL, bucket INTEGER NOT NULL, count INTEGER NOT NULL, PRIMARY KEY(user_id,bucket));
