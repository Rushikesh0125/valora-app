export type Meal = 'breakfast' | 'lunch' | 'dinner';
export interface StarterRecipe {
  id: string; name: string; minutes: number; vegan: boolean; cuisines: string[];
  slots: Meal[]; ingredients: string[]; steps: string[];
}
export const starterRecipes: StarterRecipe[] = [
  {id:'fruit-oats',name:'Banana overnight oats',minutes:5,vegan:true,cuisines:['International'],slots:['breakfast'],ingredients:['rolled oats','banana','water or unsweetened plant milk'],steps:['Combine oats and liquid and refrigerate overnight.','Add sliced banana before serving.'],},
  {id:'banana-toast',name:'Banana toast',minutes:5,vegan:true,cuisines:['International'],slots:['breakfast'],ingredients:['vegan wholegrain bread','banana','cinnamon'],steps:['Toast the bread.','Top with sliced banana and a little cinnamon.'],},
  {id:'vegetable-poha',name:'Vegetable poha',minutes:15,vegan:true,cuisines:['Indian'],slots:['breakfast','lunch'],ingredients:['flattened rice','carrot','peas','onion','oil','cumin','water'],steps:['Rinse flattened rice and drain.','Cook chopped vegetables in a little oil until tender.','Add flattened rice, cumin and a splash of water; heat through.'],},
  {id:'chickpea-bowl',name:'Chickpea and cucumber bowl',minutes:10,vegan:true,cuisines:['Mediterranean','International'],slots:['lunch','dinner'],ingredients:['canned cooked chickpeas','cucumber','tomato','lemon','olive oil'],steps:['Drain and rinse cooked chickpeas.','Wash and chop cucumber and tomato.','Combine with lemon juice and a little olive oil.'],},
  {id:'vegetable-rice',name:'Vegetable rice',minutes:25,vegan:true,cuisines:['Indian','International'],slots:['lunch','dinner'],ingredients:['rice','carrot','peas','onion','oil','water'],steps:['Rinse rice and cook according to package instructions.','Cook chopped vegetables in a little oil until tender.','Mix with hot cooked rice and serve immediately.'],},
  {id:'quick-dal',name:'Red lentil dal',minutes:25,vegan:true,cuisines:['Indian'],slots:['lunch','dinner'],ingredients:['red lentils','tomato','cumin','turmeric','water'],steps:['Rinse lentils.','Simmer lentils with chopped tomato, cumin, turmeric and water until fully tender.','Adjust thickness with water and serve hot.'],},
  {id:'yogurt-bowl',name:'Yogurt and fruit bowl',minutes:5,vegan:false,cuisines:['International'],slots:['breakfast'],ingredients:['plain yogurt','banana','rolled oats'],steps:['Place yogurt in a bowl.','Add banana slices and a small handful of oats.'],},
  {id:'paneer-vegetables',name:'Paneer and vegetable skillet',minutes:20,vegan:false,cuisines:['Indian'],slots:['lunch','dinner'],ingredients:['paneer','bell pepper','tomato','onion','oil'],steps:['Wash and chop vegetables.','Cook onion and bell pepper in a little oil until tender.','Add tomato and cubed paneer, and cook until heated through.'],},
  {id:'tomato-basil-pasta',name:'Tomato and basil pasta',minutes:20,vegan:true,cuisines:['Italian'],slots:['lunch','dinner'],ingredients:['egg-free pasta','tomato','garlic','basil','olive oil','water'],steps:['Boil pasta according to the package instructions.','Cook chopped tomato and garlic in a little olive oil until softened.','Toss drained pasta with the tomato sauce and basil.']},
  {id:'white-bean-bruschetta',name:'White bean and tomato bruschetta',minutes:10,vegan:true,cuisines:['Italian','Mediterranean'],slots:['breakfast','lunch','dinner'],ingredients:['vegan bread','canned cooked white beans','tomato','basil','olive oil'],steps:['Drain and rinse the beans.','Toast the bread.','Mix chopped tomato, beans, basil and a little olive oil; spoon onto toast.']},
  {id:'vegetable-couscous',name:'Vegetable couscous bowl',minutes:15,vegan:true,cuisines:['Mediterranean'],slots:['lunch','dinner'],ingredients:['couscous','canned cooked chickpeas','bell pepper','cucumber','lemon','water'],steps:['Prepare couscous with boiling water following the package instructions.','Drain and rinse chickpeas; wash and chop vegetables.','Combine with couscous and lemon juice.']},
  {id:'vegetable-noodles',name:'Quick vegetable noodles',minutes:20,vegan:true,cuisines:['Asian','Chinese'],slots:['lunch','dinner'],ingredients:['egg-free noodles','carrot','bell pepper','cabbage','oil','water'],steps:['Cook noodles according to the package instructions.','Stir-fry sliced vegetables in a little oil until tender.','Add drained noodles and toss until hot.']},
  {id:'bean-wrap',name:'Bean and vegetable wrap',minutes:15,vegan:true,cuisines:['Mexican'],slots:['breakfast','lunch','dinner'],ingredients:['vegan tortilla','canned cooked kidney beans','tomato','lettuce','lemon'],steps:['Drain, rinse and heat cooked beans.','Wash and chop tomato and lettuce.','Warm tortilla; fill with beans, vegetables and lemon juice.']},

  {id:'chickpea-chaat',name:'Chickpea and cucumber chaat',minutes:10,vegan:true,cuisines:['Indian'],slots:['lunch','dinner'],ingredients:['canned cooked chickpeas','cucumber','tomato','cumin','lemon'],steps:['Drain and rinse cooked chickpeas.','Wash and chop cucumber and tomato.','Mix chickpeas and vegetables with cumin and lemon juice.']},

  {id:'rice-porridge',name:'Quick rice and carrot porridge',minutes:15,vegan:true,cuisines:['Asian','Chinese'],slots:['breakfast'],ingredients:['shelf-stable ready-cooked rice','carrot','ginger','water'],steps:['Wash and finely chop carrot and ginger.','Simmer rice with water, carrot and ginger until the carrot is tender and the rice is soft.','Follow the rice package heating instructions and serve hot.']},

  {id:'carrot-lentil-soup',name:'Carrot and red lentil soup',minutes:25,vegan:true,cuisines:['Indian','Mediterranean'],slots:['lunch','dinner'],ingredients:['red lentils','carrot','cumin','water'],steps:['Rinse the lentils and wash and finely chop the carrot.','Simmer lentils, carrot and cumin in water until fully tender.','Mash lightly and serve warm.']},
  {id:'tomato-white-bean-soup',name:'Tomato and white bean soup',minutes:15,vegan:true,cuisines:['Italian','Mediterranean','International'],slots:['lunch','dinner'],ingredients:['canned cooked white beans','tomato','basil','water','olive oil'],steps:['Drain and rinse cooked beans; wash and chop tomato.','Simmer tomato, beans and water until hot and the tomato is tender.','Add basil and a little olive oil; serve warm.']},

  {id:'quick-lentil-soup',name:'Quick lentil soup',minutes:10,vegan:true,cuisines:['Indian'],slots:['lunch','dinner'],ingredients:['canned cooked lentils','cumin','water'],steps:['Drain and rinse cooked lentils.','Simmer with water and cumin until thoroughly hot, following the package heating instructions.','Serve warm.']},

];

