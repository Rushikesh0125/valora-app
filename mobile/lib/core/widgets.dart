import 'tag_suggestions.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

String money(int value) {
  final s = value.toString();
  if (s.length <= 3) return '₹$s';
  final last = s.substring(s.length - 3);
  final first = s.substring(0, s.length - 3);
  return '₹$first,$last';
}

String mealLabel(MealType type) => switch (type) {
  MealType.breakfast => 'Breakfast',
  MealType.lunch => 'Lunch',
  MealType.dinner => 'Dinner',
};
IconData mealIcon(MealType type) => switch (type) {
  MealType.breakfast => Icons.breakfast_dining_outlined,
  MealType.lunch => Icons.lunch_dining_outlined,
  MealType.dinner => Icons.dinner_dining_outlined,
};
String dateLabel(DateTime date) =>
    '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1]} ${date.day}';
void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});
  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.scaleDown,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'valora',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: ValoraColors.forest,
              letterSpacing: -1.4,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              color: Color(0xFFA2C9AE),
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      maxLines: 1,
    ),
  );
}

class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.children,
    this.controller,
    this.pageKey,
  });
  final List<Widget> children;
  final ScrollController? controller;
  final String? pageKey;
  @override
  Widget build(BuildContext context) => ListView(
    key: pageKey == null ? null : PageStorageKey(pageKey),
    controller: controller,
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: children,
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        color: ValoraColors.muted,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.25,
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.subtitle});
  final String text;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              color: ValoraColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.selected = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(19),
      boxShadow: const [
        BoxShadow(
          color: Color(0x071F3925),
          blurRadius: 15,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      color: selected ? const Color(0xFFF1F8F1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: selected ? ValoraColors.forest : ValoraColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.amber = false, this.red = false});
  final String text;
  final bool amber, red;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: red
          ? ValoraColors.red
          : amber
          ? ValoraColors.amber
          : ValoraColors.mint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: red
            ? const Color(0xFFA04C42)
            : amber
            ? const Color(0xFF8D6831)
            : ValoraColors.forest,
      ),
    ),
  );
}

class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.title, this.amber = false});
  final String text;
  final String? title;
  final bool amber;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: amber ? ValoraColors.amber : ValoraColors.mint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: ValoraColors.muted,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class Field extends StatelessWidget {
  const Field(
    this.label, {
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.lines = 1,
  });
  final String label, value;
  final String? hint;
  final int lines;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextFormField(
          key: ValueKey(label),
          initialValue: value,
          onChanged: onChanged,
          maxLines: lines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: ValoraColors.muted,
      ),
    ),
  );
}

class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<String> items;
  final Set<String> selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 280
          ? constraints.maxWidth
          : (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final active = selected.contains(item);
          return SizedBox(
            width: width,
            child: Semantics(
              selected: active,
              button: true,
              child: InkWell(
                onTap: () => onSelect(item),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE9F3EA) : Colors.white,
                    border: Border.all(
                      color: active ? ValoraColors.forest : ValoraColors.line,
                      width: active ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: active
                            ? ValoraColors.forest
                            : const Color(0xFFA3B6A6),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? ValoraColors.forest
                                : ValoraColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: ValoraColors.mint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: items.map((item) {
        return Expanded(
          child: Semantics(
            selected: item == selected,
            button: true,
            child: InkWell(
              onTap: () => onSelect(item),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                constraints: const BoxConstraints(minHeight: 43),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item == selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  item,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: item == selected
                        ? ValoraColors.forest
                        : ValoraColors.muted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: ValoraColors.muted),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class ActionRow extends StatelessWidget {
  const ActionRow(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    super.key,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
    leading: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: ValoraColors.mint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: ValoraColors.forest, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 11, color: ValoraColors.muted),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      size: 20,
      color: ValoraColors.muted,
    ),
    onTap: onTap,
  );
}

class TagField extends StatefulWidget {
  const TagField(
    this.label, {
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLength = 300,
    this.suggestions = const [],
  });
  final String label, value;
  final String? hint;
  final int maxLength;
  final List<TagSuggestion> suggestions;
  final ValueChanged<String> onChanged;
  @override
  State<TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<TagField> {
  final input = TextEditingController();
  late List<String> items = _parse(widget.value);
  String? _lastEmitted;
  List<String> _parse(String value) {
    final seen = <String>{};
    return value
        .split(RegExp(r'[,;\n]'))
        .map((v) {
          final term = v.trim();
          for (final option in widget.suggestions) {
            if (option.isExact(term)) return option.id;
          }
          return term;
        })
        .where((v) => v.isNotEmpty && seen.add(v.toLowerCase()))
        .toList();
  }

  @override
  void didUpdateWidget(covariant TagField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _lastEmitted) {
      items = _parse(widget.value);
      input.clear();
    }
  }

  void _emit() {
    // Persist drafts without letting canonical aliases exceed the storage limit.
    final raw = [
      ...items,
      input.text.trim(),
    ].where((v) => v.isNotEmpty).join(', ');
    final normalized = _parse(raw).join(', ');
    final value = normalized.length <= widget.maxLength ? normalized : raw;
    if (value.length > widget.maxLength) return;
    _lastEmitted = value;
    widget.onChanged(value);
  }

  void _add([String? selected]) {
    final value = selected ?? input.text;
    if (value.trim().isEmpty ||
        _parse([...items, value].join(', ')).join(', ').length >
            widget.maxLength)
      return;
    setState(() {
      items = _parse([...items, value].join(', '));
      input.clear();
    });
    _emit();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  InputChip(
                    label: Text(
                      widget.suggestions
                              .where((s) => s.id == item)
                              .map((s) => s.label)
                              .firstOrNull ??
                          item,
                    ),
                    backgroundColor: ValoraColors.mint,
                    deleteButtonTooltipMessage: 'Remove $item',
                    onDeleted: () {
                      setState(() => items.remove(item));
                      _emit();
                    },
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey(widget.label),
                controller: input,
                textInputAction: TextInputAction.done,
                enabled:
                    items.isEmpty ||
                    items.join(', ').length + 2 < widget.maxLength,
                maxLength:
                    (widget.maxLength -
                            items.join(', ').length -
                            (items.isEmpty ? 0 : 2))
                        .clamp(1, widget.maxLength),
                onChanged: (_) {
                  setState(() {});
                  _emit();
                },
                onFieldSubmitted: (_) => _add(),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.hint ?? 'Type one item',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: input.text.trim().isEmpty ? null : _add,
              child: const Text('Add'),
            ),
          ],
        ),
        if (input.text.trim().isNotEmpty && widget.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option
                    in widget.suggestions
                        .where(
                          (s) => s.matches(input.text) && !items.contains(s.id),
                        )
                        .take(5))
                  ActionChip(
                    label: Text(option.label),
                    tooltip: option.aliases.isEmpty
                        ? option.label
                        : '${option.label}: ${option.aliases.join(', ')}',
                    onPressed:
                        _parse(
                              [...items, option.id].join(', '),
                            ).join(', ').length <=
                            widget.maxLength
                        ? () => _add(option.id)
                        : null,
                  ),
                if (!widget.suggestions.any((s) => s.isExact(input.text)))
                  ActionChip(
                    label: Text('Add custom: ${input.text.trim()}'),
                    onPressed: () => _add(),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
