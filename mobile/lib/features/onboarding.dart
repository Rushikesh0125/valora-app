import '../core/tag_suggestions.dart';
import 'package:flutter/material.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

const goalChoices = [
  'Easier meals',
  'More variety',
  'Eat more protein',
  'Steadier routine',
  'Spend less',
  'Other',
];
const allergyChoices = [
  'Peanuts',
  'Tree nuts',
  'Milk',
  'Eggs',
  'Wheat',
  'Other',
];
const healthChoices = [
  'None',
  'Diabetes',
  'High blood pressure',
  'Digestive issue',
  'Recent injury',
  'Other',
  'Prefer not to say',
];
const cuisineChoices = [
  'Indian',
  'Italian',
  'Asian',
  'Mediterranean',
  'Mexican',
  'Anything',
  'Other',
];
const eatingPatterns = ['Omnivore', 'Vegetarian', 'Vegan'];
const mealCoverage = [
  'Breakfast, lunch & dinner',
  'Lunch & dinner',
  'Dinner only',
];

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.session,
    required this.onReview,
  });
  final SessionController session;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return Scaffold(
      body: SafeArea(
        child: PageContent(
          pageKey: 'onboarding',
          children: [
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wordmark(),
                  ),
                ),
                Pill('About 2 min'),
              ],
            ),
            const SizedBox(height: 21),
            const Eyebrow('Getting to know you'),
            const Heading("Let's make food feel easier."),
            Question(
              1,
              'What would you like help with?',
              subtitle: 'Choose any that fit.',
              child: Column(
                children: [
                  ChoiceGrid(
                    items: goalChoices,
                    selected: p.goals,
                    onSelect: (v) => session.toggle(p.goals, v),
                  ),
                  if (p.goals.contains('Other'))
                    TagField(
                      'What else would you like help with?',
                      value: p.otherGoal,
                      suggestions: goalSuggestions,
                      maxLength: 300,
                      hint: 'Tell us briefly',
                      onChanged: (v) =>
                          session.updateProfile(() => p.otherGoal = v),
                    ),
                ],
              ),
            ),
            Question(
              2,
              'How do you usually eat?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Segments(
                    items: eatingPatterns,
                    selected: p.pattern,
                    onSelect: (v) => session.updateProfile(() => p.pattern = v),
                  ),
                  TagField(
                    'Foods you don’t eat (optional)',
                    value: p.exclusions,
                    suggestions: foodSuggestions,
                    maxLength: 2000,
                    hint: 'e.g. eggplant',
                    onChanged: (v) =>
                        session.updateProfile(() => p.exclusions = v),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 15),
                    child: Text(
                      'Something you don’t like to eat.',
                      style: TextStyle(fontSize: 11, color: ValoraColors.muted),
                    ),
                  ),
                  const FieldLabel('Meals to plan'),
                  DropdownButtonFormField<String>(
                    initialValue: p.coverage,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ValoraColors.ink,
                    ),
                    items: mealCoverage
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        session.updateProfile(() => p.coverage = v);
                    },
                  ),
                ],
              ),
            ),
            Question(
              3,
              'Any allergies?',
              child: FoodRulesFields(session: session, includePattern: false),
            ),
            Question(
              4,
              'What makes a plan practical?',
              subtitle: 'We’ll respect your time and spending limit.',
              child: PracticalFields(
                session: session,
                includePreferences: false,
              ),
            ),
            Question(
              5,
              'What do you enjoy?',
              subtitle: 'Pick a starting point. We’ll keep learning.',
              child: CuisineFields(session: session),
            ),
            CheckboxListTile(
              value: p.acknowledged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => session.updateProfile(
                () => p.acknowledged = v ?? false,
                affectsPlan: false,
              ),
              title: const Text(
                'I understand Valora helps with everyday food planning. I’ll confirm important details before they shape my plan.',
                style: TextStyle(
                  fontSize: 11,
                  color: ValoraColors.muted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 7),
            FilledButton(
              onPressed: () {
                final error = session.validateProfile();
                if (error != null)
                  toast(context, error);
                else
                  onReview();
              },
              child: const Text('See my profile summary →'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class Question extends StatelessWidget {
  const Question(
    this.number,
    this.title, {
    super.key,
    this.subtitle,
    required this.child,
  });
  final int number;
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFDFEEDF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: ValoraColors.forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ValoraColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        child,
        const Divider(height: 31),
      ],
    ),
  );
}

class FoodRulesFields extends StatelessWidget {
  const FoodRulesFields({
    super.key,
    required this.session,
    this.includePattern = true,
  });
  final SessionController session;
  final bool includePattern;
  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includePattern) ...[
          const FieldLabel('Eating pattern'),
          Segments(
            items: eatingPatterns,
            selected: p.pattern,
            onSelect: (v) => session.updateProfile(() => p.pattern = v),
          ),
          TagField(
            'Foods you don’t eat',
            value: p.exclusions,
            suggestions: foodSuggestions,
            maxLength: 2000,
            hint: 'e.g. eggplant',
            onChanged: (v) => session.updateProfile(() => p.exclusions = v),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Allergies you reported'),
        ],
        ChoiceGrid(
          items: allergyChoices,
          selected: p.allergies,
          onSelect: (v) => session.toggle(p.allergies, v),
        ),
        if (p.allergies.contains('Other'))
          TagField(
            'Which allergy?',
            value: p.otherAllergy,
            suggestions: allergySuggestions,
            maxLength: 500,
            hint: 'e.g. sesame',
            onChanged: (v) => session.updateProfile(() => p.otherAllergy = v),
          ),
        const SizedBox(height: 19),
        const FieldLabel('Current health context (optional)'),
        ChoiceGrid(
          items: healthChoices,
          selected: p.health,
          onSelect: session.toggleHealth,
        ),
        if (p.health.contains('Other'))
          TagField(
            'Tell us only what you want to share',
            value: p.otherHealth,
            suggestions: healthSuggestions,
            maxLength: 500,
            hint: 'e.g. a recent injury',
            onChanged: (v) => session.updateProfile(() => p.otherHealth = v),
          ),
      ],
    );
  }
}