export function remainingMeals(now: Date, timeZone: string, coverage: string): {date: string; slots: Meal[]} {
  const parts = new Intl.DateTimeFormat('en-CA',{timeZone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',hourCycle:'h23'}).formatToParts(now);
  const part = (name: string) => parts.find(p => p.type === name)!.value;
  const hour = Number(part('hour'));
  const allowed: Meal[] = coverage === 'Dinner only' ? ['dinner'] : coverage === 'Lunch & dinner' ? ['lunch','dinner'] : ['breakfast','lunch','dinner'];
  return {date:`${part('year')}-${part('month')}-${part('day')}`,slots:allowed.filter(slot=>hour<({breakfast:10,lunch:15,dinner:22}[slot]))};
}

// Overnight oats are only usable tomorrow, so never offer them for remaining meals today.
export function eligibleRecipes(eatingPattern: string, minutes: number, slot: Meal) {
  return starterRecipes.filter(recipe=>recipe.id!=='fruit-oats' && recipe.slots.includes(slot) && recipe.minutes<=minutes && (eatingPattern!=='Vegan'||recipe.vegan));
}

// These tags describe the fixed recipe ingredients, not packaged-product cross-contact.
const recipeAllergens: Record<string,string[]> = {
  'quick-lentil-soup':[], 'carrot-lentil-soup':[], 'tomato-white-bean-soup':[],
  'rice-porridge':[], 'chickpea-chaat':[], 'vegetable-poha':[], 'chickpea-bowl':[], 'vegetable-rice':[], 'quick-dal':[], 'vegetable-couscous':['wheat','gluten'],
  'fruit-oats':['gluten'], 'banana-toast':['wheat','gluten'], 'yogurt-bowl':['milk','gluten'],
  'paneer-vegetables':['milk'], 'tomato-basil-pasta':['wheat','gluten'],
  'white-bean-bruschetta':['wheat','gluten'],
  'vegetable-noodles':['wheat','gluten'], 'bean-wrap':['wheat','gluten'],
};
const allergenAliases:Record<string,string> = {
  eggplant:'eggplant','egg plant':'eggplant','egg-plant':'eggplant',baingan:'eggplant',brinjal:'eggplant',aubergine:'eggplant','eggplant (brinjal)':'eggplant',
  peanut:'peanut',peanuts:'peanut','tree nuts':'tree-nuts','tree nut':'tree-nuts',nuts:'tree-nuts',
  dairy:'milk',milk:'milk',lactose:'milk',egg:'egg',eggs:'egg',wheat:'wheat',gluten:'gluten',
  soy:'soy',soya:'soy',fish:'fish',shellfish:'shellfish',seafood:'shellfish',sesame:'sesame',
};
const exclusionAliases:Record<string,string> = {eggplant:'eggplant',eggplants:'eggplant','egg plant':'eggplant','egg-plant':'eggplant',baingan:'eggplant','eggplant (brinjal)':'eggplant',brinjal:'eggplant',brinjals:'eggplant',aubergine:'eggplant',aubergines:'eggplant',onions:'onion',tomatoes:'tomato',potatoes:'potato',peanuts:'peanut',eggs:'egg',mushrooms:'mushroom',beans:'bean',chickpeas:'chickpea',lentils:'lentil',noodles:'noodle',nuts:'nut',oats:'oat',dairy:'milk',yogurt:'milk',curd:'milk',cheese:'milk',paneer:'milk',bread:'wheat',pasta:'wheat',couscous:'wheat',tortilla:'wheat',noodle:'wheat'};
const knownExclusions=new Set(['eggplant','ginger','onion','garlic','tomato','potato','pea','peas','carrot','cucumber','lemon','oil','olive oil','rice','cumin','turmeric','banana','cinnamon','bell pepper','cabbage','lettuce','basil','water','chickpea','bean','lentil','oat','milk','wheat','gluten','soy','sesame','peanut','nut','mushroom','chicken','fish','meat','beef','pork','egg','shellfish','sugar','salt']);
function clean(value:string) {
  return value.normalize('NFKC').toLowerCase().trim().replace(/^["'“”‘’]+|["'“”‘’.!?…]+$/g,'').trim()
    .replace(/^(?:i (?:do not|don't|don’t|cannot|can't|can’t) (?:eat|like)|i (?:avoid|dislike)|allergic to|allergy to|no|avoid|without)\s+/,'').trim();
}
const noRestriction = (value:string) => /^(?:none|nothing|nil|n\/a|na|not applicable|no (?:known )?(?:allergies|restrictions|food restrictions|exclusions)|nothing specific|no foods to avoid|-)$/i.test(value.trim().replace(/[.!?]+$/,'').trim());
export function restrictions(profile:{allergies:string[];otherAllergy:string;exclusions:string}) {
  const allergens:string[]=[];
  for(const value of profile.allergies.flatMap(a=>a==='Other'?profile.otherAllergy.split(/[,;\n/|]|\s+and\s+/):[a])) {
    if(noRestriction(value))continue;
    const key=clean(value);if(!key)continue;
    const canonical=allergenAliases[key]??exclusionAliases[key]??(knownExclusions.has(key)?key:undefined);if(!canonical)return null;
    allergens.push(canonical);
  }
  // Hidden text left after deselecting Other is not an active allergy.
  const excluded:string[]=[];
  for(const value of (noRestriction(profile.exclusions)?'':profile.exclusions).split(/[,;\n/|]|\s+and\s+/)) {
    if(noRestriction(value))continue;
    const key=clean(value);if(!key||['none','nothing','no restrictions'].includes(key))continue;
    const canonical=exclusionAliases[key]??key;
    if(!knownExclusions.has(canonical))return null;
    excluded.push(canonical);
  }
  return {allergens:[...new Set(allergens)],excluded:[...new Set(excluded)]};
}
export function suitableRecipes(profile:{eatingPattern:string;cookingMinutes:number;allergies:string[];otherAllergy:string;exclusions:string},slot:Meal) {
  const rules=restrictions(profile);if(!rules)return [];
  return eligibleRecipes(profile.eatingPattern,profile.cookingMinutes,slot).filter(recipe=>{
    const tags=recipeAllergens[recipe.id];if(!tags)return false;
    return ![...rules.allergens,...rules.excluded].some(term=>tags.includes(term)||recipe.ingredients.some(ingredient=>{
      const text=ingredient.toLowerCase();
      return text.includes(term)||(term==='milk'&&/yogurt|paneer|cheese|milk/.test(text))||(term==='wheat'&&tags.includes('wheat'));
    }));
  });
}

export function preferredRecipes(profile:Parameters<typeof suitableRecipes>[0]&{cuisines:string[];otherCuisine:string;mealStyle?:string},slot:Meal) {
  const safe=suitableRecipes(profile,slot);
  const cuisines=profile.cuisines.flatMap(c=>c==='Other'?profile.otherCuisine.split(/[,;]/):[c]).map(c=>c.trim().toLowerCase());
  const matching=!profile.cuisines.length||profile.cuisines.includes('Anything')?safe:safe.filter(r=>r.cuisines.some(c=>cuisines.includes(c.toLowerCase())));
  if(profile.mealStyle&&slot!=='breakfast') {
    const soups=matching.filter(r=>r.id.endsWith('-soup'));if(soups.length)return soups;
    const warm=matching.filter(r=>['vegetable-rice','quick-dal','paneer-vegetables','tomato-basil-pasta','vegetable-noodles','vegetable-poha'].includes(r.id));
    return warm;
  }
  return matching;
}

export function requestedCuisine(request:string):string|null {
  return ['Italian','Indian','Asian','Mediterranean','Mexican','Chinese'].find(c=>new RegExp('\\b'+c+'\\b','i').test(request))??null;
}

export function unrecognizedRestrictions(profile:{allergies:string[];otherAllergy:string;exclusions:string}) {
  const allergies=profile.allergies.flatMap(a=>a==='Other'?profile.otherAllergy.split(/[,;\n/|]|\s+and\s+/):[a]).filter(value=>!restrictions({allergies:['Other'],otherAllergy:value,exclusions:''}));
  const exclusions=(noRestriction(profile.exclusions)?[]:profile.exclusions.split(/[,;\n/|]|\s+and\s+/)).filter(value=>!restrictions({allergies:[],otherAllergy:'',exclusions:value}));
  return {allergies,exclusions};
}
