import { createLocalJWKSet, jwtVerify, type JWK } from "jose";
import type { Env, Principal } from "./types.js";

const jwksByKey = new Map<string, ReturnType<typeof createLocalJWKSet>>();

export async function authenticate(request: Request, env: Env): Promise<Principal | null> {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    if (env.APP_ENV === "development" && env.DEV_AUTH_ENABLED === "true") {
      const userId = env.DEV_USER_ID;
      if (!userId) throw new Error("dev_auth_user_missing");
      return { userId, role: "user", authSubject: `dev:${userId}`, authProvider: "development" };
    }
    return null;
  }
  if (!env.JWT_ISSUER) throw new Error("jwt_auth_not_configured");
  if (!env.AUTH_SIGNING_PRIVATE_JWK) throw new Error("auth_signing_key_not_configured");
  let privateJwk: JWK;
  try {
    privateJwk = JSON.parse(env.AUTH_SIGNING_PRIVATE_JWK) as JWK;
    if (privateJwk.kty !== "EC" || privateJwk.crv !== "P-256" ||
        typeof privateJwk.d !== "string" || typeof privateJwk.x !== "string" ||
        typeof privateJwk.y !== "string") throw new Error();
  } catch {
    throw new Error("auth_signing_key_invalid");
  }
  const keyId = typeof privateJwk.kid === "string" ? privateJwk.kid : "valora-es256";
  const cacheKey = `${keyId}:${privateJwk.x}:${privateJwk.y}`;
  let jwks = jwksByKey.get(cacheKey);
  if (!jwks) {
    const { d: _privatePart, key_ops: _keyOps, ...publicJwk } = privateJwk;
    jwks = createLocalJWKSet({ keys: [{ ...publicJwk, alg: "ES256", use: "sig" }] });
    jwksByKey.set(cacheKey, jwks);
  }
  const { payload } = await jwtVerify(authorization.slice(7), jwks, { issuer: env.JWT_ISSUER, audience: "valora-api", algorithms: ["ES256"] });
  const subject = typeof payload.sub === "string" ? payload.sub : "";
  const authProvider = typeof payload.identity_provider === "string" ? payload.identity_provider : "";
  if (!subject || !["google", "openai"].includes(authProvider)) throw new Error("jwt_identity_claims_missing");
  return { userId: "", role: "user", authSubject: subject, authProvider, email: typeof payload.email === "string" ? payload.email : undefined };
}
