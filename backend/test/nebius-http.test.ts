import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index.js';
import { D1UserRepository } from '../src/repository.js';
import type { Env } from '../src/types.js';

function env(consent = true): Env {
  const DB = { prepare: (sql: string) => ({ bind: () => ({ first: async () => sql.includes('cloud_ai_enabled') ? {cloud_ai_enabled: +consent} : {id:'test-user',role:'user'} }) }) } as unknown as D1Database;
  return {DB,APP_ENV:'development',DEV_AUTH_ENABLED:'true',DEV_USER_ID:'test-user',AI_DEFAULT_PROVIDER:'nebius',NEBIUS_API_KEY:'test-only'} as Env;
}
const request = (body: unknown = {task:'conversation',complexity:'routine',prompt:'A lunch idea'}) => new Request('https://api.test/v1/ai/respond',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
beforeEach(()=>{
  vi.spyOn(D1UserRepository.prototype,'getProfile').mockResolvedValue({acknowledged:true,allergies:[],otherAllergy:'',exclusions:'',healthContext:[],otherHealth:'',coverage:'Dinner only',eatingPattern:'Vegan',cookingMinutes:25,cuisines:['Indian'],otherCuisine:'',weeklyBudgetInr:3000} as any);
  vi.spyOn(D1UserRepository.prototype,'getPreferences').mockResolvedValue(null);
  vi.spyOn(D1UserRepository.prototype,'listMemory').mockResolvedValue([]);
});
afterEach(() => {vi.unstubAllGlobals();vi.restoreAllMocks();});

describe('Nebius HTTP contract', () => {
  it('requires real authentication in production', async () => {
    const response = await worker.fetch(request(),{...env(),APP_ENV:'production'});
    expect(response.status).toBe(401);
  });
  it('rejects consent and oversized input before inference', async () => {
    const fetch = vi.fn(); vi.stubGlobal('fetch',fetch);
    const refused = await worker.fetch(request(),env(false));
    expect(refused.status).toBe(403);
    const oversized = await worker.fetch(request({task:'conversation',complexity:'routine',prompt:'x'.repeat(12001)}),env());
    expect(oversized.status).toBe(400);
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each([[429,429,'ai_provider_rate_limited'],[401,503,'ai_provider_unavailable'],[500,502,'ai_provider_request_failed']])('maps upstream HTTP %s into sanitized HTTP %s', async (upstream,status,code) => {
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response('private payload',{status:Number(upstream)})));
    const response = await worker.fetch(request(),env());
    expect(response.status).toBe(status);
    expect(await response.json()).toEqual({error:code});
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
  it('maps timeout to 504 and malformed output to 502', async () => {
    vi.stubGlobal('fetch',vi.fn().mockRejectedValue(new DOMException('private details','TimeoutError')));
    const timeout = await worker.fetch(request(),env());
    expect(timeout.status).toBe(504);
    expect(await timeout.json()).toEqual({error:'ai_provider_timeout'});
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue(Response.json({choices:[]})));
    const invalid = await worker.fetch(request(),env());
    expect(invalid.status).toBe(502);
    expect(await invalid.json()).toEqual({error:'ai_provider_invalid_response'});
  });
});
