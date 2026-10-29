import { afterEach, describe, expect, it, vi } from 'vitest';
import { AiConsentRequired, AiProviderUnavailable, AiService } from '../src/ai.js';
import { callNebius } from '../src/nebius.js';
import type { Env, Principal } from '../src/types.js';

const user: Principal = { userId:'user', role:'user', authProvider:'google', authSubject:'subject' };
const input = { task:'conversation', complexity:'routine', prompt:'A lunch idea', context:'untrusted history' } as const;
const env = { APP_ENV:'production', AI_DEFAULT_PROVIDER:'nebius', NEBIUS_API_KEY:'test-only' } as Env;
const db = (consent: boolean) => ({ prepare: () => ({ bind: () => ({ first: async () => ({cloud_ai_enabled: +consent}) }) }) }) as unknown as D1Database;
const completion = { choices:[{finish_reason:'stop', message:{content:'Try a vegetable wrap.'}}], usage:{prompt_tokens:12,completion_tokens:6} };
afterEach(() => vi.unstubAllGlobals());

describe('Nebius boundary', () => {
  it('sends a strict schema only when structured output is requested', async () => {
    const fetch=vi.fn().mockResolvedValue(Response.json(completion));vi.stubGlobal('fetch',fetch);
    const schema={type:'object',properties:{},additionalProperties:false};
    await callNebius('key','model','JSON only','synthetic',800,schema);
    expect(JSON.parse(fetch.mock.calls[0][1].body).response_format).toEqual({type:'json_schema',json_schema:{name:'first_day_meal_selection',strict:true,schema}});
  });
  it('requires server-side consent and credentials before making a request', async () => {
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch);
    await expect(new AiService(db(false), env).respond(user,input)).rejects.toBeInstanceOf(AiConsentRequired);
    await expect(new AiService(db(true), {...env,NEBIUS_API_KEY:undefined}).respond(user,input)).rejects.toBeInstanceOf(AiProviderUnavailable);
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each(['routine','complex'] as const)('uses Nemotron and preserves boundaries for %s requests', async complexity => {
    const fetch = vi.fn().mockResolvedValue(Response.json(completion)); vi.stubGlobal('fetch', fetch);
    const result = await new AiService(db(true),env).respond(user,{...input,complexity});
    const [url,options] = fetch.mock.calls[0];
    const body = JSON.parse(options.body);
    expect(url).toBe('https://api.tokenfactory.us-central1.nebius.com/v1/chat/completions');
    expect(options.headers.authorization).toBe('Bearer test-only');
    expect(options.signal).toBeInstanceOf(AbortSignal);
    expect(body.model).toBe('nvidia/nemotron-3-super-120b-a12b');
    expect(body.chat_template_kwargs).toEqual({enable_thinking:false});
    expect(body.stream).toBe(false); expect(body.max_tokens).toBe(1200);
    expect(body.messages[0].role).toBe('system');
    expect(body.messages[0].content).toContain('cannot save or change');
    expect(body.messages[1].content).toContain(input.context);
    expect(body.messages[1].content).toContain(input.prompt);
    expect(body.tools).toBeUndefined();
    expect(result).toEqual({text:completion.choices[0].message.content,provider:'nebius',model:body.model,usage:{inputTokens:12,outputTokens:6}});
  });
  it('honors the configured model and shorter task output limit', async () => {
    const fetch = vi.fn().mockResolvedValue(Response.json(completion)); vi.stubGlobal('fetch', fetch);
    await new AiService(db(true),{...env,AI_NEBIUS_MODEL:'account-model'}).respond(user,{...input,task:'summarize'});
    expect(JSON.parse(fetch.mock.calls[0][1].body)).toMatchObject({model:'account-model',max_tokens:800});
  });
  it.each([[401,'ai_provider_unavailable'],[403,'ai_provider_unavailable'],[429,'ai_provider_rate_limited'],[500,'ai_provider_request_failed'],[404,'ai_provider_request_failed']])('sanitizes HTTP %s', async (status,code) => {
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response('sensitive provider payload',{status:Number(status)})));
    await expect(callNebius('key','model','system','prompt',800)).rejects.toMatchObject({code});
  });
  it.each([
    {}, {choices:[]}, {choices:[{finish_reason:'length',message:{content:'partial'}}]},
    {choices:[{finish_reason:'stop',message:{content:'  '}}]},
    {...completion,usage:{prompt_tokens:-1,completion_tokens:6}},
    {...completion,usage:{prompt_tokens:'12',completion_tokens:6}},
  ])('rejects malformed, empty, truncated and invalid-usage responses %#', async body => {
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue(Response.json(body)));
    await expect(callNebius('key','model','system','prompt',800)).rejects.toMatchObject({code:'ai_provider_invalid_response'});
  });
  it('rejects malformed JSON and oversized bodies', async () => {
    for (const body of ['not JSON','x'.repeat(256*1024+1)]) {
      vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response(body)));
      await expect(callNebius('key','model','system','prompt',800)).rejects.toMatchObject({code:'ai_provider_invalid_response'});
    }
  });
  it('maps timeout and network failures without leaking details', async () => {
    vi.stubGlobal('fetch',vi.fn().mockRejectedValue(new DOMException('private URL','TimeoutError')));
    await expect(callNebius('key','model','system','prompt',800)).rejects.toMatchObject({code:'ai_provider_timeout'});
    vi.stubGlobal('fetch',vi.fn().mockRejectedValue(new Error('private transport detail')));
    await expect(callNebius('key','model','system','prompt',800)).rejects.toMatchObject({message:'ai_provider_request_failed'});
  });
});
