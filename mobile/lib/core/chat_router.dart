import 'models.dart';

/// Match only whole saved-data questions. Mixed requests need conversation.
ChatFocus? savedChatFocus(String text) {
  final value = text
      .toLowerCase()
      .replaceAll('’', "'")
      .trim()
      .replaceAll(RegExp(r'[?.!]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^please '), '')
      .replaceFirst(RegExp(r' please$'), '');
  if (RegExp(
        r"^(?:(?:show|open|view)(?: me)? )?(?:my |the )?(?:today's (?:meal )?plan|(?:meal )?plan (?:for )?today)$",
      ).hasMatch(value) ||
      value == 'what am i eating today' ||
      value == 'what is my meal plan for today')
    return ChatFocus.plan;
  const subjects = <ChatFocus, String>{
    ChatFocus.pantry: r'(?:pantry|fridge|ingredients at home)',
    ChatFocus.rules:
        r'(?:allergies|allergy|food rules|food restrictions|restrictions|health context)',
    ChatFocus.limits:
        r'(?:budget|weekly budget|cooking time|planning limits|limits)',
    ChatFocus.plan: r'(?:(?:next |meal )?plan)',
    ChatFocus.profile:
        r'(?:profile|preferences|meal preferences?|food preferences?|eating pattern|cuisines|cuisine preferences)',
    ChatFocus.memory: r'(?:memory|saved facts|saved details)',
  };
  for (final entry in subjects.entries) {
    final noun = entry.value;
    if (RegExp(
          '^(?:(?:show|open|view)(?: me)? )?(?:my |the )?$noun\$',
        ).hasMatch(value) ||
        RegExp("^what(?:'s| is| are) (?:my |the )?$noun\$").hasMatch(value) ||
        RegExp('^what $noun do you have saved\$').hasMatch(value))
      return entry.key;
  }
  if (RegExp(
    r"^what(?:'s| is) in (?:my |the )?(?:pantry|fridge)$",
  ).hasMatch(value))
    return ChatFocus.pantry;
  if (value == 'how much is my budget' || value == 'how much can i spend')
    return ChatFocus.limits;
  if (value == 'what cuisines do i like' ||
      value == 'what is my preferred cuisine')
    return ChatFocus.profile;
  if (value == 'what do you remember about me') return ChatFocus.memory;
  if (value == 'what foods do i avoid') return ChatFocus.rules;
  return null;
}
