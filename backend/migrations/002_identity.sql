CREATE TABLE IF NOT EXISTS auth_oauth_transactions (
  state_hash text PRIMARY KEY,
  provider text NOT NULL CHECK (provider IN ('google','openai')),
  nonce text NOT NULL,
  code_verifier text NOT NULL,
  redirect_uri text NOT NULL,
  client_state text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_oauth_transactions_expiry_idx ON auth_oauth_transactions(expires_at);

CREATE TABLE IF NOT EXISTS auth_app_codes (
  code_hash text PRIMARY KEY,
  client_state_hash text NOT NULL,
  auth_provider text NOT NULL CHECK (auth_provider IN ('google','openai')),
  auth_subject text NOT NULL,
  email text,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_app_codes_expiry_idx ON auth_app_codes(expires_at);

CREATE TABLE IF NOT EXISTS auth_refresh_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_refresh_sessions_user_idx ON auth_refresh_sessions(user_id);
