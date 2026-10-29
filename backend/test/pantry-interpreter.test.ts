import { afterEach, describe, expect, it, vi } from 'vitest';
import { PantryInterpreter } from '../src/pantry-interpreter.js';
import * as provider from '../src/nebius.js';
import type { Env, Principal } from '../src/types.js';
const user={userId:'u',role:'user',authSubject:'synthetic',authProvider:'google'} as Principal;
let consent=true;
const db={prepare:()=>({bind:()=>({first:async()=>({cloud_ai_enabled:+consent})})})} as unknown as D1Database;
const env={NEBIUS_API_KEY:'test'} as Env;
afterEach(()=>{vi.restoreAllMocks();consent=true;});
describe('pantry natural language drafts',()=>{
  it('requires consent without calling inference',async()=>{consent=false;const model=vi.spyOn(provider,'callNebius');await expect(new PantryInterpreter(db,env).interpret(user,'I have rice')).rejects.toThrow('cloud_ai_consent_required');expect(model).not.toHaveBeenCalled();});
  it('preserves multiple items and per-package amounts without mutating storage',async()=>{
    const operations=[{action:'save',name:'potato',amount:'1 kg'},{action:'save',name:'milk',amount:'2 cartons (1 litre each)'}];
    const model=vi.spyOn(provider,'callNebius').mockResolvedValue({text:JSON.stringify({needsClarification:false,operations}),inputTokens:1,outputTokens:1});
    const result=await new PantryInterpreter(db,env).interpret(user,'I have a kg of potato and 2 cartons of milk 1 litre each');
    expect(result.status).toBe('draft');expect(result.operations).toEqual(operations);expect(model.mock.calls[0][3]).toContain('1 litre each');
  });
  it.each([{operations:[{action:'save',name:'milk',amount:null}]},{operations:[{action:'save',name:'rice',amount:'1 kg'},{action:'remove',name:'rice',amount:null}]}])('rejects incomplete or duplicate drafts',async ({operations})=>{
    vi.spyOn(provider,'callNebius').mockResolvedValue({text:JSON.stringify({needsClarification:false,operations}),inputTokens:1,outputTokens:1});
    expect((await new PantryInterpreter(db,env).interpret(user,'synthetic')).status).toBe('clarification');
  });
  it('discards a draft after consent is revoked during inference',async()=>{
    vi.spyOn(provider,'callNebius').mockImplementation(async()=>{consent=false;return {text:'{"needsClarification":false,"operations":[{"action":"save","name":"rice","amount":"1 kg"}]}',inputTokens:1,outputTokens:1};});
    await expect(new PantryInterpreter(db,env).interpret(user,'rice')).rejects.toThrow('cloud_ai_consent_required');
  });
});
