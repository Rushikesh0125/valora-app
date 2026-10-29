enum MealType { breakfast, lunch, dinner }

enum PantryKind { ingredient, leftover }

enum ChatFocus { plan, pantry, rules, limits, rationale, profile, memory }

enum Panel {
  pantry,
  rules,
  practical,
  memory,
  reports,
  notifications,
  settings,
  privacy,
  payments,
  ingredients,
  prepared,
  basket,
}

class Profile {
  final goals = <String>{'Easier meals'};
  String pattern = 'Omnivore';
  String exclusions = '';
  final allergies = <String>{};
  final health = <String>{};
  final cuisines = <String>{'Indian'};
  String otherGoal = '', otherAllergy = '', otherHealth = '', otherCuisine = '';
  String coverage = 'Breakfast, lunch & dinner';
  int budget = 2000, cookingMinutes = 30;
  String planningTime = 'Evening';
  bool acknowledged = false;

  Map<String, dynamic> toJson() => {
    'goals': goals.toList(),
    'eatingPattern': pattern,
    'exclusions': exclusions,
    'allergies': allergies.toList(),
    'healthContext': health.toList(),
    'cuisines': cuisines.toList(),
    'otherGoal': otherGoal,
    'otherAllergy': otherAllergy,
    'otherHealth': otherHealth,
    'otherCuisine': otherCuisine,
    'coverage': coverage,
    'weeklyBudgetInr': budget,
    'cookingMinutes': cookingMinutes,
    'planningTime': planningTime,
    'acknowledged': acknowledged,
  };

  void restore(Map<String, dynamic> data) {
    goals
      ..clear()
      ..addAll((data['goals'] as List).cast<String>());
    allergies
      ..clear()
      ..addAll((data['allergies'] as List).cast<String>());
    health
      ..clear()
      ..addAll((data['healthContext'] as List).cast<String>());
    cuisines
      ..clear()
      ..addAll((data['cuisines'] as List).cast<String>());
    pattern = data['eatingPattern'] as String;
    exclusions = data['exclusions'] as String;
    otherGoal = data['otherGoal'] as String;
    otherAllergy = data['otherAllergy'] as String;
    otherHealth = data['otherHealth'] as String;
    otherCuisine = data['otherCuisine'] as String;
    coverage = data['coverage'] as String;
    budget = data['weeklyBudgetInr'] as int;
    cookingMinutes = data['cookingMinutes'] as int;
    planningTime = data['planningTime'] as String;
    acknowledged = data['acknowledged'] as bool;
  }

  String resolved(Set<String> values, String other) => values
      .map((v) => v == 'Other' && other.trim().isNotEmpty ? other.trim() : v)
      .join(', ');
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.amount,
    this.kind = PantryKind.ingredient,
  });
  final int id;
  final String name, amount;
  final PantryKind kind;
}

class Intake {
  const Intake({
    required this.name,
    required this.portion,
    required this.at,
    this.sourceName,
    this.remaining,
  });
  final String name, portion;
  final DateTime at;
  final String? sourceName, remaining;
}

class Recipe {
  const Recipe(this.name, this.ingredients, this.minutes, this.method);
  final String name;
  final List<String> ingredients;
  final int minutes;
  final List<String> method;
}

class MealSlot {
  int option = 0, servings = 1;
  bool removed = false;
}

class DayDraft {
  final slots = {for (final type in MealType.values) type: MealSlot()};
}

class ChatEntry {
  const ChatEntry(
    this.text,
    this.isUser, {
    this.isError = false,
    this.source,
    this.model,
  });
  final String text;
  final bool isUser;
  final bool isError;
  final String? source;
  final String? model;
}

class SavedFact {
  const SavedFact(
    this.key,
    this.label,
    this.value,
    this.source, {
    this.safety = false,
  });
  final String key, label, value, source;
  final bool safety;
}

class GroceryOffer {
  const GroceryOffer(this.name, this.slot, this.subtotal, this.fees);
  final String name, slot;
  final int subtotal, fees;
  int get total => subtotal + fees;
}

class PreparedOffer {
  const PreparedOffer(
    this.dish,
    this.restaurant,
    this.cuisine,
    this.ingredients,
    this.price,
    this.fees,
    this.eta,
    this.fit,
  );
  final String dish, restaurant, cuisine, ingredients, eta, fit;
  final int price, fees;
  int get total => price + fees;
}
