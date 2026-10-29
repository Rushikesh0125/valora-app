import 'dart:convert';
import 'pantry_voice.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'onboarding.dart';

Future<void> showPanel(
  BuildContext context,
  SessionController session,
  Panel panel, {
  VoidCallback? onPlan,
}) {
  final title = switch (panel) {
    Panel.pantry => 'Pantry & leftovers',
    Panel.rules => 'Food rules',
    Panel.practical => 'Planning preferences',
    Panel.memory => 'Memory & saved facts',
    Panel.reports => 'Reports & photos',
    Panel.notifications => 'Notifications',
    Panel.settings => 'Notification preferences',
    Panel.privacy => 'Privacy & control',
    Panel.payments => 'Payment methods',
    Panel.ingredients => 'Ingredients for this draft',
    Panel.prepared => 'Order a meal instead',
    Panel.basket => 'Review before ordering',
  };
  return _showSheet(
    context,
    title,
    (context) => ListenableBuilder(
      listenable: session,
      builder: (context, _) => switch (panel) {
        Panel.pantry => _PantryPanel(session),
        Panel.rules => _RulesPanel(session),
        Panel.practical => Column(
          children: [
            PracticalFields(session: session),
            const SizedBox(height: 18),
            _Done(),
          ],
        ),
        Panel.memory => _MemoryPanel(session),
        Panel.reports => _ReportsPanel(session),
        Panel.notifications => _NotificationsPanel(session, onPlan),
        Panel.settings => _NotificationSettings(session),
        Panel.privacy => _PrivacyPanel(session),
        Panel.payments => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment credentials will be managed by a payment provider.',
              style: TextStyle(
                color: ValoraColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            SizedBox(height: 18),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.credit_card_off_outlined,
                    color: ValoraColors.forest,
                    size: 30,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No payment method connected',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'You will review the merchant, items, fees, and total before approving a purchase.',
                    style: TextStyle(
                      color: ValoraColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            _Done(),
          ],
        ),
        Panel.ingredients => _IngredientsPanel(session),
        Panel.prepared => _PreparedPanel(session: session),
        Panel.basket => _BasketPanel(session),
      },
    ),
  );
}

Future<void> _showSheet(
  BuildContext context,
  String title,
  WidgetBuilder builder,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: ValoraColors.canvas,
  showDragHandle: false,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (context) => FractionallySizedBox(
    heightFactor: .88,
    child: Column(
      children: [
        const SizedBox(height: 9),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: ValoraColors.line,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: builder(context),
          ),
        ),
      ],
    ),
  ),
);

class _Done extends StatelessWidget {
  const _Done();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Done'),
    ),
  );
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'Food rules and allergies stay separate from cuisine preferences.',
          style: TextStyle(
            fontSize: 12,
            color: ValoraColors.muted,
            height: 1.5,
          ),
        ),
      ),
      FoodRulesFields(session: session),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            final p = session.profile;
            if (p.allergies.contains('Other') &&
                    p.otherAllergy.trim().isEmpty ||
                p.health.contains('Other') && p.otherHealth.trim().isEmpty) {
              toast(context, 'Add a detail for the selected Other option.');
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('Done'),
        ),
      ),
    ],
  );
}

class _PantryPanel extends StatelessWidget {
  const _PantryPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Estimated amounts at home. A meal changes inventory only when you link it and confirm what remains.',
        style: TextStyle(fontSize: 12, color: ValoraColors.muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => _showSheet(
          context,
          'Pantry voice input',
          (_) => PantryVoicePanel(session: session),
        ),
        icon: const Icon(Icons.mic_none_rounded),
        label: const Text('Add or remove by voice'),
      ),
      const SizedBox(height: 12),
      if (session.pantry.isEmpty)
        const Surface(
          child: Text('No items listed. Add an ingredient or leftover.'),
        )
      else
        Surface(
          child: Column(
            children: session.pantry
                .map(
                  (item) => ActionRow(
                    item.kind == PantryKind.leftover
                        ? Icons.takeout_dining_outlined
                        : Icons.kitchen_outlined,
                    item.name,
                    '${item.kind == PantryKind.leftover ? 'Leftover' : 'Ingredient'} · ${item.amount} estimated',
                    () => _showSheet(
                      context,
                      'Correct pantry item',
                      (_) => _PantryEditor(session: session, item: item),
                    ),
                    key: ValueKey(item.id),
                  ),
                )
                .toList(),
          ),
        ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showSheet(
            context,
            'Add pantry item',
            (_) => _PantryEditor(session: session),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add item'),
        ),
      ),
    ],
  );
}

