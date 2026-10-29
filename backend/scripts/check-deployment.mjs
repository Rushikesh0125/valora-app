import { readFileSync } from 'node:fs';

const config = JSON.parse(readFileSync(new URL('../wrangler.jsonc', import.meta.url), 'utf8'));
const db = config.d1_databases?.[0];
const vars = config.vars ?? {};
const errors = [];
if (config.name !== 'valora-nebius-api') errors.push('Worker must be valora-nebius-api.');
if (db?.database_name !== 'valora-nebius-db' || db?.binding !== 'DB') errors.push('Use the independent valora-nebius-db binding.');
if (!/^[0-9a-f-]{36}$/i.test(db?.database_id ?? '') || db.database_id === 'f44fab9c-e79e-421d-a822-53749eaa6219') errors.push('Provision a NEW Nebius D1 database and set its ID.');
if (vars.APP_ENV !== 'production' || vars.DEV_AUTH_ENABLED === 'true') errors.push('Production requires real authentication.');
if (vars.AI_DEFAULT_PROVIDER !== 'nebius') errors.push('The submission provider must be Nebius.');
if (!/^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$/.test(vars.GOOGLE_CLIENT_ID ?? '')) errors.push('Configure a Google Web OAuth client.');
if (vars.MOBILE_AUTH_REDIRECT_URI !== 'valoranebius://auth/callback') errors.push('Use the variant mobile callback scheme.');
try {
  const issuer = new URL(vars.JWT_ISSUER);
  const callback = new URL(vars.GOOGLE_CALLBACK_URL);
  if (issuer.protocol !== 'https:' || !issuer.hostname.startsWith('valora-nebius-api.') || callback.origin !== issuer.origin || callback.pathname !== '/v1/auth/google/callback' || callback.search || callback.hash) errors.push('Configure matching HTTPS Nebius issuer and OAuth callback URLs.');
} catch { errors.push('Configure valid issuer and callback URLs.'); }
if (errors.length) {
  console.error('Deployment blocked:\n' + errors.map(error => `- ${error}`).join('\n'));
  process.exitCode = 1;
} else console.log('Nebius deployment targets passed isolation checks. Verify secrets separately.');
