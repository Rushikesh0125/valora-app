import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index.js';
import type { Env } from '../src/types.js';

const base = 'https://valora-nebius-api.jadhav-rushikesh-ggl.workers.dev';
function config(scheme = 'valoranebius'): Env {
  const statement = { run: vi.fn().mockResolvedValue({success:true}), first: vi.fn().mockResolvedValue({client_state:'client-state'}) };
  const DB = { prepare: () => ({...statement,bind: () => statement}) } as unknown as D1Database;
  return {DB,APP_ENV:'production',GOOGLE_CLIENT_ID:'shared-google-client',GOOGLE_CLIENT_SECRET:'test-only',GOOGLE_CALLBACK_URL:base+'/v1/auth/google/callback',MOBILE_AUTH_REDIRECT_URI:scheme+'://auth/callback'} as Env;
}
describe('Nebius OAuth callback isolation', () => {
  it('starts Google OAuth using the shared client and independent HTTPS callback', async () => {
    const response = await worker.fetch(new Request(base+'/v1/auth/google/start',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({clientState:'a'.repeat(43)})}),config());
    expect(response.status).toBe(200);
    const body = await response.json() as {data:{authorizationUrl:string}};
    const url = new URL(body.data.authorizationUrl);
    expect(url.searchParams.get('client_id')).toBe('shared-google-client');
    expect(url.searchParams.get('redirect_uri')).toBe(base+'/v1/auth/google/callback');
    expect(url.searchParams.get('code_challenge_method')).toBe('S256');
    expect(url.searchParams.has('client_secret')).toBe(false);
  });
  it('returns cancelled sign-in to the Nebius app', async () => {
    const response = await worker.fetch(new Request(base+'/v1/auth/google/callback?error=access_denied&state='+'b'.repeat(43)),config());
    expect(response.status).toBe(302);
    const location = new URL(response.headers.get('location')!);
    expect(location.protocol).toBe('valoranebius:');
    expect(location.hostname).toBe('auth');
    expect(location.pathname).toBe('/callback');
    expect(location.searchParams.get('state')).toBe('client-state');
  });
  it('rejects a configuration that redirects into canonical Valora', async () => {
    const response = await worker.fetch(new Request(base+'/v1/auth/google/start',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({clientState:'a'.repeat(43)})}),config('valora'));
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({error:'authentication_unavailable'});
  });
});
