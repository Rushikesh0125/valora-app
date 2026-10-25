import { createRemoteJWKSet, importJWK, SignJWT, jwtVerify, type JWK } from "jose";
import type { Env, Principal } from "./types.js";
import { D1UserRepository } from "./repository.js";

const ACCESS_TOKEN_SECONDS = 15 * 60;
const REFRESH_TOKEN_SECONDS = 30 * 24 * 60 * 60;
const AUTH_TRANSACTION_SECONDS = 10 * 60;
const APP_CODE_SECONDS = 2 * 60;
const API_AUDIENCE = "valora-api";
const OPENAI_ISSUER = "https://auth.openai.com";
const OPENAI_AUTHORIZATION_ENDPOINT = "https://auth.openai.com/api/accounts/authorize";
const OPENAI_TOKEN_ENDPOINT = "https://auth.openai.com/api/accounts/oauth/token";
const GOOGLE_ISSUER = "https://accounts.google.com";
const GOOGLE_AUTHORIZATION_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";
const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
const jwksByProvider = new Map<string, ReturnType<typeof createRemoteJWKSet>>();
const signingKeys = new Map<string, Promise<CryptoKey>>();

type Provider = "google" | "openai";

export class IdentityConfigurationError extends Error {}
export class IdentityExchangeError extends Error {}

export async function publicJwks(env: Env): Promise<{ keys: JWK[] }> {
  const privateJwk = readPrivateJwk(env);
  const { d: _privatePart, key_ops: _keyOps, ...publicJwk } = privateJwk;
  return { keys: [{ ...publicJwk, alg: "ES256", use: "sig" }] };
}

export async function startIdentitySignIn(provider: Provider, clientState: string, db: D1Database, env: Env, requestUrl: URL): Promise<string> {
  const cfg = providerConfig(provider, env, requestUrl);
  mobileRedirectUri(env);
  const state = randomToken(32);
  const nonce = randomToken(32);
  const codeVerifier = randomToken(48);
  const codeChallenge = await sha256Base64Url(codeVerifier);
  await db.prepare("DELETE FROM auth_oauth_transactions WHERE expires_at <= unixepoch()").run();
  await db.prepare("DELETE FROM auth_app_codes WHERE expires_at <= unixepoch()").run();
  await db.prepare(
    `INSERT INTO auth_oauth_transactions (state_hash, provider, nonce, code_verifier, redirect_uri, client_state, expires_at)
     VALUES (?,?,?,?,?,?,unixepoch() + ?)`,
  ).bind(await sha256Base64Url(state), provider, nonce, codeVerifier, cfg.redirectUri, clientState, AUTH_TRANSACTION_SECONDS).run();
  const authUrl = new URL(cfg.authorizationEndpoint);
  authUrl.search = new URLSearchParams({
    client_id: cfg.clientId,
    redirect_uri: cfg.redirectUri,
    response_type: "code",
    scope: "openid profile email",
    state,
    nonce,
    code_challenge: codeChallenge,
    code_challenge_method: "S256",
  }).toString();
  return authUrl.toString();
}

export async function completeIdentityCallback(provider: Provider, code: string, state: string, db: D1Database, env: Env, requestUrl: URL): Promise<string> {
  const cfg = providerConfig(provider, env, requestUrl);
  const transaction = await db.prepare(
    `DELETE FROM auth_oauth_transactions WHERE state_hash=? AND provider=? AND expires_at > unixepoch()
     RETURNING nonce, code_verifier, redirect_uri, client_state`,
  ).bind(await sha256Base64Url(state), provider).first<{nonce:string;code_verifier:string;redirect_uri:string;client_state:string}>();
  if (!transaction) throw new IdentityExchangeError("oauth_transaction_invalid");
  const identityToken = await exchangeCode(provider, code, transaction.code_verifier, transaction.redirect_uri, cfg);
  const identity = await verifyProviderIdentity(provider, identityToken, transaction.nonce, cfg.clientId);
  const appCode = randomToken(32);
  await db.prepare(
    `INSERT INTO auth_app_codes (code_hash, client_state_hash, auth_provider, auth_subject, email, expires_at)
     VALUES (?,?,?,?,?,unixepoch() + ?)`,
  ).bind(await sha256Base64Url(appCode), await sha256Base64Url(transaction.client_state), provider, identity.subject, identity.email, APP_CODE_SECONDS).run();
  const redirect = mobileRedirectUri(env);
  redirect.search = new URLSearchParams({ code: appCode, state: transaction.client_state }).toString();
  return redirect.toString();
}

export async function cancelIdentitySignIn(provider: Provider, state: string, db: D1Database): Promise<string | null> {
  const row = await db.prepare(
    "DELETE FROM auth_oauth_transactions WHERE state_hash=? AND provider=? RETURNING client_state",
  ).bind(await sha256Base64Url(state), provider).first<{client_state:string}>();
  return row?.client_state ?? null;
}