class PracticalFields extends StatelessWidget {
  const PracticalFields({
    super.key,
    required this.session,
    this.includePreferences = true,
  });
  final SessionController session;
  final bool includePreferences;
  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Range(
          label: 'Weekly grocery budget',
          valueText: '${money(p.budget)} / week',
          value: p.budget,
          min: 500,
          max: 15000,
          divisions: 58,
          minLabel: '₹500',
          maxLabel: '₹15,000',
          onChanged: (v) => session.updateProfile(() => p.budget = v),
        ),
        const SizedBox(height: 14),
        _Range(
          label: 'Max cooking time per meal',
          valueText: '${p.cookingMinutes} min',
          value: p.cookingMinutes,
          min: 5,
          max: 120,
          divisions: 23,
          minLabel: '5 min',
          maxLabel: '120 min',
          onChanged: (v) => session.updateProfile(() => p.cookingMinutes = v),
        ),
        if (includePreferences) ...[
          const SizedBox(height: 19),
          const FieldLabel('Meals to plan'),
          DropdownButtonFormField<String>(
            initialValue: p.coverage,
            isExpanded: true,
            items: mealCoverage
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) session.updateProfile(() => p.coverage = v);
            },
          ),
          const SizedBox(height: 19),
          CuisineFields(session: session),
        ],
      ],
    );
  }
}

class _Range extends StatelessWidget {
  const _Range({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });
  final String label, valueText, minLabel, maxLabel;
  final int value, min, max, divisions;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: ValoraColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            valueText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ValoraColors.forest,
            ),
          ),
        ],
      ),
      Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions,
        semanticFormatterCallback: (_) => valueText,
        label: valueText,
        onChanged: (v) => onChanged(v.round()),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            minLabel,
            style: const TextStyle(fontSize: 10, color: ValoraColors.muted),
          ),
          Text(
            maxLabel,
            style: const TextStyle(fontSize: 10, color: ValoraColors.muted),
          ),
        ],
      ),
    ],
  );
}

