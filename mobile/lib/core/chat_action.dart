import 'models.dart';

enum ChatActionField { budget, cookingMinutes, pattern }

class ChatAction {
  ChatAction(this.field, this.value);
  final ChatActionField field;
  final Object value;
  String get label => switch (field) {
    ChatActionField.budget => 'Weekly budget (INR)',
    ChatActionField.cookingMinutes => 'Cooking time (minutes)',
    ChatActionField.pattern => 'Eating pattern',
  };
  Object current(Profile p) => switch (field) {
    ChatActionField.budget => p.budget,
    ChatActionField.cookingMinutes => p.cookingMinutes,
    ChatActionField.pattern => p.pattern,
  };
  void apply(Profile p) {
    switch (field) {
      case ChatActionField.budget:
        p.budget = value as int;
      case ChatActionField.cookingMinutes:
        p.cookingMinutes = value as int;
      case ChatActionField.pattern:
        p.pattern = value as String;
    }
  }
}

/// Deliberately requires a whole explicit command, including unambiguous units.
ChatAction? parseChatAction(String text) {
  final input = text
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^please '), '')
      .replaceFirst(RegExp(r'[.!]$'), '');
  final budget = RegExp(
    r'^(?:set|change|update) my weekly budget to (?:inr |rs\.? |₹)(\d+)$',
  ).firstMatch(input);
  if (budget != null) {
    final value = int.tryParse(budget[1]!);
    if (value != null && value <= 10000000)
      return ChatAction(ChatActionField.budget, value);
  }
  final time = RegExp(
    r'^(?:set|change|update) my cooking time to (\d+) minutes$',
  ).firstMatch(input);
  if (time != null) {
    final value = int.tryParse(time[1]!);
    if (value != null && value <= 1440)
      return ChatAction(ChatActionField.cookingMinutes, value);
  }
  final pattern = RegExp(
    r'^(?:set|change|update) my eating pattern to (omnivore|vegetarian|vegan)$',
  ).firstMatch(input);
  if (pattern != null) {
    final value = pattern[1]!;
    return ChatAction(
      ChatActionField.pattern,
      value[0].toUpperCase() + value.substring(1),
    );
  }
  return null;
}
