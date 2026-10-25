import { afterEach, describe, expect, it, vi } from 'vitest';
import { AiConsentRequired, AiProviderUnavailable, AiService } from '../src/ai.js';
import type { Env, Principal } from '../src/types.js';

const user: Principal = { userId:'user', role:'user', authProvider:'google', authSubject:'subject' };
function db(consent: boolean) {
  return { prepare: () => ({ bind: () => ({ first: async () => ({cloud_ai_enabled:consent ? 1 : 0}) }) }) } as unknown as D1Database;
}
function env(provider: 'openai' | 'gemini' = 'openai'): Env {
  return { APP_ENV:'production', AI_DEFAULT_PROVIDER:provider, OPENAI_API_KEY:'test-key', GEMINI_API_KEY:'test-key' } as Env;
}
const input = { task:'conversation', complexity:'routine', prompt:'Help with lunch', context:'{"history":[]}' } as const;
afterEach(() => vi.unstubAllGlobals());

describe('AI provider boundary', () => {
  it('does not contact a provider without stored cloud consent', async () => {
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch);
    await expect(new AiService(db(false), env()).respond(user, input)).rejects.toBeInstanceOf(AiConsentRequired);
    expect(fetch).not.toHaveBeenCalled();
  });

  it('sends bounded text/context with storage disabled and no action tools', async () => {
    const fetch = vi.fn().mockResolvedValue(Response.json({output:[{content:[{text:'Practical advice'}]}],usage:{input_tokens:20,output_tokens:5}}));
    vi.stubGlobal('fetch', fetch);
    const result = await new AiService(db(true), env()).respond(user, input);
    const body = JSON.parse(fetch.mock.calls[0][1].body as string);
    expect(body.store).toBe(false);
    expect(body.model).toBe('gpt-6-luna');
    expect(body.reasoning.effort).toBe('none');
    expect(body.tools).toBeUndefined();
    expect(body.instructions).toContain('cannot save or change');
    expect(body.input).toContain(input.context);
    expect(body.input).toContain(input.prompt);
    expect(result.text).toBe('Practical advice');
    expect(result.usage.outputTokens).toBe(5);
  });

  it('supports Gemini with the same context and analytical instructions', async () => {
    const fetch = vi.fn().mockResolvedValue(Response.json({candidates:[{content:{parts:[{text:'A useful reply'}]}}]}));
    vi.stubGlobal('fetch', fetch);
    const result = await new AiService(db(true), env('gemini')).respond(user, input);
    const body = JSON.parse(fetch.mock.calls[0][1].body as string);
    expect(body.systemInstruction.parts[0].text).toContain('cannot save or change');
    expect(body.contents[0].parts[0].text).toContain(input.context);
    expect(result.provider).toBe('gemini');
  });

  it('uses Luna for complex requests as well', async () => {
    const fetch = vi.fn().mockResolvedValue(Response.json({output_text:'A comparison'}));
    vi.stubGlobal('fetch', fetch);
    await new AiService(db(true), env()).respond(user, {...input, complexity:'complex'});
    expect(JSON.parse(fetch.mock.calls[0][1].body as string).model).toBe('gpt-6-luna');
  });

  it('reports missing credentials before making a provider call', async () => {
    const config = env(); delete config.OPENAI_API_KEY;
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch);
    await expect(new AiService(db(true), config).respond(user, input)).rejects.toBeInstanceOf(AiProviderUnavailable);
    expect(fetch).not.toHaveBeenCalled();
  });
});
