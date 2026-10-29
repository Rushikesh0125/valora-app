import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/core/widgets.dart';
import 'package:valora_mobile/core/tag_suggestions.dart';

void main() {
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
