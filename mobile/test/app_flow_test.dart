import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/app.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/core/widgets.dart';

Future<void> onboard(WidgetTester tester) async {
  final ack = find.byType(CheckboxListTile);
  await tester.scrollUntilVisible(
    ack,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(ack);
  await tester.pumpAndSettle();
  final review = find.text('See my profile summary →');
  await tester.ensureVisible(review);
  await tester.tap(review);
  await tester.pumpAndSettle();
  expect(find.text('Does this look right?'), findsOneWidget);
  final confirm = find.text('Looks right');
  await tester.scrollUntilVisible(
    confirm,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chat opens pantry review and waits for confirmation', (t) async {
    final session = SessionController()..onboarded = true;
    addTearDown(session.dispose);
    await t.pumpWidget(ValoraApp(session: session));
    await t.pumpAndSettle();
    await session.submitChat('add rice two kg');
    await t.pumpAndSettle();
    expect(find.textContaining('Update Rice:'), findsOneWidget);
    expect(session.pantry.first.amount, '~1 kg');
    await t.ensureVisible(find.text('Confirm pantry change'));
    await t.tap(find.text('Confirm pantry change'));
    await t.pumpAndSettle();
    expect(session.pantry.first.amount, '2 kg');
  });

  testWidgets(
    'one-page onboarding preserves scroll and exposes an Other allergy field',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ValoraApp(session: SessionController()));
      expect(find.text("Let's make food feel easier."), findsOneWidget);
      final vegan = find.text('Vegan');
      await tester.scrollUntilVisible(
        vegan,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = position.pixels;
      await tester.tap(vegan);
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(offset, 1));
      expect(find.text('Do you eat eggs?'), findsNothing);
      expect(find.text('Foods you don’t eat (optional)'), findsOneWidget);
      final allergy = find.byWidgetPredicate(
        (w) => w is ChoiceGrid && w.items.contains('Peanuts'),
      );
      await tester.scrollUntilVisible(
        allergy,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(allergy);
      await tester.tap(
        find.descendant(of: allergy, matching: find.text('Other')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Which allergy?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom chat hides workspace cards and saved reads show a widget',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ValoraApp(session: SessionController()));
      await onboard(tester);
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        'I want more protein after joining the gym',
      );
      await tester.tap(find.byTooltip('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('What do you need\nright now?'), findsNothing);
      expect(find.text('Next plan'), findsNothing);
      expect(
        find.text('I want more protein after joining the gym'),
        findsOneWidget,
      );
      expect(find.byTooltip('Your space'), findsOneWidget);
      await tester.tap(find.byTooltip('Your space'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        "What's in my pantry?",
      );
      await tester.tap(find.byTooltip('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('What you have'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('main tabs and prepared-food review fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ValoraApp(session: SessionController()));
    await onboard(tester);
    for (final label in ['Plan', 'Insights', 'You', 'Chat']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    final order = find.text('Order a meal instead');
    await tester.scrollUntilVisible(
      order,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(order);
    await tester.pumpAndSettle();
    expect(find.text('Best match'), findsOneWidget);
    final review = find.text('Review selected meal →');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.text('Approve example meal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a confirmed meal can correct linked pantry inventory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ValoraApp(session: SessionController()));
    await onboard(tester);
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log a meal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Rice bowl');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '100 g cooked rice',
    );
    await tester.tap(find.text('No linked pantry item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice · ~1 kg').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(2),
      '900 g uncooked rice',
    );
    await tester.ensureVisible(find.text('Confirm meal'));
    await tester.tap(find.text('Confirm meal'));
    await tester.pumpAndSettle();
    expect(find.text('Rice bowl'), findsOneWidget);
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pantry & leftovers'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ingredient · 900 g uncooked rice estimated'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
