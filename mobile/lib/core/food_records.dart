import 'dart:convert';
import 'models.dart';

/// The account's atomic pantry, confirmed meal log and example plan document.
class FoodRecords {
  FoodRecords(this.pantry, this.intake, this.days, this.startDate);
  final List<PantryItem> pantry;
  final List<Intake> intake;
  final List<DayDraft> days;
  final DateTime startDate;

  factory FoodRecords.empty() {
    final now = DateTime.now();
    return FoodRecords(
      [],
      [],
      List.generate(5, (_) => DayDraft()),
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'pantry': pantry
        .map(
          (item) => {
            'id': item.id,
            'name': item.name,
            'amount': item.amount,
            'kind': item.kind.name,
          },
        )
        .toList(),
    'intake': intake
        .map(
          (meal) => {
            'name': meal.name,
            'portion': meal.portion,
            'at': meal.at.toUtc().toIso8601String(),
            'sourceName': meal.sourceName,
            'remaining': meal.remaining,
          },
        )
        .toList(),
    'plan': {
      'recipeSet': 'example-v1',
      'startDate': startDate.toIso8601String().substring(0, 10),
      'days': days
          .map(
            (day) => {
              for (final type in MealType.values)
                type.name: {
                  'option': day.slots[type]!.option,
                  'servings': day.slots[type]!.servings,
                  'removed': day.slots[type]!.removed,
                },
            },
          )
          .toList(),
    },
  };

  factory FoodRecords.fromJson(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1)
      throw const FormatException('Unsupported food records');
    String text(Object? value) {
      if (value is! String || value.trim().isEmpty || value.length > 200) {
        throw const FormatException('Invalid food record text');
      }
      return value;
    }

    final items = (data['pantry'] as List)
        .map(
          (item) => PantryItem(
            id: item['id'] as int,
            name: text(item['name']),
            amount: text(item['amount']),
            kind: PantryKind.values.byName(item['kind'] as String),
          ),
        )
        .toList();
    if (items.length > 500 ||
        items.any((i) => i.id < 1 || i.id > 2147483647) ||
        items.map((i) => i.id).toSet().length != items.length) {
      throw const FormatException('Invalid pantry records');
    }
    final meals = (data['intake'] as List).map((meal) {
      final at = DateTime.parse(meal['at'] as String);
      if (!at.isUtc ||
          (meal['sourceName'] == null && meal['remaining'] != null)) {
        throw const FormatException('Invalid meal record');
      }
      return Intake(
        name: text(meal['name']),
        portion: text(meal['portion']),
        at: at.toLocal(),
        sourceName: meal['sourceName'] == null
            ? null
            : text(meal['sourceName']),
        remaining: meal['remaining'] == null ? null : text(meal['remaining']),
      );
    }).toList();
    if (meals.length > 5000)
      throw const FormatException('Too many meal records');
    final plan = data['plan'] as Map<String, dynamic>;
    if (plan['recipeSet'] != 'example-v1')
      throw const FormatException('Unsupported recipe set');
    final start = DateTime.parse(plan['startDate'] as String);
    if (start.toIso8601String().substring(0, 10) != plan['startDate']) {
      throw const FormatException('Invalid plan date');
    }
    final drafts = (plan['days'] as List).map((value) {
      final draft = DayDraft();
      for (final type in MealType.values) {
        final valueSlot = value[type.name];
        final slot = draft.slots[type]!;
        slot.option = valueSlot['option'] as int;
        slot.servings = valueSlot['servings'] as int;
        slot.removed = valueSlot['removed'] as bool;
        if (slot.option < 0 ||
            slot.option > 4 ||
            slot.servings < 1 ||
            slot.servings > 4) {
          throw const FormatException('Invalid plan slot');
        }
      }
      return draft;
    }).toList();
    if (drafts.length != 5) throw const FormatException('Invalid plan length');
    return FoodRecords(items, meals, drafts, start);
  }

  // Leave room for the request's version and mutation ID envelope.
  bool get fitsRequest =>
      utf8.encode(jsonEncode(toJson())).length <= 512 * 1024 - 256;
}
