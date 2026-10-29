class TagSuggestion {
  const TagSuggestion(this.id, this.label, [this.aliases = const []]);
  final String id, label;
  final List<String> aliases;
  bool matches(String query) => [
    label,
    id,
    ...aliases,
  ].any((v) => v.toLowerCase().contains(query.trim().toLowerCase()));
  bool isExact(String value) => [
    label,
    id,
    ...aliases,
  ].any((v) => v.toLowerCase() == value.trim().toLowerCase());
}

const foodSuggestions = [
  TagSuggestion('eggplant', 'Eggplant', ['brinjal', 'aubergine', 'egg plant']),
  TagSuggestion('onion', 'Onion', ['onions']),
  TagSuggestion('garlic', 'Garlic'),
  TagSuggestion('mushroom', 'Mushroom', ['mushrooms']),
  TagSuggestion('tomato', 'Tomato', ['tomatoes']),
  TagSuggestion('potato', 'Potato', ['potatoes']),
  TagSuggestion('carrot', 'Carrot'),
  TagSuggestion('bell pepper', 'Bell pepper', ['capsicum']),
  TagSuggestion('cucumber', 'Cucumber'),
  TagSuggestion('cabbage', 'Cabbage'),
  TagSuggestion('peas', 'Peas'),
  TagSuggestion('lettuce', 'Lettuce'),
  TagSuggestion('chickpea', 'Chickpeas'),
  TagSuggestion('bean', 'Beans'),
  TagSuggestion('lentil', 'Lentils'),
  TagSuggestion('rice', 'Rice'),
  TagSuggestion('oat', 'Oats'),
  TagSuggestion('wheat', 'Wheat', ['bread', 'pasta']),
  TagSuggestion('gluten', 'Gluten'),
  TagSuggestion('milk', 'Milk / dairy', [
    'dairy',
    'yogurt',
    'paneer',
    'cheese',
  ]),
  TagSuggestion('egg', 'Eggs'),
  TagSuggestion('peanut', 'Peanuts'),
  TagSuggestion('nut', 'Nuts'),
  TagSuggestion('soy', 'Soy', ['soya']),
  TagSuggestion('sesame', 'Sesame'),
  TagSuggestion('fish', 'Fish'),
  TagSuggestion('shellfish', 'Shellfish'),
  TagSuggestion('chicken', 'Chicken'),
  TagSuggestion('beef', 'Beef'),
  TagSuggestion('pork', 'Pork'),
  TagSuggestion('meat', 'Meat'),
  TagSuggestion('banana', 'Banana'),
  TagSuggestion('lemon', 'Lemon'),
  TagSuggestion('ginger', 'Ginger'),
  TagSuggestion('cumin', 'Cumin'),
  TagSuggestion('turmeric', 'Turmeric'),
  TagSuggestion('basil', 'Basil'),
  TagSuggestion('cinnamon', 'Cinnamon'),
  TagSuggestion('oil', 'Oil'),
  TagSuggestion('sugar', 'Sugar'),
  TagSuggestion('salt', 'Salt'),
];
const allergySuggestions = [
  TagSuggestion('peanut', 'Peanuts'),
  TagSuggestion('tree nuts', 'Tree nuts', ['almonds', 'walnuts', 'cashews']),
  TagSuggestion('milk', 'Milk / dairy', ['dairy', 'lactose']),
  TagSuggestion('egg', 'Eggs'),
  TagSuggestion('wheat', 'Wheat'),
  TagSuggestion('gluten', 'Gluten'),
  TagSuggestion('soy', 'Soy', ['soya']),
  TagSuggestion('sesame', 'Sesame'),
  TagSuggestion('fish', 'Fish'),
  TagSuggestion('shellfish', 'Shellfish'),
  TagSuggestion('eggplant', 'Eggplant', ['brinjal', 'aubergine']),
];
const cuisineSuggestions = [
  TagSuggestion('Indian', 'Indian'),
  TagSuggestion('Italian', 'Italian'),
  TagSuggestion('Asian', 'Asian'),
  TagSuggestion('Chinese', 'Chinese'),
  TagSuggestion('Mediterranean', 'Mediterranean'),
  TagSuggestion('Mexican', 'Mexican'),
];
const goalSuggestions = [
  TagSuggestion('Easier meals', 'Easier meals', ['simple', 'easy']),
  TagSuggestion('More variety', 'More variety'),
  TagSuggestion('Eat more protein', 'Eat more protein', ['protein']),
  TagSuggestion('Steadier routine', 'Steadier routine'),
  TagSuggestion('Spend less', 'Spend less', ['budget']),
];
// Entries are self-reported context only; selecting one does not establish a diagnosis.
const healthSuggestions = [
  TagSuggestion('Recent injury', 'Recent injury'),
  TagSuggestion('Digestive issue', 'Digestive issue'),
  TagSuggestion('Diabetes', 'Diabetes'),
  TagSuggestion('High blood pressure', 'High blood pressure', ['hypertension']),
  TagSuggestion('Kidney stones', 'Kidney stones', ['renal stones']),
];
