import '../core/backend_api.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/session_controller.dart';
import '../core/pantry_speech.dart';
import '../core/pantry_voice_command.dart';
import '../core/tag_suggestions.dart';
import '../core/widgets.dart';

class PantryVoicePanel extends StatefulWidget {
  const PantryVoicePanel({super.key, required this.session, this.speech});
  final SessionController session;
  final PantrySpeech? speech;
  @override
  State<PantryVoicePanel> createState() => _PantryVoicePanelState();
}

class _PantryVoicePanelState extends State<PantryVoicePanel>
    with WidgetsBindingObserver {
  final transcript = TextEditingController();
  late final speech = widget.speech ?? DevicePantrySpeech.shared;
  late final int account;
  late final int foodGeneration;
  bool listening = false,
      starting = false,
      saving = false,
      applied = false,
      invalid = false;
  String error = '', snapshot = '';
  List<PantryBatchEdit>? batch;
  bool interpreting = false;
  String draftSource = '';
  String pantrySnapshot() => jsonEncode(
    widget.session.pantry
        .map((p) => [p.id, p.name, p.amount, p.kind.name])
        .toList(),
  );
  @override
  void initState() {
    super.initState();
    account = widget.session.accountGeneration;
    foodGeneration = widget.session.foodRecordsGeneration;
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(accountChanged);
  }

  void accountChanged() {
    if (!mounted || invalid) return;
    if (account != widget.session.accountGeneration ||
        foodGeneration != widget.session.foodRecordsGeneration) {
      unawaited(speech.cancel());
      setState(() {
        invalid = true;
        listening = starting = false;
        batch = null;
        error =
            'Your account or food records changed. Close and reopen voice input.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(speech.cancel());
      if (mounted)
        setState(() {
          listening = starting = false;
        });
    }
  }

  Future<void> listen() async {
    if (invalid || saving || applied || starting || interpreting) return;
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() {
      starting = true;
      error = '';
      batch = null;
    });
    final previousTranscript = transcript.text.trim();
    final available = await speech.start(
      onWords: (words) {
        if (!mounted || invalid || saving || applied || interpreting) return;
        final text = [
          previousTranscript,
          words,
        ].where((v) => v.isNotEmpty).join(', ');
        setState(() {
          transcript.text = text;
          batch = null;
        });
      },
      onListening: (value) {
        if (mounted && !invalid) setState(() => listening = value);
      },
      onError: (message) {
        if (mounted && !invalid)
          setState(() {
            error = message;
            listening = false;
          });
      },
    );
    if (!mounted || invalid) return;
    setState(() {
      starting = false;
      if (!available) {
        listening = false;
        error =
            'Microphone permission or speech recognition is unavailable. You can type below.';
      }
    });
  }

  String normalized(String name) {
    for (final item in foodSuggestions) {
      if (item.isExact(name)) return item.id;
    }
    return name.toLowerCase().trim();
  }

  Future<void> preview() async {
    if (invalid || saving || listening || starting || applied || interpreting)
      return;
    final spoken = transcript.text.trim();
    if (spoken.length > 4000) {
      setState(
        () => error =
            'Please shorten the transcript to 4,000 characters or fewer before previewing.',
      );
      return;
    }
    var commands = parsePantryVoiceBatch(spoken);
    var source = 'Parsed on device';
    if (commands == null) {
      final api = widget.session.backendApi;
      if (api == null) {
        setState(
          () => error =
              'For natural language, connect your account and enable cloud AI. You can also use “add rice one kg and milk two litres”.',
        );
        return;
      }
      setState(() {
        interpreting = true;
        error = '';
        batch = null;
      });
      try {
        final draft = await api.interpretPantry(spoken);
        if (!mounted || invalid) return;
        commands = pantryCommandsFromDraft(draft);
        source = 'NVIDIA Nemotron via Nebius';
      } catch (e) {
        if (mounted && !invalid)
          setState(
            () => error =
                e is BackendException &&
                    e.message == 'cloud_ai_consent_required'
                ? 'Enable cloud AI in AI settings to interpret natural language.'
                : 'Could not interpret the list. Your pantry is unchanged. Check the transcript and retry.',
          );
        return;
      } finally {
        if (mounted && !invalid) setState(() => interpreting = false);
      }
    }
    if (commands == null || commands.isEmpty || commands.length > 20) {
      setState(
        () => error =
            'Please include an amount for every added item and clarify any ambiguous part. Nothing has been changed.',
      );
      return;
    }
    final edits = <PantryBatchEdit>[];
    final names = <String>{};
    for (final c in commands) {
      final key = normalized(c.name);
      if (!names.add(key)) {
        setState(
          () => error =
              'The same item appears more than once. Combine its amount or clarify the transcript first.',
        );
        return;
      }
      final matches = widget.session.pantry
          .where((p) => normalized(p.name) == key)
          .toList();
      if (matches.length > 1 || (c.remove && matches.isEmpty)) {
        setState(
          () => error = matches.isEmpty
              ? '${c.name} is not in your pantry. Check the name below.'
              : 'More than one pantry item matches ${c.name}. Open the exact item in your pantry to edit it.',
        );
        return;
      }
      final existing = matches.firstOrNull;
      edits.add(
        PantryBatchEdit(
          command: PantryVoiceCommand(
            remove: c.remove,
            name: existing?.name ?? c.name,
            amount: c.amount,
          ),
          id: existing?.id,
          kind: existing?.kind ?? PantryKind.ingredient,
          previousAmount: existing?.amount,
        ),
      );
    }
    setState(() {
      error = '';
      batch = edits;
      draftSource = source;
      snapshot = pantrySnapshot();
    });
  }

  Future<void> confirm() async {
    if (invalid || saving || batch == null) return;
    if (account != widget.session.accountGeneration ||
        foodGeneration != widget.session.foodRecordsGeneration ||
        snapshot != pantrySnapshot()) {
      setState(() {
        batch = null;
        error =
            'Your pantry changed. Preview the command again before confirming.';
      });
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    if (!applied) {
      final result = widget.session.applyPantryBatch(batch!);
      if (result != null) {
        if (mounted)
          setState(() {
            saving = false;
            error = result;
          });
        return;
      }
      applied = true;
      snapshot = pantrySnapshot();
    }
    await widget.session.saveAccountData();
    if (!mounted || invalid) return;
    if (widget.session.saveError.isNotEmpty ||
        widget.session.hasUnsavedChanges) {
      setState(() {
        saving = false;
        error =
            'Changed on this device, but could not save to your account. Retry saving.';
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    widget.session.removeListener(accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(speech.cancel());
    transcript.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Say “I have a kg of potato and two cartons of milk, one litre each”, or list items to add and remove. Review every change before saving.',
      ),
      const SizedBox(height: 8),
      const Text(
        'Your device’s speech service transcribes audio and may use its network service. For natural language, the transcript is sent to cloud AI after consent. Valora does not send the audio to its AI service.',
        style: TextStyle(fontSize: 11),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: invalid || saving || applied || starting || interpreting
            ? null
            : listen,
        icon: Icon(listening ? Icons.stop_rounded : Icons.mic_none_rounded),
        label: Text(
          starting
              ? 'Starting microphone…'
              : listening
              ? 'Stop listening'
              : 'Start speaking',
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('pantry-voice-transcript'),
        controller: transcript,
        readOnly: listening || starting || applied || invalid || interpreting,
        maxLength: 4000,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Your command',
          hintText: 'You can also type or correct the transcript',
        ),
        onChanged: (_) => setState(() {
          batch = null;
          error = '';
        }),
      ),
      if (error.isNotEmpty) InfoNote(error, amber: true),
      if (interpreting) const LinearProgressIndicator(),
      if (batch != null)
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(draftSource, style: const TextStyle(fontSize: 11)),
              for (final edit in batch!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    edit.command.remove
                        ? 'Remove ${edit.command.name} (${edit.previousAmount}) from pantry?'
                        : edit.id != null
                        ? 'Update ${edit.command.name}: ${edit.previousAmount} → ${edit.command.amount}'
                        : 'Add ${edit.command.name}: ${edit.command.amount}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: saving || invalid ? null : confirm,
                child: Text(
                  saving
                      ? 'Saving…'
                      : applied
                      ? 'Retry saving'
                      : batch!.length > 1
                      ? 'Confirm all ${batch!.length} changes'
                      : batch!.first.command.remove
                      ? 'Confirm removal'
                      : 'Confirm pantry change',
                ),
              ),
            ],
          ),
        )
      else
        FilledButton(
          onPressed: invalid || listening || starting || interpreting
              ? null
              : preview,
          child: Text(
            interpreting ? 'Interpreting your list…' : 'Preview pantry change',
          ),
        ),
    ],
  );
}