class _PantryEditor extends StatefulWidget {
  const _PantryEditor({required this.session, this.item});
  final SessionController session;
  final PantryItem? item;
  @override
  State<_PantryEditor> createState() => _PantryEditorState();
}

class _PantryEditorState extends State<_PantryEditor> {
  final form = GlobalKey<FormState>();
  late final int generation;
  late final int foodGeneration;
  @override
  void initState() {
    super.initState();
    generation = widget.session.accountGeneration;
    foodGeneration = widget.session.foodRecordsGeneration;
  }

  late final name = TextEditingController(text: widget.item?.name ?? '');
  late final amount = TextEditingController(text: widget.item?.amount ?? '');
  late PantryKind kind = widget.item?.kind ?? PantryKind.ingredient;
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('What is it?'),
        Segments(
          items: const ['Ingredient', 'Leftover'],
          selected: kind == PantryKind.ingredient ? 'Ingredient' : 'Leftover',
          onSelect: (v) => setState(
            () => kind = v == 'Ingredient'
                ? PantryKind.ingredient
                : PantryKind.leftover,
          ),
        ),
        const SizedBox(height: 17),
        const FieldLabel('Item'),
        TextFormField(
          controller: name,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'e.g. Tomatoes or cooked rice',
          ),
          validator: _required,
        ),
        const SizedBox(height: 17),
        const FieldLabel('Amount left'),
        TextFormField(
          controller: amount,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'e.g. 3 pieces or 2 portions',
          ),
          validator: _required,
        ),
        const InfoNote(
          'Record an estimate you can correct later. Raw ingredients and cooked leftovers are separate items.',
        ),
        if (widget.item != null)
          TextButton.icon(
            onPressed: () {
              if (generation != widget.session.accountGeneration) {
                Navigator.pop(context);
                return;
              }
              if (foodGeneration != widget.session.foodRecordsGeneration) {
                toast(context, 'Your food records changed. Reopen this form.');
                return;
              }
              final error = widget.session.removePantry(widget.item!.id);
              if (error != null) {
                toast(context, error);
                return;
              }
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove from pantry'),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              if (generation != widget.session.accountGeneration) {
                Navigator.pop(context);
                return;
              }
              if (foodGeneration != widget.session.foodRecordsGeneration) {
                toast(context, 'Your food records changed. Reopen this form.');
                return;
              }
              final error = widget.session.savePantry(
                id: widget.item?.id,
                name: name.text,
                amount: amount.text,
                kind: kind,
              );
              if (error != null) {
                toast(context, error);
                return;
              }
              Navigator.pop(context);
            },
            child: const Text('Save item'),
          ),
        ),
      ],
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Please add this detail.' : null;

Future<void> showRecipe(
  BuildContext context,
  SessionController session,
  MealType type,
) => _showSheet(
  context,
  session.recipe(type).name,
  (context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final recipe = session.recipe(type);
      if (session.holdReason != null)
        return InfoNote(session.holdReason!, title: 'Recipe check needed');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pill(
            '${session.slot(type).servings} serving(s) · ${recipe.minutes} min · sample recipe',
          ),
          const SizedBox(height: 16),
          const FieldLabel('Ingredients'),
          Surface(
            child: Column(
              children: recipe.ingredients
                  .map((v) => SummaryRow(v, 'Quantity needs verification'))
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Simple method'),
          ...recipe.method.asMap().entries.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0${step.key + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ValoraColors.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.value,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const InfoNote(
            'Illustrative recipe. Exact quantities, ingredient safety, and nutrients are not verified.',
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => showIntake(
                context,
                session,
                name: recipe.name,
                portion: '${session.slot(type).servings} serving(s)',
              ),
              child: const Text('I ate this'),
            ),
          ),
        ],
      );
    },
  ),
);

