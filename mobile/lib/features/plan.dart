import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({
    super.key,
    required this.session,
    required this.onPanel,
    required this.onRecipe,
    required this.onShop,
  });
  final SessionController session;
  final ValueChanged<Panel> onPanel;
  final ValueChanged<MealType> onRecipe;
  final VoidCallback onShop;
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final rotationInput = TextEditingController();
  @override
  void dispose() {
    rotationInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (s.holdReason != null) {
      return PageContent(
        pageKey: 'plan-hold',
        children: [
          const Eyebrow('Your plan'),
          const Heading('A check before we plan.'),
          InfoNote(s.holdReason!, title: 'Planning paused', amber: true),
          const Text(
            'Your pantry and saved details are still available.',
            style: TextStyle(fontSize: 13, color: ValoraColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () =>
                widget.onPanel(s.safetyPaused ? Panel.memory : Panel.rules),
            child: const Text('Review details'),
          ),
          OutlinedButton(
            onPressed: () => widget.onPanel(Panel.pantry),
            child: const Text('View pantry'),
          ),
        ],
      );
    }
    return PageContent(
      pageKey: 'plan',
      children: [
        const Eyebrow('Draft · Not ordered'),
        const Heading(
          'Review your meals.',
          subtitle: 'Five-day illustrative plan · one person.',
        ),
        if (s.foodEditError.isNotEmpty) InfoNote(s.foodEditError, amber: true),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Start a new draft for tomorrow'),
            onPressed: () async {
              final generation = s.accountGeneration;
              final replace = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Replace this draft?'),
                  content: const Text(
                    'This resets all five days to the example meals starting tomorrow. Your pantry and meal log stay as they are.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Start new draft'),
                    ),
                  ],
                ),
              );
              if (replace == true && generation == s.accountGeneration)
                s.startNewDraft();
            },
          ),
        ),
        SizedBox(
          height: 44 + MediaQuery.textScalerOf(context).scale(32),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final date = DateUtilsLocal.offset(s.firstDate, i);
              final selected = s.day == i;
              return Semantics(
                selected: selected,
                button: true,
                label: dateLabel(date),
                child: InkWell(
                  onTap: () => s.selectDay(i),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 24 + MediaQuery.textScalerOf(context).scale(42),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? ValoraColors.forest : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected
                            ? ValoraColors.forest
                            : ValoraColors.line,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dateLabel(date).split(' ').first,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.white70
                                : ValoraColors.muted,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : ValoraColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            const Pill('~25 min active time'),
            Pill(
              s.canUseQuote ? '₹640 example estimate' : 'New quote needed',
              amber: true,
            ),
            Pill(s.profile.coverage),
          ],
        ),
        const SizedBox(height: 13),
        ...s.plannedTypes.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MealCard(
              type: type,
              session: s,
              onRecipe: () => widget.onRecipe(type),
            ),
          ),
        ),
        if (!s.canUseQuote)
          const InfoNote(
            'Your meal or pantry changes need a fresh quantity and price calculation before ordering.',
            title: 'Ingredient checklist updated',
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ValoraColors.mint,
            border: Border.all(color: const Color(0xFFBCD1BF)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Want another direction?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Change this draft. Your saved food rules stay in place.',
                style: TextStyle(fontSize: 11, color: ValoraColors.muted),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final direction in [
                    ('italian', 'Something Italian'),
                    ('quick', 'Simple & quick'),
                    ('different', 'Something different'),
                  ])
                    ActionChip(
                      label: Text(
                        direction.$2,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => s.rotate(direction.$1),
                      backgroundColor: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 9),
              TextField(
                controller: rotationInput,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Or tell us what you feel like…',
                  suffixIcon: IconButton(
                    tooltip: 'Change this draft',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _rotate(context),
                  ),
                ),
                onSubmitted: (_) => _rotate(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        OutlinedButton.icon(
          onPressed: () => widget.onPanel(Panel.prepared),
          icon: const Icon(Icons.restaurant_outlined, size: 18),
          label: const Text('Order a meal instead'),
        ),
        const SizedBox(height: 9),
        FilledButton(
          onPressed: s.activeTypes.isEmpty
              ? null
              : s.canUseQuote
              ? widget.onShop
              : () => widget.onPanel(Panel.ingredients),
          child: Text(
            s.canUseQuote ? 'Review groceries →' : 'Review ingredients →',
          ),
        ),
      ],
    );
  }

  void _rotate(BuildContext context) {
    if (!widget.session.rotateFromText(rotationInput.text)) {
      toast(
        context,
        'Try “Italian”, “simple and quick”, or “something different”. Other changes need the planning agent.',
      );
    } else {
      rotationInput.clear();
    }
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.type,
    required this.session,
    required this.onRecipe,
  });
  final MealType type;
  final SessionController session;
  final VoidCallback onRecipe;
  @override
  Widget build(BuildContext context) {
    final slot = session.slot(type), recipe = session.recipe(type);
    return Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ValoraColors.mint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              slot.removed ? Icons.add : mealIcon(type),
              size: 26,
              color: ValoraColors.forest,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mealLabel(type).toUpperCase()} · ${recipe.minutes} MIN',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ValoraColors.muted,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  slot.removed ? 'Removed from this draft' : recipe.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (slot.removed)
                  TextButton(
                    onPressed: () => session.removeMeal(type, false),
                    child: const Text('Add a meal back'),
                  )
                else ...[
                  const SizedBox(height: 5),
                  Text(
                    recipe.ingredients.join(', '),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: ValoraColors.muted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Servings',
                          style: TextStyle(
                            fontSize: 11,
                            color: ValoraColors.muted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Decrease ${mealLabel(type)} servings',
                        onPressed: slot.servings > 1
                            ? () => session.setServings(type, slot.servings - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 21),
                      ),
                      Text(
                        '${slot.servings}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase ${mealLabel(type)} servings',
                        onPressed: slot.servings < 4
                            ? () => session.setServings(type, slot.servings + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline, size: 21),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 1,
                    children: [
                      TextButton(
                        onPressed: () => session.swap(type),
                        child: const Text('Swap'),
                      ),
                      TextButton(
                        onPressed: () => session.removeMeal(type, true),
                        child: const Text('Remove'),
                      ),
                      TextButton(
                        onPressed: onRecipe,
                        child: const Text('Recipe'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
