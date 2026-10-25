import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'ai_settings.dart';
import 'onboarding.dart' show ProfileRows;

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.session,
    required this.onPlan,
    required this.onPanel,
  });
  final SessionController session;
  final VoidCallback onPlan;
  final ValueChanged<Panel> onPanel;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  int _lastCount = 0;
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastCount != widget.session.chat.length) {
      _lastCount = widget.session.chat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients)
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
      });
    }
  }

  void _send() {
    final text = input.text.trim();
    if (text.isEmpty || widget.session.aiBusy) return;
    input.clear();
    widget.session.submitChat(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Column(
      children: [
        if (s.aiService != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text(
                      'Include food preferences',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: s.shareFoodContext,
                    onSelected: s.aiBusy ? null : s.setShareFoodContext,
                  ),
                ),
                IconButton(
                  tooltip: 'AI settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () async {
                    await s.refreshAiSettings();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AiSettingsPage(session: s),
                      ),
                    );
                  },
                ),
                if (s.chat.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear conversation',
                    onPressed: s.aiBusy ? null : s.clearChat,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          ),
        Expanded(
          child: PageContent(
            controller: scroll,
            pageKey: s.conversation ? 'conversation' : 'workspace',
            children: [
              if (s.aiService != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    s.shareFoodContext
                        ? 'AI receives recent messages and your active food preferences, including reported allergies. Health-context fields are excluded.'
                        : 'AI receives recent messages. Saved food preferences are excluded unless you choose to include them.',
                    style: const TextStyle(
                      fontSize: 10,
                      color: ValoraColors.muted,
                    ),
                  ),
                ),
              if (s.conversation) ...[
                const SizedBox(height: 8),
                ...s.chat.map((entry) => _Message(entry)),
                if (s.chatActionMessage.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.chatActionMessage),
                          if (s.pendingChatAction != null) ...[
                            const SizedBox(height: 8),
                            const Text('Review this change before saving.'),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: s.chatActionBusy
                                      ? null
                                      : s.confirmChatAction,
                                  child: Text(
                                    s.chatActionBusy
                                        ? 'Saving…'
                                        : s.chatActionApplied
                                        ? 'Retry saving'
                                        : 'Confirm change',
                                  ),
                                ),
                                if (!s.chatActionApplied)
                                  TextButton(
                                    onPressed: s.chatActionBusy
                                        ? null
                                        : s.cancelChatAction,
                                    child: const Text('Cancel'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (s.canRetryChat)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: s.retryChat,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry reply'),
                    ),
                  ),
                if (s.aiBusy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ] else ...[
                const Eyebrow('Your space'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Try “Set my weekly budget to INR 3000”, “Set my cooking time to 20 minutes”, or “Set my eating pattern to vegetarian”. You will review each change before saving.',
                  ),
                ),
                const Heading(
                  'What do you need\nright now?',
                  subtitle:
                      'Open something you already have, or ask for a new thought.',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Glance(
                        Icons.calendar_view_month_outlined,
                        'Next plan',
                        s.planStatus,
                        () => s.openFocus(ChatFocus.plan),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Glance(
                        Icons.kitchen_outlined,
                        'Pantry',
                        '${s.pantry.length} items listed',
                        () => s.openFocus(ChatFocus.pantry),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Glance(
                        Icons.shield_outlined,
                        'Food rules',
                        '${s.profile.allergies.length} allergies saved',
                        () => s.openFocus(ChatFocus.rules),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Eyebrow(s.request.isEmpty ? 'Open now' : 'Your request'),
                    const Icon(
                      Icons.south_east,
                      size: 15,
                      color: ValoraColors.muted,
                    ),
                  ],
                ),
                if (s.request.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ValoraColors.mint,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOU ASKED',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                              color: ValoraColors.forest,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(s.request, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                _FocusCard(
                  session: s,
                  onPlan: widget.onPlan,
                  onPanel: widget.onPanel,
                ),
                const SizedBox(height: 13),
                const Eyebrow('Try asking'),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    for (final prompt in [
                      "What's in my pantry?",
                      'Show my next plan',
                      'My allergies',
                    ])
                      ActionChip(
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => s.submitChat(prompt),
                        side: const BorderSide(color: ValoraColors.line),
                        backgroundColor: Colors.white,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ValoraColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ValoraColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Voice input',
                    onPressed: () => toast(
                      context,
                      'Voice capture is not connected in this preview. You can type your request.',
                    ),
                    icon: const Icon(
                      Icons.mic_none_rounded,
                      color: ValoraColors.forest,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-input'),
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 12000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(fontSize: 12, height: 1.4),
                      decoration: const InputDecoration(
                        hintText:
                            'Ask anything to Valora for your next plan...',
                        hintMaxLines: 2,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 2,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Attach a report or photo',
                    onPressed: () => widget.onPanel(Panel.reports),
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: ValoraColors.forest,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send request',
                    onPressed: s.aiBusy ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: ValoraColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 21),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Glance extends StatelessWidget {
  const _Glance(this.icon, this.title, this.detail, this.onTap);
  final IconData icon;
  final String title, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Surface(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 91),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: ValoraColors.mint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: ValoraColors.forest, size: 17),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 9,
                  color: ValoraColors.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.session,
    required this.onPlan,
    required this.onPanel,
  });
  final SessionController session;
  final VoidCallback onPlan;
  final ValueChanged<Panel> onPanel;
  @override
  Widget build(BuildContext context) {
    final s = session, p = s.profile;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Pill(s.request.isEmpty ? 'IN FOCUS' : 'REQUEST RESULT'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.focus == ChatFocus.pantry
                      ? 'Pantry estimate'
                      : 'Saved details',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ValoraColors.muted,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (s.focus == ChatFocus.pantry) ...[
            const Heading(
              'What you have',
              subtitle: 'Adjust anything that has run out.',
            ),
            if (s.pantry.isEmpty) const Text('No pantry items listed yet.'),
            ...s.pantry.map((item) => SummaryRow(item.name, item.amount)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onPanel(Panel.pantry),
                child: const Text('Manage pantry'),
              ),
            ),
          ] else if (s.focus == ChatFocus.profile) ...[
            const Heading('Your food preferences'),
            ProfileRows(session: s),
            if (s.hasUnsavedChanges)
              const InfoNote(
                'Your latest edits are waiting to save.',
                amber: true,
              ),
            OutlinedButton(
              onPressed: () => onPanel(Panel.practical),
              child: const Text('Edit planning preferences'),
            ),
          ] else if (s.focus == ChatFocus.memory) ...[
            const Heading('Your saved facts'),
            ...s.facts.map(
              (fact) => SummaryRow(
                fact.label,
                '${fact.value}${s.pausedFacts.contains(fact.key) ? ' · Paused' : ''}',
              ),
            ),
            OutlinedButton(
              onPressed: () => onPanel(Panel.memory),
              child: const Text('Review saved facts'),
            ),
          ] else if (s.focus == ChatFocus.rules) ...[
            const Heading('Your saved food details'),
            const FieldLabel('Reported allergies'),
            if (p.allergies.isEmpty)
              const Text(
                'None recorded',
                style: TextStyle(fontSize: 12, color: ValoraColors.muted),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.allergies
                    .map(
                      (a) => Pill(a == 'Other' ? p.otherAllergy : a, red: true),
                    )
                    .toList(),
              ),
            const Divider(),
            SummaryRow(
              'Foods to avoid',
              p.exclusions.isEmpty ? 'None recorded' : p.exclusions,
            ),
            SummaryRow(
              'Health context',
              p.health.isEmpty
                  ? 'Not shared'
                  : p.resolved(p.health, p.otherHealth),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onPanel(Panel.rules),
                child: const Text('Review profile'),
              ),
            ),
          ] else if (s.focus == ChatFocus.limits) ...[
            const Heading('Your planning limits'),
            Text(
              money(p.budget),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 34,
                color: ValoraColors.forest,
              ),
            ),
            const Text(
              'per week',
              style: TextStyle(color: ValoraColors.muted, fontSize: 12),
            ),
            SummaryRow(
              'Cooking time',
              'Up to ${p.cookingMinutes} min per meal',
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onPanel(Panel.practical),
                child: const Text('Change limits'),
              ),
            ),
          ] else if (s.holdReason != null) ...[
            const Heading('A check before we plan.'),
            Text(
              s.holdReason!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: ValoraColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () =>
                  onPanel(s.safetyPaused ? Panel.memory : Panel.rules),
              child: const Text('Review your details'),
            ),
          ] else if (s.focus == ChatFocus.rationale) ...[
            const Heading('Why this draft?'),
            const Text(
              '01  It uses ingredients listed in your pantry.\n\n02  It is aimed at your cooking-time limit.\n\n03  Every meal stays editable before shopping.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const InfoNote(
              'This is stored context for the example plan. Nutrition guidance needs approved sources.',
            ),
            FilledButton(
              onPressed: onPlan,
              child: const Text('Review the plan'),
            ),
          ] else ...[
            const Heading(
              "Tomorrow's plan",
              subtitle: 'A draft for one person. You can change every meal.',
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const Pill('~25 min active'),
                Pill(
                  s.canUseQuote ? '₹640 example estimate' : 'New quote needed',
                  amber: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...s.plannedTypes.map(
              (type) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: ValoraColors.mint,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        mealIcon(type),
                        size: 22,
                        color: ValoraColors.forest,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.slot(type).removed
                                ? '${mealLabel(type)} removed'
                                : s.recipe(type).name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${mealLabel(type)} · ${s.slot(type).servings} serving(s)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ValoraColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => s.openFocus(ChatFocus.rationale),
                    child: const Text('Why these?'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onPlan,
                    child: const Text('Review plan'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.entry);
  final ChatEntry entry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: entry.isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!entry.isUser) ...[
          const CircleAvatar(
            radius: 14,
            backgroundColor: ValoraColors.forest,
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: entry.isUser ? ValoraColors.mint : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(entry.isUser ? 18 : 5),
                bottomRight: Radius.circular(entry.isUser ? 5 : 18),
              ),
              border: entry.isUser
                  ? null
                  : Border.all(color: ValoraColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isUser ? 'YOU' : 'Valora',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ValoraColors.forest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                SelectionArea(
                  child: Text(
                    entry.text,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
                if (entry.source != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      switch (entry.source) {
                        'on_device_gemma' => 'Gemma · on device',
                        'gemini' => 'Gemini · cloud',
                        _ => 'OpenAI · cloud',
                      },
                      style: const TextStyle(
                        fontSize: 10,
                        color: ValoraColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (entry.isUser) const SizedBox(width: 0),
      ],
    ),
  );
}