Future<void> showIntake(
  BuildContext context,
  SessionController session, {
  String name = '',
  String portion = '1 serving',
}) => _showSheet(
  context,
  'Confirm what you ate',
  (_) => _IntakeEditor(
    session: session,
    initialName: name,
    initialPortion: portion,
  ),
);

class _IntakeEditor extends StatefulWidget {
  const _IntakeEditor({
    required this.session,
    required this.initialName,
    required this.initialPortion,
  });
  final SessionController session;
  final String initialName, initialPortion;
  @override
  State<_IntakeEditor> createState() => _IntakeEditorState();
}

class _IntakeEditorState extends State<_IntakeEditor> {
  final form = GlobalKey<FormState>();
  late final int generation;
  late final int foodGeneration;
  @override
  void initState() {
    super.initState();
    generation = widget.session.accountGeneration;
    foodGeneration = widget.session.foodRecordsGeneration;
  }

  late final name = TextEditingController(text: widget.initialName);
  late final portion = TextEditingController(text: widget.initialPortion);
  final remaining = TextEditingController();
  int sourceId = 0;
  @override
  void dispose() {
    name.dispose();
    portion.dispose();
    remaining.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Only a meal you confirm counts as eaten.',
          style: TextStyle(fontSize: 12, color: ValoraColors.muted),
        ),
        const SizedBox(height: 17),
        const FieldLabel('Meal or food'),
        TextFormField(
          controller: name,
          maxLength: 200,
          validator: _required,
          decoration: const InputDecoration(
            hintText: 'e.g. Chickpea rice bowl',
          ),
        ),
        const SizedBox(height: 17),
        const FieldLabel('Portion you ate'),
        TextFormField(
          controller: portion,
          maxLength: 200,
          validator: _required,
          decoration: const InputDecoration(
            hintText: 'e.g. 1 bowl or 100 g cooked rice',
          ),
        ),
        const SizedBox(height: 17),
        const FieldLabel('Used something from your pantry?'),
        DropdownButtonFormField<int>(
          initialValue: sourceId,
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: 0,
              child: Text(
                'No linked pantry item',
                style: TextStyle(fontSize: 12),
              ),
            ),
            ...widget.session.pantry.map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(
                  '${item.name} · ${item.amount}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() {
            sourceId = v ?? 0;
            remaining.text = sourceId == 0
                ? ''
                : widget.session.pantry
                      .firstWhere((p) => p.id == sourceId)
                      .amount;
          }),
        ),
        if (sourceId != 0) ...[
          const SizedBox(height: 17),
          const FieldLabel('How much remains at home?'),
          TextFormField(
            controller: remaining,
            maxLength: 200,
            validator: _required,
            decoration: const InputDecoration(
              hintText: 'e.g. 900 g uncooked rice',
            ),
          ),
          const InfoNote(
            'Confirm the remaining amount yourself. Valora will not guess raw-to-cooked conversions or subtract it twice.',
          ),
        ] else
          const InfoNote('Your pantry estimate will stay as it is.'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              if (generation != widget.session.accountGeneration) {
                Navigator.pop(context);
                return;
              }
              if (foodGeneration != widget.session.foodRecordsGeneration) {
                toast(context, 'Your food records changed. Reopen this form.');
                return;
              }
              final error = widget.session.recordIntake(
                name: name.text,
                portion: portion.text,
                sourceId: sourceId == 0 ? null : sourceId,
                remaining: sourceId == 0 ? null : remaining.text,
              );
              if (error != null) {
                toast(context, error);
                return;
              }
              Navigator.pop(context);
              toast(
                context,
                'Meal confirmed${sourceId == 0 ? '.' : ' and pantry amount corrected.'}',
              );
            },
            child: const Text('Confirm meal'),
          ),
        ),
      ],
    ),
  );
}

