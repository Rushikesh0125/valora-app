import { afterEach, describe, expect, it, vi } from 'vitest';
import { ContextAgent } from '../src/context-agent.js';
import * as provider from '../src/nebius.js';
import type { Env, Principal } from '../src/types.js';
const user={userId:'u',role:'user',authProvider:'google',authSubject:'synthetic'} as Principal;
let consent=true;
const db={prepare:()=>({bind:()=>({first:async()=>({cloud_ai_enabled:+consent})})})} as unknown as D1Database;
const env={NEBIUS_API_KEY:'test'} as Env;
function answer(actions:{kind:string;value:string}[]){return {text:JSON.stringify({needsClarification:false,actions}),inputTokens:1,outputTokens:1};}
afterEach(()=>{vi.restoreAllMocks();consent=true;});
describe('context-action proposals',()=>{
 it('proposes reported symptoms and meal style without saving them',async()=>{
  vi.spyOn(provider,'callNebius').mockResolvedValue(answer([{kind:'temporary_health',value:'fever'},{kind:'temporary_health',value:'cold'},{kind:'meal_style',value:'warm'}]));
  const result=await new ContextAgent(db,env).propose(user,'I have some fever and cold today');
  expect(result.contextActions).toHaveLength(3);expect(result.text).toContain('confirm');
 });
 it('weather cold cannot be recorded as a health report even if the model suggests it',async()=>{
  vi.spyOn(provider,'callNebius').mockResolvedValue(answer([{kind:'temporary_health',value:'cold'}]));
  expect((await new ContextAgent(db,env).propose(user,'It is very cold tonight')).contextActions).toBeUndefined();
  vi.mocked(provider.callNebius).mockResolvedValue(answer([{kind:'meal_style',value:'warm'}]));
  expect((await new ContextAgent(db,env).propose(user,'It is very cold tonight')).contextActions).toEqual([{kind:'meal_style',value:'warm'}]);
 });
 it('canonicalizes known food restrictions and rejects unsupported allergies',async()=>{
  vi.spyOn(provider,'callNebius').mockResolvedValue(answer([{kind:'add_allergy',value:'peanuts'},{kind:'avoid_food',value:'brinjal'}]));
  expect((await new ContextAgent(db,env).propose(user,'I am allergic to peanuts and do not eat brinjal')).contextActions).toEqual([{kind:'add_allergy',value:'peanut'},{kind:'avoid_food',value:'eggplant'}]);
  vi.mocked(provider.callNebius).mockResolvedValue(answer([{kind:'add_allergy',value:'unknown ingredient'}]));
  expect((await new ContextAgent(db,env).propose(user,'allergy')).contextActions).toBeUndefined();
 });
 it('requires cloud consent and rechecks it after extraction',async()=>{
  const model=vi.spyOn(provider,'callNebius');consent=false;
  await expect(new ContextAgent(db,env).propose(user,'I have a cold')).rejects.toThrow('cloud_ai_consent_required');expect(model).not.toHaveBeenCalled();
  consent=true;model.mockImplementation(async()=>{consent=false;return answer([{kind:'meal_style',value:'warm'}]);});
  await expect(new ContextAgent(db,env).propose(user,'cold tonight')).rejects.toThrow('cloud_ai_consent_required');
 });
});