export async function exchangeAppCode(code: string, clientState: string, db: D1Database, env: Env): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
  const row = await db.prepare(
    `DELETE FROM auth_app_codes WHERE code_hash=? AND client_state_hash=? AND expires_at > unixepoch()
     RETURNING auth_provider, auth_subject, email`,
  ).bind(await sha256Base64Url(code), await sha256Base64Url(clientState)).first<{auth_provider:Provider;auth_subject:string;email:string|null}>();
  if (!row) throw new IdentityExchangeError("auth_code_invalid");
  const principal = await new D1UserRepository(db).resolvePrincipal({
    userId: "", role: "user", authProvider: row.auth_provider, authSubject: row.auth_subject,
    ...(typeof row.email === "string" ? { email: row.email } : {}),
  });
  return createSession(principal, db, env);
}

export async function rotateRefreshToken(refreshToken: string, db: D1Database, env: Env): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
  const session = await db.prepare(
    `UPDATE auth_refresh_sessions SET revoked_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')
     WHERE token_hash=? AND revoked_at IS NULL AND expires_at > unixepoch() RETURNING user_id`,
  ).bind(await sha256Base64Url(refreshToken)).first<{user_id:string}>();
  if (!session) throw new IdentityExchangeError("refresh_token_invalid");
  const user = await db.prepare(
    `SELECT id, auth_provider, auth_subject, email, role FROM app_users WHERE id=?`,
  ).bind(session.user_id).first<{id:string;auth_provider:Provider;auth_subject:string;email:string|null;role:"user"|"admin"}>();
  if (!user || !["google", "openai"].includes(user.auth_provider)) throw new IdentityExchangeError("refresh_identity_unavailable");
  const principal: Principal = { userId:user.id, role:user.role, authProvider:user.auth_provider, authSubject:user.auth_subject, ...(user.email ? {email:user.email} : {}) };
  return createSession(principal, db, env);
}

export async function revokeRefreshToken(refreshToken: string, db: D1Database): Promise<void> {
  await db.prepare("UPDATE auth_refresh_sessions SET revoked_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE token_hash=? AND revoked_at IS NULL").bind(await sha256Base64Url(refreshToken)).run();
}

function providerConfig(provider: Provider, env: Env, requestUrl?: URL) {
  const clientId = provider === "google" ? env.GOOGLE_CLIENT_ID : env.OPENAI_CLIENT_ID;
  const configuredCallback = provider === "google" ? env.GOOGLE_CALLBACK_URL : env.OPENAI_CALLBACK_URL;
  if (!clientId || !configuredCallback) throw new IdentityConfigurationError(`${provider}_oauth_not_configured`);
  if (provider === "google" && !env.GOOGLE_CLIENT_SECRET) throw new IdentityConfigurationError("google_oauth_secret_not_configured");
  let callback: URL;
  try { callback = new URL(configuredCallback); } catch { throw new IdentityConfigurationError(`${provider}_callback_invalid`); }
  if (callback.protocol !== "https:" && !(env.APP_ENV === "development" && callback.protocol === "http:")) throw new IdentityConfigurationError(`${provider}_callback_must_use_https`);
  if (callback.pathname !== `/v1/auth/${provider}/callback` || callback.search || callback.hash) throw new IdentityConfigurationError(`${provider}_callback_path_invalid`);
  if (requestUrl && callback.origin !== requestUrl.origin) throw new IdentityConfigurationError(`${provider}_callback_origin_mismatch`);
  return {
    clientId, clientSecret:provider === "google" ? env.GOOGLE_CLIENT_SECRET : undefined, redirectUri:callback.toString(),
    authorizationEndpoint:provider === "google" ? GOOGLE_AUTHORIZATION_ENDPOINT : OPENAI_AUTHORIZATION_ENDPOINT,
    tokenEndpoint:provider === "google" ? GOOGLE_TOKEN_ENDPOINT : OPENAI_TOKEN_ENDPOINT,
  };
}

function isAllowedMobileRedirect(url: URL): boolean {
  return url.protocol === "valora:" && url.hostname === "auth" && url.pathname === "/callback";
}

function mobileRedirectUri(env: Env): URL {
  let redirect: URL;
  try { redirect = new URL(env.MOBILE_AUTH_REDIRECT_URI || ""); }
  catch { throw new IdentityConfigurationError("mobile_auth_redirect_uri_invalid"); }
  if (!isAllowedMobileRedirect(redirect)) throw new IdentityConfigurationError("mobile_auth_redirect_uri_invalid");
  return redirect;
}