class CuisineFields extends StatelessWidget {
  const CuisineFields({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChoiceGrid(
          items: cuisineChoices,
          selected: p.cuisines,
          onSelect: session.toggleCuisine,
        ),
        if (p.cuisines.contains('Other'))
          TagField(
            'Which cuisine?',
            value: p.otherCuisine,
            suggestions: cuisineSuggestions,
            maxLength: 300,
            hint: 'e.g. Korean',
            onChanged: (v) => session.updateProfile(() => p.otherCuisine = v),
          ),
        const SizedBox(height: 19),
        const FieldLabel('When should we suggest your next plan?'),
        Segments(
          items: const ['Morning', 'Evening'],
          selected: p.planningTime,
          onSelect: (v) => session.updateProfile(
            () => p.planningTime = v,
            affectsPlan: false,
          ),
        ),
      ],
    );
  }
}

class ProfileConfirmation extends StatelessWidget {
  const ProfileConfirmation({
    super.key,
    required this.session,
    required this.onEdit,
  });
  final SessionController session;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: session.savingAccount ? null : onEdit,
        tooltip: 'Edit answers',
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Wordmark(),
    ),
    body: PageContent(
      children: [
        const Eyebrow('Your starting profile'),
        const Heading(
          'Does this look right?',
          subtitle:
              'These are the details Valora will use for your first plan.',
        ),
        Surface(child: ProfileRows(session: session)),
        if (session.firstDayPlanner != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: session.firstPlanConsent,
            onChanged: session.savingAccount
                ? null
                : (value) => session.setFirstPlanConsent(value ?? false),
            title: const Text('Prepare my remaining meals today with Nebius'),
            subtitle: const Text(
              'Allow NVIDIA Nemotron via Nebius to receive my diet, cuisines, cooking time, budget and meal coverage. Allergies and foods to avoid are checked on the server. Qloo receives public taste IDs and cuisine signals to rank candidates; health, allergies and chat stay out of Qloo requests. Saved health details are not sent. Target: under five minutes after confirming. Cloud consent can be turned off later.',
            ),
          ),
        const InfoNote(
          'Safety details are based on what you reported. You can correct or remove them any time.',
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: session.savingAccount ? null : onEdit,
                child: const Text('Edit answers'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: session.savingAccount
                    ? null
                    : session.completeOnboarding,
                child: Text(
                  session.savingAccount
                      ? 'Saving…'
                      : session.firstDayPlanner != null &&
                            session.firstPlanConsent
                      ? 'Create my plan'
                      : 'Looks right',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ProfileRows extends StatelessWidget {
  const ProfileRows({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return Column(
      children: [
        SummaryRow('Goals', p.resolved(p.goals, p.otherGoal)),
        SummaryRow('Eating pattern', p.pattern),
        SummaryRow('Meals to plan', p.coverage),
        SummaryRow(
          'Foods to avoid',
          p.exclusions.trim().isEmpty ? 'None recorded' : p.exclusions,
        ),
        SummaryRow(
          'Allergies',
          p.allergies.isEmpty
              ? 'None reported'
              : p.resolved(p.allergies, p.otherAllergy),
        ),
        SummaryRow(
          'Health context',
          p.health.isEmpty ? 'Not shared' : p.resolved(p.health, p.otherHealth),
        ),
        SummaryRow('Weekly budget', '${money(p.budget)} / week'),
        SummaryRow('Cooking time', 'Up to ${p.cookingMinutes} min'),
        SummaryRow('Cuisines', p.resolved(p.cuisines, p.otherCuisine)),
        SummaryRow('Plan time', p.planningTime),
      ],
    );
  }
}
