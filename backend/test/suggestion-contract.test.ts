import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { restrictions, starterRecipes, suitableRecipes } from '../src/starter-recipes.js';
const source=readFileSync(new URL('../../mobile/lib/core/tag_suggestions.dart',import.meta.url),'utf8');
function ids(section:string){const body=source.split(`const ${section} = [`)[1]?.split('];')[0];if(!body)throw new Error('Suggestion catalog missing');return [...body.matchAll(/TagSuggestion\(\s*'([^']+)'/g)].map(m=>m[1]);}
describe('mobile suggestion contract',()=>{
  it('accepts every selectable food and allergen canonical id in server filtering',()=>{
    for(const id of ids('foodSuggestions'))expect(restrictions({allergies:[],otherAllergy:'',exclusions:id}),id).not.toBeNull();
    for(const id of ids('allergySuggestions'))expect(restrictions({allergies:['Other'],otherAllergy:id,exclusions:''}),id).not.toBeNull();
  });
  it('suggests only cuisines present in the recipe collection',()=>{
    for(const id of ids('cuisineSuggestions'))expect(starterRecipes.some(r=>r.cuisines.includes(id)),id).toBe(true);
  });
});

describe('food names entered as allergies',()=>{
  it('recognizes paneer and chicken without discarding either restriction',()=>{
    expect(restrictions({allergies:['Other'],otherAllergy:'paneer, chicken',exclusions:'eggplant'})).toEqual({allergens:['milk','chicken'],excluded:['eggplant']});
  });
  it('accepts every known suggested food in allergy Other too',()=>{
    for(const id of ids('foodSuggestions'))expect(restrictions({allergies:['Other'],otherAllergy:id,exclusions:''}),id).not.toBeNull();
  });
  it('filters dairy recipes when paneer is reported as an allergy',()=>{
    const recipes=suitableRecipes({eatingPattern:'Omnivore',cookingMinutes:30,allergies:['Other'],otherAllergy:'paneer, chicken',exclusions:''},'lunch');
    expect(recipes.length).toBeGreaterThan(0);
    expect(recipes.some(r=>r.id==='paneer-vegetables')).toBe(false);
  });
  it('enforces ingredient allergies without a major-allergen tag',()=>{
    const recipes=suitableRecipes({eatingPattern:'Omnivore',cookingMinutes:30,allergies:['Other'],otherAllergy:'tomato',exclusions:''},'lunch');
    expect(recipes.length).toBeGreaterThan(0);
    expect(recipes.every(r=>r.ingredients.every(i=>!i.includes('tomato')))).toBe(true);
    expect(restrictions({allergies:['Other'],otherAllergy:'unrecognized ingredient',exclusions:''})).toBeNull();
  });
});