async function exchangeCode(provider: Provider, code: string, verifier: string, redirectUri: string, cfg: ReturnType<typeof providerConfig>): Promise<string> {
  const body = new URLSearchParams({ grant_type:"authorization_code", code, redirect_uri:redirectUri, client_id:cfg.clientId, code_verifier:verifier });
  const headers = new Headers({ accept:"application/json", "content-type":"application/x-www-form-urlencoded" });
  // Google uses a confidential web client; the ChatGPT identity client uses public PKCE.
  if (provider === "google") body.set("client_secret", cfg.clientSecret ?? "");
  const response = await fetch(cfg.tokenEndpoint, { method:"POST", headers, body });
  if (!response.ok) throw new IdentityExchangeError(`${provider}_token_exchange_failed`);
  const json = await response.json() as { id_token?: unknown };
  if (typeof json.id_token !== "string") throw new IdentityExchangeError(`${provider}_id_token_missing`);
  return json.id_token;
}

async function verifyProviderIdentity(provider: Provider, idToken: string, nonce: string, clientId: string): Promise<{subject:string; email:string|null}> {
  const issuer = provider === "google" ? GOOGLE_ISSUER : OPENAI_ISSUER;
  const jwksUrl = provider === "google" ? GOOGLE_JWKS_URL : "https://auth.openai.com/.well-known/jwks.json";
  let jwks = jwksByProvider.get(jwksUrl);
  if (!jwks) { jwks = createRemoteJWKSet(new URL(jwksUrl)); jwksByProvider.set(jwksUrl, jwks); }
  let payload;
  try { ({ payload } = await jwtVerify(idToken, jwks, { issuer, audience:clientId, algorithms:["RS256"] })); }
  catch { throw new IdentityExchangeError(`${provider}_identity_token_invalid`); }
  if (payload.nonce !== nonce) throw new IdentityExchangeError(`${provider}_identity_nonce_invalid`);
  if (typeof payload.sub !== "string" || !payload.sub) throw new IdentityExchangeError(`${provider}_identity_subject_missing`);
  const verifiedEmail = payload.email_verified === true && typeof payload.email === "string";
  return { subject:payload.sub, email:verifiedEmail ? payload.email as string : null };
}

async function createSession(principal: Principal, db: D1Database, env: Env) {
  const accessToken = await signAccessToken(principal, env);
  const refreshToken = randomToken(48);
  await db.prepare(
    `INSERT INTO auth_refresh_sessions (id, user_id, token_hash, expires_at)
     VALUES (?,?,?,unixepoch() + ?)`,
  ).bind(crypto.randomUUID(), principal.userId, await sha256Base64Url(refreshToken), REFRESH_TOKEN_SECONDS).run();
  return { accessToken, refreshToken, expiresIn:ACCESS_TOKEN_SECONDS };
}

async function signAccessToken(principal: Principal, env: Env): Promise<string> {
  if (!env.JWT_ISSUER) throw new IdentityConfigurationError("jwt_issuer_not_configured");
  validateIssuer(env.JWT_ISSUER, env.APP_ENV);
  const key = await signingKey(env);
  const jwk = readPrivateJwk(env);
  return new SignJWT({ identity_provider:principal.authProvider, ...(principal.email ? {email:principal.email} : {}) })
    .setProtectedHeader({ alg:"ES256", typ:"JWT", kid:typeof jwk.kid === "string" ? jwk.kid : "valora-es256" })
    .setIssuer(env.JWT_ISSUER).setAudience(API_AUDIENCE).setSubject(principal.authSubject)
    .setIssuedAt().setExpirationTime(`${ACCESS_TOKEN_SECONDS}s`).setJti(crypto.randomUUID()).sign(key);
}

function signingKey(env: Env): Promise<CryptoKey> {
  const privateJwk = readPrivateJwk(env);
  const raw = JSON.stringify(privateJwk);
  let key = signingKeys.get(raw);
  if (!key) { key = importJWK(privateJwk, "ES256") as Promise<CryptoKey>; signingKeys.set(raw, key); }
  return key;
}

function readPrivateJwk(env: Env): JWK {
  if (!env.AUTH_SIGNING_PRIVATE_JWK) throw new IdentityConfigurationError("auth_signing_key_not_configured");
  try {
    const jwk = JSON.parse(env.AUTH_SIGNING_PRIVATE_JWK) as JWK;
    if (jwk.kty !== "EC" || jwk.crv !== "P-256" || typeof jwk.d !== "string" || typeof jwk.x !== "string" || typeof jwk.y !== "string") throw new Error();
    return jwk;
  } catch { throw new IdentityConfigurationError("auth_signing_key_invalid"); }
}

function validateIssuer(issuer: string, appEnv: string): void {
  let url: URL;
  try { url = new URL(issuer); } catch { throw new IdentityConfigurationError("jwt_issuer_invalid"); }
  if (url.origin !== issuer || url.pathname !== "/" || url.search || url.hash || (appEnv !== "development" && url.protocol !== "https:")) {
    throw new IdentityConfigurationError("jwt_issuer_must_be_an_origin");
  }
}

function randomToken(byteLength: number): string {
  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/g,"");
}

async function sha256Base64Url(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  let binary = "";
  for (const byte of new Uint8Array(digest)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/g,"");
}
