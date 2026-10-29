import 'voice_chat.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'ai_settings.dart';
import 'first_day_plan.dart';
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
  String _lastRequest = '';
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastCount != widget.session.chat.length ||
        _lastRequest != widget.session.request) {
      _lastCount = widget.session.chat.length;
      _lastRequest = widget.session.request;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients)
          scroll.animateTo(
            widget.session.conversation ? scroll.position.maxScrollExtent : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
      });
    }
  }

  Future<void> _voice() async {
    final account = widget.session.accountGeneration;
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          VoiceChatSheet(session: widget.session, initialText: input.text),
    );
    if (mounted &&
        account == widget.session.accountGeneration &&
        text != null) {
      input.text = text;
      input.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  void _send() {
    final text = input.text.trim();
    if (text.isEmpty ||
        widget.session.aiBusy ||
        widget.session.chatActionBusy ||
        widget.session.contextActionBusy ||
        widget.session.firstDayPlanner?.changeBusy == true)
      return;
    input.clear();
    widget.session.submitChat(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session, planner = widget.session.firstDayPlanner;
    final pending = planner?.proposal;
    return Column(
      children: [
        if (s.aiService != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 17,
                  color: ValoraColors.forest,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Saved food rules applied',
                    style: TextStyle(fontSize: 12),
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
                    onPressed: s.aiBusy || planner?.changeBusy == true
                        ? null
                        : () {
                            planner?.cancelChange();
                            s.clearChat();
                          },
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
                TextButton.icon(
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                  label: const Text(
                    'What is shared with AI',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('You control the context'),
                      content: const Text(
                        'Your saved diet, allergens, foods to avoid and cooking time filter meal suggestions on the server. Nebius receives recent messages and eligible recipes. Saved health fields are excluded. Anything you type in chat is sent as part of your message.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (s.conversation) ...[
                const SizedBox(height: 8),
                ...s.chat.map((entry) => _Message(entry)),
                if (pending != null)
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proposed meal change',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${pending['meal']}: ${(pending['before'] as Map)['name']} → ${(pending['recipe'] as Map)['name']}',
                        ),
                        Text(
                          'Ingredients: ${((pending['recipe'] as Map)['ingredients'] as List).join(', ')}',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: (planner!.changeBusy || planner.busy)
                                  ? null
                                  : planner.confirmChange,
                              child: Text(
                                (planner.changeBusy || planner.busy)
                                    ? 'Saving…'
                                    : 'Confirm meal change',
                              ),
                            ),
                            TextButton(
                              onPressed: (planner.changeBusy || planner.busy)
                                  ? null
                                  : planner.cancelChange,
                              child: const Text('Keep current meal'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (planner?.changeMessage.isNotEmpty == true)
                  InfoNote(planner!.changeMessage),
                if (s.pendingContextActions != null ||
                    s.contextActionMessage.isNotEmpty)
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.contextActionMessage),
                        if (s.pendingContextActions != null) ...[
                          for (final action in s.pendingContextActions!)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '${(action['kind'] as String).replaceAll('_', ' ')}: ${action['value']}',
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: s.contextActionBusy
                                    ? null
                                    : s.confirmContextActions,
                                child: Text(
                                  s.contextActionBusy
                                      ? 'Saving…'
                                      : 'Save context & refresh plan',
                                ),
                              ),
                              TextButton(
                                onPressed: s.contextActionBusy
                                    ? null
                                    : s.cancelContextActions,
                                child: const Text('Keep saved context'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (s.chatActionMessage.isNotEmpty)
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.chatActionMessage),
                        if (s.pendingChatAction != null) ...[
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
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('Preparing a reply…')),
                      ],
                    ),
                  ),
              ] else if (s.request.isNotEmpty ||
                  s.focus == ChatFocus.rationale) ...[
                if (planner != null && s.focus == ChatFocus.plan)
                  FirstDayPlanView(
                    planner: planner,
                    onReview: () => widget.onPanel(Panel.rules),
                    compact: true,
                    onOpen: widget.onPlan,
                  )
                else
                  _FocusCard(
                    session: s,
                    onPlan: widget.onPlan,
                    onPanel: widget.onPanel,
                  ),
              ] else ...[
                const SizedBox(height: 20),
                const Heading(
                  'A little help with\nwhat to eat.',
                  subtitle:
                      'Meals that fit your saved food preferences. Changes stay yours to confirm.',
                ),
                const SizedBox(height: 20),
                for (final suggestion in [
                  'Suggest a quick lunch',
                  'I want Italian for dinner tonight',
                  'Set my cooking time to 20 minutes',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () => s.submitChat(suggestion),
                      child: Row(
                        children: [
                          Expanded(child: Text(suggestion)),
                          const Icon(Icons.north_east_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                      ),
                      label: const Text('My meal plan'),
                      onPressed: widget.onPlan,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.kitchen_outlined, size: 16),
                      label: const Text('My pantry'),
                      onPressed: () => s.submitChat("What's in my pantry?"),
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
                    tooltip: 'Voice message',
                    onPressed: s.aiBusy || s.contextActionBusy ? null : _voice,
                    icon: const Icon(
                      Icons.mic_none_rounded,
                      color: ValoraColors.forest,
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
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your meals…',
                        hintMaxLines: 1,
                        counterText: '',
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 8,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send request',
                    onPressed:
                        s.aiBusy ||
                            s.chatActionBusy ||
                            s.contextActionBusy ||
                            planner?.changeBusy == true
                        ? null
                        : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: ValoraColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 21),
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
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: entry.isUser
                  ? ValoraColors.mint
                  : entry.isError
                  ? ValoraColors.red
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: entry.isUser
                  ? null
                  : Border.all(color: ValoraColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isUser
                      ? 'You'
                      : entry.isError
                      ? 'Reply interrupted'
                      : 'Valora',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ValoraColors.forest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                SelectionArea(
                  child: entry.isUser || entry.isError
                      ? Text(
                          entry.text,
                          style: const TextStyle(fontSize: 15, height: 1.55),
                        )
                      : MarkdownBody(
                          data: entry.text,
                          onTapLink: (_, href, _) async {
                            final url = Uri.tryParse(href ?? '');
                            if (url != null &&
                                url.scheme == 'https' &&
                                [
                                  'pubmed.ncbi.nlm.nih.gov',
                                  'pmc.ncbi.nlm.nih.gov',
                                  'www.nejm.org',
                                  'doi.org',
                                ].contains(url.host)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          imageBuilder: (_, _, _) => const SizedBox.shrink(),
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: const TextStyle(
                                  fontSize: 15,
                                  height: 1.55,
                                  color: ValoraColors.ink,
                                ),
                                h1: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                h2: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                                h3: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                listBullet: const TextStyle(fontSize: 15),
                                blockSpacing: 10,
                              ),
                        ),
                ),
                if (entry.source != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      (switch (entry.source) {
                            'nebius' => 'NVIDIA Nemotron via Nebius',
                            'knowledge' => 'Published study sources',
                            'valora' => 'Valora · saved food rules',
                            'on_device_gemma' => 'Gemma · on device',
                            'gemini' => 'Gemini · cloud',
                            'openai' => 'OpenAI · cloud',
                            _ => 'Cloud AI',
                          }) +
                          (entry.model == null ? '' : ' · ${entry.model}'),
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
      ],
    ),
  );
}