class _IngredientsPanel extends StatelessWidget {
  const _IngredientsPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'For ${dateLabel(DateUtilsLocal.offset(session.firstDate, session.day))}. Quantities and provider prices need a fresh calculation.',
        style: const TextStyle(
          color: ValoraColors.muted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      Surface(
        child: Column(
          children: session.activeTypes
              .map(
                (type) => SummaryRow(
                  '${mealLabel(type)} · ${session.slot(type).servings} serving(s)',
                  session.recipe(type).name,
                ),
              )
              .toList(),
        ),
      ),
      const Eyebrow('Ingredient checklist'),
      if (session.ingredients.isEmpty)
        const Text('No meals selected.')
      else
        Surface(
          child: Column(
            children: session.ingredients
                .map((v) => SummaryRow(v, 'To calculate'))
                .toList(),
          ),
        ),
      const InfoNote(
        'A fresh quote is required before comparing offers or approving an order.',
        title: 'Quote needed',
        amber: true,
      ),
      const _Done(),
    ],
  );
}

class _BasketPanel extends StatelessWidget {
  const _BasketPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    if (!session.canUseQuote || !session.planReviewed)
      return const InfoNote(
        'This basket no longer matches the draft. Review the plan and request a fresh quote.',
      );
    final offer = SessionController.grocers[session.selectedGrocer];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill('EXAMPLE · NOT A LIVE ORDER'),
        const SizedBox(height: 16),
        Surface(
          child: Column(
            children: [
              SummaryRow('Merchant', offer.name),
              ...session.basket.map((item) => SummaryRow(item.$1, item.$2)),
              const Divider(height: 14),
              SummaryRow('Delivery', offer.slot),
              const SummaryRow('Substitutions', 'Ask me first'),
              SummaryRow('Items subtotal', money(offer.subtotal)),
              SummaryRow('Delivery + fees', money(offer.fees)),
              const Divider(height: 14),
              SummaryRow('Total to review', money(offer.total)),
            ],
          ),
        ),
        const InfoNote(
          'Approval in the live app will apply only to this merchant, basket, delivery window, and maximum total. Any change needs a fresh approval.',
          amber: true,
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (!session.canUseQuote || !session.planReviewed) return;
              Navigator.pop(context);
              toast(
                context,
                'Example reviewed. No order or payment was submitted.',
              );
            },
            child: const Text('Approve example'),
          ),
        ),
      ],
    );
  }
}

class _PreparedPanel extends StatefulWidget {
  const _PreparedPanel({required this.session});
  final SessionController session;
  @override
  State<_PreparedPanel> createState() => _PreparedPanelState();
}

