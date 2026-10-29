import 'package:flutter/material.dart';
import '../core/first_day_planner.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class FirstDayPlanView extends StatelessWidget {
  const FirstDayPlanView({
    super.key,
    required this.planner,
    required this.onReview,
    this.compact = false,
    this.onOpen,
  });
  final FirstDayPlanner planner;
  final VoidCallback onReview;
  final bool compact;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      final data = planner.state;
      final ready = planner.status == 'ready';
      final needsConsent = planner.status == 'consent_required';
      final review =
          planner.status == 'review_required' ||
          data['error'] == 'preferences_changed';
      final preparing = planner.busy || planner.status == 'generating';
      final meals = (data['meals'] as List? ?? []).cast<Map<String, dynamic>>();
      return Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ready
                  ? 'Your first-day meals · ${data['date']}'
                  : 'Your first-day meal plan',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (preparing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Preparing the remaining meals today. Usually seconds; our target is under five minutes. Keep the app open while we prepare your plan.',
              ),
            ] else if (needsConsent) ...[
              const Text(
                'Allow NVIDIA Nemotron via Nebius to use your diet, cuisine, cooking time, budget and meal coverage for your first-day plan. Allergies and foods to avoid filter recipes on the server. Saved health details are not sent. You can turn cloud AI off in AI settings.',
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    planner.refresh(enableConsent: true, retry: true),
                child: const Text('Allow & prepare today’s meals'),
              ),
            ] else if (review) ...[
              Text(
                planner.preferencesPending
                    ? 'Saving your latest preferences before preparing your meals…'
                    : data['error'] == 'no_suitable_starter_recipe'
                    ? 'No recipe in the current collection matches all your saved food preferences and cooking-time limit. Your preferences have not been changed.'
                    : data['error'] == 'preferences_changed' ||
                          data['error'] == 'plan_outdated'
                    ? 'Preparing meals using your latest saved preferences.'
                    : 'A food restriction needs a more specific ingredient or allergen before we can safely match a recipe. Your other saved preferences are already applied.',
              ),
              if (!planner.preferencesPending &&
                  data['error'] != 'food_details_need_review')
                TextButton(
                  onPressed: () => planner.refresh(retry: true),
                  child: const Text('Prepare my meals'),
                ),
              if (data['error'] == 'food_details_need_review')
                TextButton(
                  onPressed: onReview,
                  child: const Text('Specify the food restriction'),
                ),
            ] else if (planner.status == 'no_meals_remaining' ||
                (ready && meals.isEmpty)) ...[
              const Text(
                'No meal slots remain today. We have not switched your first-day plan to tomorrow.',
              ),
            ] else if (ready) ...[
              Text(
                'Remaining meals for ${data['date']} · ${data['timeZone']}. Based on your confirmed preferences when created.',
              ),
              const SizedBox(height: 8),
              for (final meal in meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Recipe(meal: meal, compact: compact),
                ),
              if (!compact)
                Text(
                  'NVIDIA Nemotron via Nebius · ${data['model']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ValoraColors.muted,
                  ),
                ),
              const Text(
                'Starter meal suggestions. Prices and nutrition are not verified; check ingredients and portions before cooking.',
                style: TextStyle(fontSize: 11, color: ValoraColors.muted),
              ),
              if (compact && onOpen != null)
                TextButton(
                  onPressed: onOpen,
                  child: const Text('View recipes'),
                ),
            ] else ...[
              const Text(
                'Your plan is not ready. Check your connection and try again. We will not substitute a sample plan.',
              ),
              TextButton(
                onPressed: () => planner.refresh(retry: true),
                child: const Text('Retry first-day plan'),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _Recipe extends StatelessWidget {
  const _Recipe({required this.meal, required this.compact});
  final Map<String, dynamic> meal;
  final bool compact;
  void _fulfillment(
    BuildContext context,
    Map<String, dynamic> recipe,
    bool ingredients,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredients
                    ? 'Ingredients for ${recipe['name']}'
                    : 'Order ${recipe['name']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (ingredients) ...[
                for (final ingredient in recipe['ingredients'] as List)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text('• $ingredient'),
                  ),
                const Text(
                  'Review portions and quantities before buying. Pantry stock has not been deducted.',
                ),
              ],
              const SizedBox(height: 16),
              Text(
                ingredients
                    ? 'Swiggy Instamart ordering is not connected yet. This is your ingredient list, not a live cart.'
                    : 'Swiggy Food ordering is not connected yet. Restaurant availability, prices and delivery options are not available.',
              ),
              const SizedBox(height: 12),
              const Text(
                'No order has been placed. Check product labels and restaurant allergen information before purchasing.',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = meal['recipe'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${meal['meal']} · ${recipe['name']}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        Text('${recipe['minutes']} min'),
        if (!compact) ...[
          Text('Ingredients: ${(recipe['ingredients'] as List).join(', ')}'),
          const SizedBox(height: 6),
          for (final step in (recipe['steps'] as List).indexed)
            Text('${step.$1 + 1}. ${step.$2}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _fulfillment(context, recipe, true),
                icon: const Icon(Icons.shopping_basket_outlined, size: 18),
                label: const Text('Ingredients to order'),
              ),
              OutlinedButton.icon(
                onPressed: () => _fulfillment(context, recipe, false),
                icon: const Icon(Icons.restaurant_outlined, size: 18),
                label: const Text('Order this dish'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
