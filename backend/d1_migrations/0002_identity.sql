CREATE TABLE auth_oauth_transactions (
  state_hash TEXT PRIMARY KEY NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('google','openai')),
  nonce TEXT NOT NULL,
  code_verifier TEXT NOT NULL,
  redirect_uri TEXT NOT NULL,
  client_state TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX auth_oauth_transactions_expiry_idx ON auth_oauth_transactions(expires_at);

CREATE TABLE auth_app_codes (
  code_hash TEXT PRIMARY KEY NOT NULL,
  client_state_hash TEXT NOT NULL,
  auth_provider TEXT NOT NULL CHECK (auth_provider IN ('google','openai')),
  auth_subject TEXT NOT NULL,
  email TEXT,
  expires_at INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX auth_app_codes_expiry_idx ON auth_app_codes(expires_at);

CREATE TABLE auth_refresh_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL,
  revoked_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX auth_refresh_sessions_user_idx ON auth_refresh_sessions(user_id);
