import { additionalRecipes } from './discovery-additional-recipes.js';
export interface Recipe {
  id: string;
  name: string;
  cuisine: string;
  minutes: number;
  servings: number;
  ingredients: string[];
  steps: string[];
  texture: string;
  soft: boolean;
  mild: boolean;
  spiceAdjustment: string;
  eatingPattern: string;
  source: string;
  license: string;
  reviewStatus: string;
  budgetStatus: string;
  priceInr: null;
}
export const recipes: readonly Recipe[] = [
  ...additionalRecipes,
  {
    id: "moong-khichdi",
    name: "Moong dal khichdi",
    cuisine: "indian",
    minutes: 30,
    servings: 1,
    ingredients: [
      "1/4 cup rice",
      "1/4 cup split moong dal",
      "1/2 cup diced carrot",
      "1 tsp oil",
      "1/8 tsp turmeric",
      "2 cups water",
    ],
    steps: [
      "Rinse rice and dal.",
      "Bring all ingredients to a boil in a covered pot; simmer 25 minutes, stirring and adding water as needed until rice and dal are tender.",
    ],
    texture: "Soft, moist rice and lentils",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "vegetable-poha",
    name: "Vegetable poha",
    cuisine: "indian",
    minutes: 20,
    servings: 1,
    ingredients: [
      "1 cup thick poha",
      "1/2 cup peas",
      "1/2 small onion, diced",
      "1 tsp oil",
      "1/8 tsp turmeric",
      "1/2 cup water",
    ],
    steps: [
      "Rinse poha briefly and drain for 5 minutes.",
      "Soften onion in oil for 5 minutes. Add peas, turmeric and water; simmer covered 5 minutes.",
      "Fold in poha; steam 3 minutes until moist.",
    ],
    texture: "Moist flakes; peas remain distinct",
    soft: false,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "masoor-dal",
    name: "Gentle masoor dal",
    cuisine: "indian",
    minutes: 25,
    servings: 1,
    ingredients: [
      "1/3 cup red lentils",
      "1 tomato, diced",
      "1 tsp oil",
      "1/8 tsp cumin",
      "1 1/2 cups water",
    ],
    steps: [
      "Rinse lentils.",
      "Combine all ingredients; simmer partially covered 20 minutes until lentils break down, adding water if needed.",
      "Mash lightly before serving.",
    ],
    texture: "Soft mashed lentils",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "carrot-upma",
    name: "Carrot upma",
    cuisine: "indian",
    minutes: 20,
    servings: 1,
    ingredients: [
      "1/3 cup semolina (wheat)",
      "1/2 carrot, grated",
      "1 tsp oil",
      "1 cup water",
    ],
    steps: [
      "Dry toast semolina on low heat for 3 minutes, then set aside.",
      "Cook grated carrot in oil 3 minutes. Add water and bring to a boil.",
      "Slowly stir in semolina; cover on low heat for 5 minutes.",
    ],
    texture: "Moist grain porridge",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "rice-kanji",
    name: "Rice kanji",
    cuisine: "indian",
    minutes: 35,
    servings: 1,
    ingredients: [
      "1/4 cup rice",
      "2 1/2 cups water",
      "1/2 carrot, finely grated",
    ],
    steps: [
      "Rinse rice. Combine with water and carrot.",
      "Simmer partially covered 30 minutes, stirring often until rice is very tender; add water as needed.",
    ],
    texture: "Loose rice porridge",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "lemon-rice",
    name: "Gentle lemon rice",
    cuisine: "indian",
    minutes: 15,
    servings: 1,
    ingredients: [
      "1 cup already-cooked rice, freshly prepared",
      "1 tsp oil",
      "1 tbsp lemon juice",
      "1/8 tsp turmeric",
      "2 tbsp water",
    ],
    steps: [
      "Heat oil, turmeric and water in a pan.",
      "Add freshly cooked rice, cover and heat until steaming throughout.",
      "Remove from heat and stir in lemon juice.",
    ],
    texture: "Tender rice grains",
    soft: false,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "tomato-pasta",
    name: "Tomato courgette pasta",
    cuisine: "italian",
    minutes: 25,
    servings: 1,
    ingredients: [
      "70 g small pasta (wheat)",
      "1 tomato, diced",
      "1/2 courgette, diced",
      "1 tsp olive oil",
      "1 1/2 cups water",
    ],
    steps: [
      "Boil pasta in water according to package directions until tender, adding water as needed; drain.",
      "Simmer tomato and courgette in oil with 3 tbsp water for 12 minutes.",
      "Combine pasta and sauce.",
    ],
    texture: "Tender pasta with soft vegetable pieces",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "white-bean-soup",
    name: "White bean tomato soup",
    cuisine: "italian",
    minutes: 20,
    servings: 1,
    ingredients: [
      "3/4 cup canned cooked white beans, drained",
      "1 tomato, diced",
      "1/2 carrot, grated",
      "1 tsp olive oil",
      "1 cup water",
    ],
    steps: [
      "Rinse canned beans.",
      "Simmer all ingredients together 15 minutes until vegetables are soft.",
      "Mash half the beans into the broth.",
    ],
    texture: "Thick soup with soft bean pieces",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "rice-minestrone",
    name: "Rice and vegetable minestrone",
    cuisine: "italian",
    minutes: 30,
    servings: 1,
    ingredients: [
      "1/4 cup rice",
      "1/2 courgette, diced",
      "1 tomato, diced",
      "1/2 cup canned beans, drained",
      "2 cups water",
      "1 tsp olive oil",
    ],
    steps: [
      "Rinse rice and canned beans.",
      "Simmer all ingredients for 25 minutes, stirring occasionally, until rice and vegetables are tender.",
    ],
    texture: "Brothy rice with soft vegetables",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "ginger-congee",
    name: "Ginger vegetable congee",
    cuisine: "chinese",
    minutes: 40,
    servings: 1,
    ingredients: [
      "1/4 cup rice",
      "1/2 carrot, grated",
      "1/4 tsp grated ginger",
      "3 cups water",
    ],
    steps: [
      "Rinse rice.",
      "Simmer all ingredients partly covered for 35 minutes, stirring often and adding water as needed.",
    ],
    texture: "Loose rice porridge",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "tofu-rice",
    name: "Tofu and vegetable rice",
    cuisine: "chinese",
    minutes: 20,
    servings: 1,
    ingredients: [
      "100 g plain tofu (soy), cubed",
      "1 cup freshly cooked rice",
      "1/2 courgette, diced",
      "1 tsp oil",
      "1/4 cup water",
    ],
    steps: [
      "Simmer courgette with oil and water covered for 8 minutes.",
      "Add tofu and rice; cover and heat for 5 minutes until steaming throughout.",
    ],
    texture: "Tender rice with tofu and vegetable pieces",
    soft: false,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
  {
    id: "noodle-soup",
    name: "Vegetable noodle soup",
    cuisine: "chinese",
    minutes: 20,
    servings: 1,
    ingredients: [
      "60 g plain wheat noodles",
      "1/2 carrot, grated",
      "1/2 courgette, diced",
      "2 cups water",
      "1 tsp oil",
    ],
    steps: [
      "Bring water, vegetables and oil to a boil; simmer 8 minutes.",
      "Add noodles and cook according to package directions until tender.",
    ],
    texture: "Broth with noodles and vegetable pieces",
    soft: true,
    mild: true,
    spiceAdjustment:
      "No chilli in this preparation. Keep chilli and hot sauces out for a mild version.",
    eatingPattern: "vegan",
    source:
      "Original Valora kitchen preparation specification; desk-reviewed for ingredient/step consistency, not clinically or kitchen validated.",
    license: "MIT",
    reviewStatus: "desk-reviewed",
    budgetStatus: "unverified",
    priceInr: null,
  },
];
