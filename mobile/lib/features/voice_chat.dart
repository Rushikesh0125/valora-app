import 'dart:async';
import 'package:flutter/material.dart';
import '../core/pantry_speech.dart';
import '../core/session_controller.dart';
import '../core/widgets.dart';

class VoiceChatSheet extends StatefulWidget {
  const VoiceChatSheet({
    super.key,
    required this.session,
    this.initialText = '',
    this.speech,
  });
  final SessionController session;
  final String initialText;
  final PantrySpeech? speech;
  @override
  State<VoiceChatSheet> createState() => _VoiceChatSheetState();
}

class _VoiceChatSheetState extends State<VoiceChatSheet>
    with WidgetsBindingObserver {
  late final input = TextEditingController(text: widget.initialText);
  late final speech = widget.speech ?? DevicePantrySpeech.shared;
  late final int account;
  bool listening = false, starting = false, invalid = false;
  String error = '', base = '';
  @override
  void initState() {
    super.initState();
    account = widget.session.accountGeneration;
    widget.session.addListener(checkAccount);
    WidgetsBinding.instance.addObserver(this);
  }

  void checkAccount() {
    if (!mounted || invalid) return;
    if (account != widget.session.accountGeneration) {
      unawaited(speech.cancel());
      setState(() {
        invalid = true;
        listening = starting = false;
        error = 'Your account changed. Close this voice message.';
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

  Future<void> toggle() async {
    if (invalid || starting) return;
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    base = input.text.trim();
    setState(() {
      starting = true;
      error = '';
    });
    final available = await speech.start(
      onWords: (words) {
        if (!mounted || invalid) return;
        final text = [base, words].where((s) => s.isNotEmpty).join(' ');
        setState(
          () => input.text = text.length > 12000
              ? text.substring(0, 12000)
              : text,
        );
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
        error = 'Speech input is unavailable. You can type your message below.';
      }
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(checkAccount);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(speech.cancel());
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading(
            'Speak to Valora',
            subtitle:
                'Review the transcript, then use it in chat. Nothing is sent or saved until you send the message.',
          ),
          const Text(
            'Your device’s speech service transcribes audio and may use its network service. Valora sends only the message text to cloud AI after consent.',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: invalid || starting ? null : toggle,
            icon: Icon(listening ? Icons.stop_rounded : Icons.mic_none_rounded),
            label: Text(
              starting
                  ? 'Starting microphone…'
                  : listening
                  ? 'Stop listening'
                  : 'Start speaking',
            ),
          ),
          TextField(
            key: const ValueKey('voice-chat-transcript'),
            controller: input,
            readOnly: listening || starting || invalid,
            minLines: 2,
            maxLines: 6,
            maxLength: 12000,
            decoration: const InputDecoration(labelText: 'Your message'),
          ),
          if (error.isNotEmpty) InfoNote(error, amber: true),
          FilledButton(
            onPressed: invalid || listening || starting
                ? null
                : () {
                    if (input.text.trim().isNotEmpty)
                      Navigator.pop(context, input.text.trim());
                  },
            child: const Text('Use in chat'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