class _PreparedPanelState extends State<_PreparedPanel> {
  bool review = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (s.foodHoldReason != null)
      return Column(
        children: [
          InfoNote(
            s.foodHoldReason!,
            title: 'Options held for review',
            amber: true,
          ),
          const Text(
            'Restaurant ingredients and preparation must be verified before suggesting a suitable dish.',
            style: TextStyle(
              fontSize: 12,
              color: ValoraColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () => showPanel(context, s, Panel.rules),
            child: const Text('Review your details'),
          ),
        ],
      );
    final offer = s.prepared[s.selectedPrepared];
    if (review)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Pill('SAMPLE OFFER · NOT LIVE'),
          const SizedBox(height: 15),
          Heading(
            offer.dish,
            subtitle: '${offer.restaurant} · ${offer.cuisine} · ${offer.eta}',
          ),
          Surface(
            child: Column(
              children: [
                const SummaryRow(
                  'Ordering platform',
                  'Delivery partner · sample',
                ),
                SummaryRow('Menu description', offer.ingredients),
                const SummaryRow('Food-rule check', 'Not verified'),
                SummaryRow('Meal price', money(offer.price)),
                SummaryRow('Delivery + fees', money(offer.fees)),
                const Divider(height: 14),
                SummaryRow('Example total', money(offer.total)),
              ],
            ),
          ),
          const InfoNote(
            'Restaurant, menu, ingredients, portions, availability, and prices are examples. No restaurant is contacted in this preview.',
            amber: true,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                toast(context, 'Sample meal reviewed. No order was placed.');
              },
              child: const Text('Approve example meal'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => review = false),
              child: const Text('Choose another'),
            ),
          ),
        ],
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Best example match for your cuisine and preferences.',
          style: TextStyle(fontSize: 12, color: ValoraColors.muted),
        ),
        const Eyebrow('Sample delivery offers'),
        ...s.prepared.asMap().entries.map((entry) {
          final o = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => s.selectPrepared(entry.key),
              borderRadius: BorderRadius.circular(19),
              child: Surface(
                selected: s.selectedPrepared == entry.key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.ramen_dining_outlined,
                          size: 29,
                          color: ValoraColors.forest,
                        ),
                        const Spacer(),
                        if (entry.key == 0) const Pill('Best match'),
                        Icon(
                          s.selectedPrepared == entry.key
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: ValoraColors.forest,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      o.dish,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${o.restaurant} · ${o.cuisine}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ValoraColors.muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      o.fit,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ValoraColors.forest,
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${o.eta}\n${money(o.price)} + ${money(o.fees)} delivery',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ValoraColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          money(o.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ValoraColors.forest,
                            fontSize: 19,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const InfoNote(
          'Sample offers. Real ranking will use live menus, complete ingredients, portions, delivery time, and full cost.',
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => review = true),
            child: const Text('Review selected meal →'),
          ),
        ),
      ],
    );
  }
}

String _factText(SavedFact fact) {
  if (fact.key != 'meal_style') return fact.value;
  try {
    final value = jsonDecode(fact.value) as Map<String, dynamic>;
    final until = DateTime.parse(value['expiresAt'] as String).toLocal();
    final expired = until.isBefore(DateTime.now());
    return '${value['style']} meals · ${expired ? 'Expired' : 'Until'} ${until.day}/${until.month} ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return 'Comfort meal preference';
  }
}

class _MemoryPanel extends StatelessWidget {
  const _MemoryPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Details you have shared and confirmed. Tap a fact to inspect its source and control its use.',
        style: TextStyle(fontSize: 12, color: ValoraColors.muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      ...session.facts.map(
        (fact) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Surface(
            child: ActionRow(
              Icons.bookmark_outline_rounded,
              fact.label,
              '${_factText(fact)}${session.pausedFacts.contains(fact.key) ? ' · Paused' : ''}',
              () => _showSheet(
                context,
                'Saved fact',
                (context) => _FactDetail(session, fact.key),
              ),
            ),
          ),
        ),
      ),
      const InfoNote(
        'Pausing a safety detail pauses planning until it is reviewed. It does not make a restriction disappear.',
      ),
      const _Done(),
    ],
  );
}

