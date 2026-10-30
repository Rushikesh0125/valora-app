import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/core/widgets.dart';
import 'package:valora_mobile/core/tag_suggestions.dart';

void main() {
  testWidgets('allergy autocomplete retains food aliases such as paneer', (
    t,
  ) async {
    String saved = '';
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagField(
            'Allergies',
            value: '',
            suggestions: [...allergySuggestions, ...foodSuggestions],
            onChanged: (value) => saved = value,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'paneer');
    await t.pump();
    await t.tap(find.text('Milk / dairy'));
    await t.pump();
    expect(saved, 'milk');
  });

  testWidgets('live cuisine lookup is debounced and discards stale results', (
    t,
  ) async {
    final calls = <String>[];
    final first = Completer<List<TagSuggestion>>();
    final second = Completer<List<TagSuggestion>>();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagField(
            'Cuisine',
            value: '',
            onChanged: (_) {},
            onLookup: (q) {
              calls.add(q);
              return q == 'In' ? first.future : second.future;
            },
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'In');
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, isEmpty);
    await t.pump(const Duration(milliseconds: 250));
    expect(calls, ['In']);
    await t.enterText(find.byType(TextFormField), 'It');
    await t.pump(const Duration(milliseconds: 550));
    expect(calls, ['In', 'It']);
    first.complete([const TagSuggestion('Indian', 'Indian')]);
    await t.pump();
    expect(find.text('Indian'), findsNothing);
    second.complete([const TagSuggestion('Italian', 'Italian')]);
    await t.pumpAndSettle();
    expect(find.text('Italian'), findsOneWidget);
    await t.tap(find.text('Italian'));
    await t.pump();
    expect(find.byType(InputChip), findsOneWidget);
    expect(find.text('Powered by Qloo'), findsOneWidget);
  });
  testWidgets('live lookup ignores late results after disposal', (t) async {
    final pending = Completer<List<TagSuggestion>>();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagField(
            'Cuisine',
            value: '',
            suggestions: const [TagSuggestion('Indian', 'Indian')],
            onChanged: (_) {},
            onLookup: (_) => pending.future,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextFormField), 'In');
    await t.pump(const Duration(milliseconds: 550));
    await t.pumpWidget(const SizedBox());
    pending.complete([const TagSuggestion('Indian', 'Indian')]);
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'tags restore, add, deduplicate, remove and retain unfinished drafts',
    (tester) async {
      var saved = 'eggplant, mushrooms';
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return TagField(
                  'Foods to avoid',
                  value: saved,
                  onChanged: (value) => setState(() => saved = value),
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(InputChip), findsNWidgets(2));
      final field = find.byType(TextFormField);
      await tester.enterText(field, 'onion');
      await tester.pump();
      expect(saved, 'eggplant, mushrooms, onion');
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.byType(InputChip), findsNWidgets(3));
      await tester.enterText(field, 'EGGPLANT');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(InputChip), findsNWidgets(3));
      expect(saved, 'eggplant, mushrooms, onion');
      await tester.tap(find.byTooltip('Remove eggplant'));
      await tester.pump();
      expect(saved, 'mushrooms, onion');
      rebuild(() => saved = 'brinjal');
      await tester.pump();
      expect(find.byType(InputChip), findsOneWidget);
      expect(find.text('brinjal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'full-length saved value stays editable through removing a chip',
    (tester) async {
      var saved = 'long';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagField(
                'Other',
                maxLength: 4,
                value: saved,
                onChanged: (value) => setState(() => saved = value),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Remove long'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'milk');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved, 'milk');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'autocomplete resolves aliases to canonical stored values and supports custom items',
    (tester) async {
      var saved = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagField(
                'Foods',
                suggestions: foodSuggestions,
                value: saved,
                onChanged: (v) => setState(() => saved = v),
              ),
            ),
          ),
        ),
      );
      final input = find.byType(TextFormField);
      await tester.enterText(input, 'brin');
      await tester.pump();
      expect(find.widgetWithText(ActionChip, 'Eggplant'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Eggplant'));
      await tester.pump();
      expect(saved, 'eggplant');
      expect(find.widgetWithText(InputChip, 'Eggplant'), findsOneWidget);
      await tester.enterText(input, 'aubergine');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saved, 'eggplant');
      expect(find.byType(InputChip), findsOneWidget);
      await tester.enterText(input, 'custom food');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ActionChip, 'Add custom: custom food'),
      );
      await tester.pump();
      expect(saved, 'eggplant, custom food');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('autocomplete cannot exceed the existing field length limit', (
    tester,
  ) async {
    var saved = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TagField(
              'Foods',
              maxLength: 4,
              suggestions: foodSuggestions,
              value: saved,
              onChanged: (v) => setState(() => saved = v),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'brin');
    await tester.pump();
    final suggestion = tester.widget<ActionChip>(
      find.widgetWithText(ActionChip, 'Eggplant'),
    );
    expect(suggestion.onPressed, isNull);
    expect(saved.length, lessThanOrEqualTo(4));
  });
}
