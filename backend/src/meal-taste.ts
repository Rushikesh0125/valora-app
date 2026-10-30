import {z} from 'zod';
import {QlooClient,QlooError,type Signal} from './qloo.js';
import type {StarterRecipe} from './starter-recipes.js';
import type {Env,ProfileRecord} from './types.js';

const supported=['indian','italian','chinese'] as const;
const cuisineEvidence=z.object({id:z.string().max(200),label:z.string().max(200),cuisine:z.enum(supported)}).strict();
export const mealTasteSchema=z.object({
  provider:z.literal('qloo'),
  affinities:z.array(cuisineEvidence).min(1).max(3),
  selectedCuisines:z.array(cuisineEvidence).max(3).optional(),
}).strict();
export type MealTaste=z.infer<typeof mealTasteSchema>;

/** Only public cuisine IDs projected from saved preferences leave the Worker; private profile fields do not. */
export async function mealSignals(db:D1Database,userId:string,profile:ProfileRecord):Promise<Signal[]> {
  const cuisines=[...profile.cuisines.filter(c=>!['Other','Anything'].includes(c)),...(profile.cuisines.includes('Other')?profile.otherCuisine.split(/[,;\n]/):[])].map(c=>c.trim()).filter(Boolean).slice(0,10);
  const signals:Signal[]=[];
  for(const cuisine of cuisines){
    const canonical=cuisine.toLowerCase();
    const resolved=await db.prepare("SELECT signal_id,label FROM qloo_resolved WHERE user_id=? AND kind='tag' AND lower(label)=? AND expires_at>unixepoch() ORDER BY expires_at DESC LIMIT 1").bind(userId,canonical).first<{signal_id:string;label:string}>();
    if(resolved?.signal_id.startsWith('urn:tag:genre:place:restaurant:'))signals.push({id:resolved.signal_id,kind:'tag',label:resolved.label});
    else if(supported.includes(canonical as typeof supported[number]))signals.push({id:`urn:tag:genre:place:restaurant:${canonical}`,kind:'tag',label:canonical});
  }
  return signals.filter((s,i,all)=>all.findIndex(v=>v.id===s.id)===i);
}

export async function mealTaste(env:Env,signals:Signal[],message=''):Promise<MealTaste|null> {
  // A specific meal-cuisine request is a temporary public taste signal, never saved.
  const requested=supported.find(c=>new RegExp('\\b'+c+'\\b','i').test(message));
  const seeds=requested?[{id:`urn:tag:genre:place:restaurant:${requested}`,kind:'tag' as const,label:requested}]:signals;
  if(!seeds.length)return null;
  // Qloo omits input tags from related-tag results. Sending every catalog cuisine
  // would exclude the entire supported result set; use one cuisine anchor while
  // retaining the other explicit cuisine preferences locally.
  const isCuisine=(s:Signal)=>s.kind==='tag'&&supported.some(c=>s.id===`urn:tag:genre:place:restaurant:${c}`);
  const anchor=seeds.find(isCuisine);
  const requestSeeds=seeds.filter(s=>!isCuisine(s)||s===anchor);
  const raw=await new QlooClient(env).insights(requestSeeds,'tags');
  const tags=z.array(z.object({tag_id:z.string(),name:z.string().min(1).max(200)})).max(100).safeParse(raw);
  if(!tags.success)throw new QlooError('qloo_invalid_response',502);
  const seen=new Set<string>();
  const affinities=tags.data.flatMap(tag=>{
    const cuisine=supported.find(c=>tag.tag_id===`urn:tag:genre:place:restaurant:${c}`);
    return cuisine&&!seen.has(cuisine)&&(seen.add(cuisine))?[{id:tag.tag_id,label:tag.name,cuisine}]:[];
  });
  if(!affinities.length)throw new QlooError('qloo_no_recipe_affinities',422);
  const selectedCuisines=seeds.flatMap(seed=>{
    const cuisine=supported.find(c=>seed.kind==='tag'&&seed.id===`urn:tag:genre:place:restaurant:${c}`);
    return cuisine?[{id:seed.id,label:cuisine,cuisine}]:[];
  }).filter((a,i,all)=>all.findIndex(b=>b.id===a.id)===i);
  return {provider:'qloo',affinities,selectedCuisines};
}

/** Returned affinities rank discovery; explicit cuisine limits still retain their selected seeds. */
export function tasteCuisines(taste:MealTaste):string[] {
  return [...new Set([...taste.affinities,...(taste.selectedCuisines??[])].map(a=>a.cuisine))];
}
export function tasteExplanation(taste:MealTaste):string {
  return `Related cuisines: ${taste.affinities.map(a=>a.label).join(', ')}.${taste.selectedCuisines?.length?' Your saved cuisines: '+taste.selectedCuisines.map(a=>a.label).join(', ')+'.':''} Your saved food rules and cuisine preferences take priority. Taste analysis does not establish health or allergen suitability.`;
}

export function qlooEnabled(env:Env):boolean{return env.QLOO_ENABLED==='true';}
/** Rank only previously validated candidates. Do not invent or relax a cuisine. */
export function rankTaste<T extends Pick<StarterRecipe,'cuisines'>>(recipes:T[],taste:MealTaste|null):T[] {
  if(!taste||!recipes.length)return recipes;
  const order=tasteCuisines(taste);
  const ranked=recipes.map(recipe=>({recipe,rank:Math.min(...recipe.cuisines.map(c=>{const i=order.indexOf(c.toLowerCase());return i<0?Infinity:i;}))})).filter(r=>Number.isFinite(r.rank)).sort((a,b)=>a.rank-b.rank);
  if(!ranked.length)return recipes;
  // Give Nemotron choices within the best available cuisine, so affinity order has an observable effect.
  return ranked.filter(r=>r.rank===ranked[0].rank).map(r=>r.recipe);
}