class _FactDetail extends StatelessWidget {
  const _FactDetail(this.session, this.factKey);
  final SessionController session;
  final String factKey;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final matches = session.facts.where((f) => f.key == factKey);
      if (matches.isEmpty)
        return const Column(
          children: [
            Text('This fact has been removed.'),
            SizedBox(height: 16),
            _Done(),
          ],
        );
      final fact = matches.first;
      final paused = session.pausedFacts.contains(factKey);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pill(paused ? 'PAUSED' : 'CONFIRMED BY YOU'),
          const SizedBox(height: 15),
          Heading(fact.label, subtitle: _factText(fact)),
          Surface(
            child: Column(
              children: [
                SummaryRow('Source', fact.source),
                SummaryRow('Use', paused ? 'Paused' : 'Available for planning'),
                SummaryRow(
                  'Category',
                  fact.safety ? 'Safety-relevant detail' : 'Preference',
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => session.pauseFact(factKey),
              child: Text(paused ? 'Resume this fact' : 'Pause this fact'),
            ),
          ),
          if (factKey != 'pattern')
            TextButton.icon(
              onPressed: () async {
                final remove = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove this fact?'),
                    content: Text(
                      'Remove “${fact.value}” from this preview’s saved profile?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep it'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (remove == true) session.removeFact(factKey);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove fact'),
            ),
          const InfoNote(
            'To correct the meaning, edit the matching food rule or planning preference.',
          ),
          OutlinedButton(
            onPressed: () => showPanel(
              context,
              session,
              fact.safety ? Panel.rules : Panel.practical,
            ),
            child: const Text('Correct this detail'),
          ),
        ],
      );
    },
  );
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Extract facts, review them, then discard the original file.',
        style: TextStyle(fontSize: 12, color: ValoraColors.muted, height: 1.5),
      ),
      const SizedBox(height: 18),
      const Surface(
        child: Column(
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 35,
              color: ValoraColors.forest,
            ),
            SizedBox(height: 12),
            Text(
              'PDF, JPG or PNG',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Report intake is not connected in this preview. No file is selected or stored.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ValoraColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Heading(
        'Review before remembering.',
        subtitle:
            'See how a proposed fact is confirmed before it can shape a plan.',
      ),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => _showSheet(
            context,
            'Review a proposed fact',
            (_) => _SampleFactEditor(session),
          ),
          child: const Text('Preview sample fact review'),
        ),
      ),
    ],
  );
}

class _SampleFactEditor extends StatefulWidget {
  const _SampleFactEditor(this.session);
  final SessionController session;
  @override
  State<_SampleFactEditor> createState() => _SampleFactEditorState();
}

class _SampleFactEditorState extends State<_SampleFactEditor> {
  String kind = 'Food exclusion';
  final value = TextEditingController(text: 'Peanuts');
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Pill('PROPOSED · NOT SAVED'),
      const InfoNote(
        'Sample only. No file was processed. Sample source, page 1: “Avoid peanuts.”',
      ),
      const FieldLabel('Save this as'),
      DropdownButtonFormField<String>(
        initialValue: kind,
        items: [
          'Food exclusion',
          'Reported allergy',
          'Health context',
        ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => kind = v!),
      ),
      const SizedBox(height: 17),
      const FieldLabel('Detail'),
      TextField(controller: value),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: FilledButton(
              onPressed: () {
                if (value.text.trim().isEmpty) {
                  toast(context, 'Enter the detail you want to save.');
                  return;
                }
                widget.session.confirmSampleFact(kind, value.text);
                Navigator.pop(context);
                toast(context, 'Sample detail confirmed in this preview.');
              },
              child: const Text('Confirm & save'),
            ),
          ),
        ],
      ),
    ],
  );
}

