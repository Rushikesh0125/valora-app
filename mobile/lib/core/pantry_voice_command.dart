import 'tag_suggestions.dart';
import 'models.dart';

class PantryVoiceCommand {
  const PantryVoiceCommand({
    required this.remove,
    required this.name,
    this.amount,
  });
  final bool remove;
  final String name;
  final String? amount;
}

PantryVoiceCommand? parsePantryVoice(String transcript) {
  var text = transcript
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .replaceAll(RegExp(r'[,;]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^please '), '')
      .replaceFirst(RegExp(r' (?:from|to|in) (?:my |the )?pantry$'), '');
  if (text.length > 500) return null;
  final removal = RegExp(r'^(?:remove|delete) (?:the )?(.+)$').firstMatch(text);
  if (removal != null) {
    final name = removal[1]!.trim();
    if (name.length > 200 || RegExp(r'\b(and|all|everything)\b').hasMatch(name))
      return null;
    return PantryVoiceCommand(remove: true, name: name);
  }
  final start = RegExp(r'^(?:add|save|set|update) (.+)$').firstMatch(text);
  if (start == null) return null;
  text = start[1]!;
  const numbers = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'half': '0.5',
    'quarter': '0.25',
  };
  for (final entry in numbers.entries) {
    text = text.replaceAll(RegExp('\\b${entry.key}\\b'), entry.value);
  }
  const unit =
      r'(kg|kgs|kilograms?|kilos?|g|grams?|l|litres?|liters?|ml|millilitres?|milliliters?|packets?|cans?|pieces?|portions?|cups?|bottles?)';
  final end = RegExp(
    '^(.+?) (?:to )?(\\d+(?:\\.\\d+)?)\\s*$unit\$',
  ).firstMatch(text);
  final front = RegExp(
    '^(\\d+(?:\\.\\d+)?)\\s*$unit (?:of )?(.+)\$',
  ).firstMatch(text);
  String? name, amount;
  if (end != null) {
    name = end[1];
    amount = '${end[2]} ${end[3]}';
  } else if (front != null) {
    name = front[3];
    amount = '${front[1]} ${front[2]}';
  }
  if (name == null ||
      amount == null ||
      name.length > 200 ||
      RegExp(r'\b(and|then)\b').hasMatch(name))
    return null;
  if (double.tryParse(amount.split(' ').first) case final number?
      when number > 0) {
    return PantryVoiceCommand(remove: false, name: name.trim(), amount: amount);
  }
  return null;
}

List<PantryVoiceCommand>? parsePantryVoiceBatch(String transcript) {
  final parts = transcript
      .toLowerCase()
      .trim()
      .split(RegExp(r'[,;]|\band\b|\bthen\b'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.length > 20) return null;
  final result = <PantryVoiceCommand>[];
  String? verb;
  for (var part in parts) {
    final explicit = RegExp(
      r'^(?:please )?(add|save|set|update|remove|delete)\b',
    ).firstMatch(part);
    if (explicit != null)
      verb = explicit[1];
    else if (verb != null)
      part = '$verb $part';
    final command = parsePantryVoice(part);
    if (command == null) return null;
    result.add(command);
  }
  return result;
}

class PantryBatchEdit {
  const PantryBatchEdit({
    required this.command,
    this.id,
    this.kind = PantryKind.ingredient,
    this.previousAmount,
  });
  final PantryVoiceCommand command;
  final int? id;
  final PantryKind kind;
  final String? previousAmount;
}

List<PantryVoiceCommand>? pantryCommandsFromDraft(Map<String, dynamic> draft) {
  if (draft['status'] != 'draft' || draft['operations'] is! List) return null;
  final operations = draft['operations'] as List;
  if (operations.isEmpty || operations.length > 20) return null;
  final result = <PantryVoiceCommand>[];
  for (final raw in operations) {
    if (raw is! Map ||
        !['save', 'remove'].contains(raw['action']) ||
        raw['name'] is! String)
      return null;
    final name = (raw['name'] as String).trim();
    final amount = raw['amount'];
    if (name.isEmpty ||
        name.length > 200 ||
        RegExp(r'\b(all|everything)\b', caseSensitive: false).hasMatch(name))
      return null;
    final remove = raw['action'] == 'remove';
    if (!remove) {
      if (amount is! String || amount.trim().isEmpty || amount.length > 200)
        return null;
      final match = RegExp(
        r'^(\d+(?:\.\d+)?)(?=\s*[a-zA-Z(]|$)',
      ).firstMatch(amount);
      if (match == null || double.parse(match[1]!) <= 0) return null;
    }
    result.add(
      PantryVoiceCommand(
        remove: remove,
        name: name,
        amount: remove ? null : amount as String,
      ),
    );
  }
  return result;
}

/// Routes explicit stock updates, not dietary preferences or symptom reports.
bool isPantryUpdate(String text) {
  final s = text.toLowerCase().trim();
  if (RegExp(
    r"\b(allerg\w*|prefer\w*|avoid|cuisines?|meal plan|diet|do not eat|don't eat)\b",
  ).hasMatch(s))
    return false;
  if (RegExp(
    r"\b(?:i have|i feel|i am suffering from) (?:a |some )?(?:cold|fever|cough)\b",
  ).hasMatch(s))
    return false;
  if (RegExp(
    r"^(?:please )?(?:add|save|set|update|remove|delete)\b",
  ).hasMatch(s))
    return true;
  if (RegExp(
    r"\b(?:bought|purchased|picked up|ran out of|used up|finished all)\b",
  ).hasMatch(s))
    return true;
  final stockPrefix = RegExp(
    r"^(?:i have|i've got|i’ve got|i have got|there is|there are)\b",
  ).firstMatch(s);
  if (stockPrefix == null) return false;
  final tail = s
      .substring(stockPrefix.end)
      .trim()
      .replaceFirst(RegExp(r'^(?:some|a|an|few) '), '');
  final foodFirst = foodSuggestions.any(
    (food) => [food.id, ...food.aliases].any(
      (v) =>
          RegExp('^' + RegExp.escape(v.toLowerCase()) + r'\b').hasMatch(tail),
    ),
  );
  return foodFirst ||
      RegExp(
        r'\d|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|half|quarter|kg|kilo|litre|liter|pantry)\b',
      ).hasMatch(tail);
}
