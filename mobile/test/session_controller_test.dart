import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/core/models.dart';
import 'package:valora_mobile/core/session_controller.dart';

void main() {
  late SessionController session;
  setUp(() => session = SessionController());
  tearDown(() => session.dispose());

  test(
    'explicit saved-state reads do not invoke conversation or mutate facts',
    () {
      session.submitChat("What's in my pantry?");
      expect(session.focus, ChatFocus.pantry);
      expect(session.conversation, isFalse);
      expect(session.chat, isEmpty);
      session.submitChat('Show my allergies');
      expect(session.focus, ChatFocus.rules);
      expect(session.profile.allergies, isEmpty);
      session.submitChat('Show my next plan');
      expect(session.focus, ChatFocus.plan);
      expect(session.chat, isEmpty);
    },
  );

  test(
    'requests containing edits stay in conversation without saving changes',
    () {
      for (final message in [
        'Add a peanut allergy',
        'Show the pantry and update rice to 900 g',
        'I want more protein in my meal plan',
      ]) {
        session.submitChat(message);
        expect(session.conversation, isTrue);
      }
      expect(session.profile.allergies, isEmpty);
      expect(session.pantry.first.amount, '~1 kg');
      expect(session.chat.length, 6);
      expect(session.recipe(MealType.lunch).name, 'Chickpea rice bowl');
    },
  );

  test(
    'each day owns its portions and recipe edits; edits invalidate quotes',
    () {
      expect(session.reviewPlan(), isTrue);
      session.setServings(MealType.lunch, 2);
      expect(session.canUseQuote, isFalse);
      expect(session.planReviewed, isFalse);
      session.selectDay(1);
      expect(session.slot(MealType.lunch).servings, 1);
      session.rotate('italian');
      session.selectDay(0);
      expect(session.slot(MealType.lunch).servings, 2);
      expect(session.recipe(MealType.lunch).name, 'Chickpea rice bowl');
      expect(session.reviewPlan(), isFalse);
    },
  );

  test('meal coverage is respected in both plans and grocery approval', () {
    session.profile.coverage = 'Dinner only';
    expect(session.plannedTypes, [MealType.dinner]);
    expect(session.canUseQuote, isFalse);
    session.removeMeal(MealType.dinner, true);
    expect(session.activeTypes, isEmpty);
  });

  test('intake changes only explicitly linked pantry inventory', () {
    session.recordIntake(name: 'Rice bowl', portion: '100 g cooked');
    expect(session.pantry.first.amount, '~1 kg');
    session.recordIntake(
      name: 'Rice bowl',
      portion: '100 g cooked',
      sourceId: 1,
      remaining: '900 g uncooked',
    );
    expect(session.pantry.first.amount, '900 g uncooked');
    expect(session.intake.first.sourceName, 'Rice');
    expect(session.intake.first.remaining, '900 g uncooked');
    expect(session.intake.length, 2);
    expect(session.quoteStale, isTrue);
  });

  test(
    'allergies, exclusions, health context and paused safety facts hold meals',
    () {
      session.toggle(session.profile.allergies, 'Peanuts');
      expect(session.foodHoldReason, isNotNull);
      session.pauseFact('allergy:Peanuts');
      expect(session.safetyPaused, isTrue);
      expect(session.canUseQuote, isFalse);
      session.removeFact('allergy:Peanuts');
      expect(session.safetyPaused, isFalse);
      expect(session.foodHoldReason, isNull);
      session.pauseFact('pattern');
      expect(session.foodHoldReason, isNotNull);
    },
  );

  test(
    'health none is exclusive and does not create a health planning hold',
    () {
      session.toggleHealth('Diabetes');
      expect(session.hasHealth, isTrue);
      session.toggleHealth('None');
      expect(session.profile.health, {'None'});
      expect(session.hasHealth, isFalse);
      expect(session.holdReason, isNull);
      session.toggleHealth('Recent injury');
      expect(session.profile.health, {'Recent injury'});
    },
  );

  test('prepared food is available when the constraint is cooking time', () {
    session.profile.cookingMinutes = 5;
    expect(session.holdReason, isNotNull);
    expect(session.foodHoldReason, isNull);
    expect(session.prepared, isNotEmpty);
  });

  test(
    'Other values require a detail and sample facts require confirmation',
    () {
      session.profile.acknowledged = true;
      session.profile.allergies.add('Other');
      expect(session.validateProfile(), isNotNull);
      session.profile.otherAllergy = 'Sesame';
      expect(session.validateProfile(), isNull);
      session.profile.allergies.clear();
      session.confirmSampleFact('Food exclusion', 'Peanuts');
      expect(session.profile.exclusions, 'Peanuts');
      expect(session.profile.allergies, isEmpty);
      expect(
        session.facts.singleWhere((f) => f.key == 'exclusions').source,
        contains('Sample source'),
      );
    },
  );

  test('confirming another custom allergy preserves previous custom facts', () {
    session.confirmSampleFact('Reported allergy', 'Sesame');
    session.confirmSampleFact('Reported allergy', 'Mustard');
    expect(session.profile.otherAllergy, contains('Sesame'));
    expect(session.profile.otherAllergy, contains('Mustard'));
  });

  test(
    'Italian rotation targets the requested direction on every selected day',
    () {
      session.selectDay(3);
      session.rotate('italian');
      expect(session.recipe(MealType.lunch).name, 'Tomato pasta & greens');
      session.selectDay(4);
      session.rotate('italian');
      expect(session.recipe(MealType.dinner).name, 'Quick pesto pasta');
    },
  );
}