class _PrivacyPanel extends StatelessWidget {
  const _PrivacyPanel(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Your information should be easy to inspect and correct.',
        style: TextStyle(fontSize: 13, color: ValoraColors.muted),
      ),
      const SizedBox(height: 15),
      Surface(
        child: Column(
          children: [
            ActionRow(
              Icons.description_outlined,
              'Reports & photos',
              'Original files are not retained',
              () => showPanel(context, session, Panel.reports),
            ),
            ActionRow(
              Icons.memory_outlined,
              'Saved facts',
              'Review, pause, correct or remove',
              () => showPanel(context, session, Panel.memory),
            ),
            ActionRow(
              Icons.notifications_none,
              'Notification privacy',
              'Health details stay off lock-screen previews',
              () => showPanel(context, session, Panel.settings),
            ),
          ],
        ),
      ),
      InfoNote(
        session.backendApi == null
            ? 'This preview keeps your details for this session.'
            : 'Your profile, preferences and saved facts are stored in your account. Cloud AI requires your separate consent. Report processing is not connected yet.',
      ),
      const _Done(),
    ],
  );
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel(this.session, this.onPlan);
  final SessionController session;
  final VoidCallback? onPlan;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Pill('TEMPLATE PREVIEWS'),
      const SizedBox(height: 15),
      _NotificationCard(
        Icons.calendar_today_outlined,
        'Tomorrow’s plan is ready',
        'Take a look when you have a moment.',
        'Review plan',
        () {
          Navigator.pop(context);
          onPlan?.call();
        },
      ),
      _NotificationCard(
        Icons.kitchen_outlined,
        'A quick pantry check',
        'Do you still have the chickpeas from your last shop?',
        'Review pantry',
        () => showPanel(context, session, Panel.pantry),
      ),
      _NotificationCard(
        Icons.restaurant_outlined,
        'How did your meal go?',
        'Confirm what you ate when you’re ready.',
        'Log a meal',
        () => showIntake(context, session),
      ),
      const SizedBox(height: 9),
      OutlinedButton.icon(
        onPressed: () => showPanel(context, session, Panel.settings),
        icon: const Icon(Icons.tune, size: 18),
        label: const Text('Timing & frequency'),
      ),
      const InfoNote(
        'These are template previews. Push delivery and notification voice replies are not connected.',
      ),
    ],
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard(
    this.icon,
    this.title,
    this.body,
    this.action,
    this.onTap,
  );
  final IconData icon;
  final String title, body, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: ValoraColors.forest),
              const SizedBox(width: 8),
              const Text(
                'VALORA',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: ValoraColors.muted,
                ),
              ),
              const Spacer(),
              const Text(
                'now',
                style: TextStyle(fontSize: 10, color: ValoraColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: ValoraColors.muted,
              height: 1.45,
            ),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    ),
  );
}

class _NotificationSettings extends StatelessWidget {
  const _NotificationSettings(this.session);
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: session.notificationsEnabled,
        onChanged: (v) =>
            session.updateNotifications(() => session.notificationsEnabled = v),
        title: const Text(
          'Allow proactive prompts',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      const SizedBox(height: 12),
      const FieldLabel('What would you like to hear about?'),
      ChoiceGrid(
        items: const [
          'Plan ready',
          'Pantry check',
          'Meal check-in',
          'Profile questions',
        ],
        selected: session.notificationCategories,
        onSelect: (v) => session.updateNotifications(() {
          if (!session.notificationCategories.remove(v))
            session.notificationCategories.add(v);
        }),
      ),
      const SizedBox(height: 19),
      const FieldLabel('Frequency'),
      DropdownButtonFormField<String>(
        initialValue: session.frequency,
        items: ['Daily', 'A few times a week', 'Only when needed']
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (v) =>
            session.updateNotifications(() => session.frequency = v!),
      ),
      const SizedBox(height: 18),
      const FieldLabel('Plan suggestions'),
      Segments(
        items: const ['Morning', 'Evening'],
        selected: session.profile.planningTime,
        onSelect: (v) =>
            session.updateNotifications(() => session.profile.planningTime = v),
      ),
      const SizedBox(height: 18),
      const FieldLabel('Quiet hours'),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _time(context, true),
              child: Text('From ${session.quietStart}'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _time(context, false),
              child: Text('Until ${session.quietEnd}'),
            ),
          ),
        ],
      ),
      const InfoNote(
        'Sensitive health details stay out of lock-screen previews. You can skip or snooze a prompt.',
      ),
      const _Done(),
    ],
  );
  Future<void> _time(BuildContext context, bool start) async {
    final parts = (start ? session.quietStart : session.quietEnd).split(':');
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (chosen == null) return;
    final text =
        '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}';
    session.updateNotifications(() {
      if (start)
        session.quietStart = text;
      else
        session.quietEnd = text;
    });
  }
}
