import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/core/pantry_speech.dart';
import 'package:valora_mobile/core/pantry_voice_command.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/core/models.dart';
import 'package:valora_mobile/features/pantry_voice.dart';

class FakeSpeech implements PantrySpeech {
  bool available = true, cancelled = false;
  void Function(String)? words;
  @override
  Future<bool> start({
    required void Function(String) onWords,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) async {
    words = onWords;
    onListening(available);
    return available;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

Future<void> open(
  WidgetTester tester,
  SessionController session,
  FakeSpeech speech,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SingleChildScrollView(
                child: PantryVoicePanel(session: session, speech: speech),
              ),
            ),
            child: const Text('Open voice'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open voice'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'count quantities without units are valid and pantry intent excludes health/preferences',
    () {
      final commands = pantryCommandsFromDraft({
        'status': 'draft',
        'operations': [
          {'action': 'save', 'name': 'apple', 'amount': '5'},
          {'action': 'save', 'name': 'milk', 'amount': '1 litre'},
        ],
      });
      expect(commands, hasLength(2));
      expect(commands!.first.amount, '5');
      expect(isPantryUpdate('I have five apples and 1 litre of milk'), true);
      expect(isPantryUpdate('I have a cold'), false);
      expect(isPantryUpdate('I have rice'), true);
      expect(isPantryUpdate('I bought 2 bottles of cold coffee'), true);
      expect(isPantryUpdate('I have a peanut allergy'), false);
      expect(isPantryUpdate('I prefer Italian food'), false);
      expect(
        pantryCommandsFromDraft({
          'status': 'draft',
          'operations': [
            {'action': 'save', 'name': 'apple', 'amount': '0'},
          ],
        }),
        isNull,
      );
    },
  );
  test(
    'chat routes inventory to a review draft without changing pantry',
    () async {
      final session = SessionController();
      addTearDown(session.dispose);
      final before = session.pantry.length;
      await session.submitChat('I have five apples and a litre of milk');
      expect(session.pantryChatDraft, isNotNull);
      expect(session.pantry.length, before);
      expect(
        session.takePantryChatDraft(),
        'I have five apples and a litre of milk',
      );
      expect(session.pantryChatDraft, isNull);
      await session.submitChat('Set my weekly budget to INR 3000');
      expect(session.pendingChatAction, isNotNull);
      expect(session.pantryChatDraft, isNull);
    },
  );

  test(
    'parses single-item save, update and removal commands with spoken quantities',
    () {
      expect(parsePantryVoice('add rice one kilogram')?.amount, '1 kilogram');
      expect(parsePantryVoice('add two cans of chickpeas')?.name, 'chickpeas');
      expect(parsePantryVoice('set rice to 500 grams')?.amount, '500 grams');
      expect(
        parsePantryVoice('Please remove rice from my pantry')?.remove,
        true,
      );
      expect(parsePantryVoice('add rice half kg')?.amount, '0.5 kg');
      for (final text in [
        'remove everything',
        'remove rice and milk',
        'add rice',
        'add rice 0 kg',
        'add rice 1 kg and milk 2 l',
      ]) {
        expect(parsePantryVoice(text), isNull, reason: text);
      }
    },
  );
  testWidgets(
    'voice transcript cannot mutate pantry until preview and confirmation',
    (tester) async {
      final session = SessionController();
      final speech = FakeSpeech();
      addTearDown(session.dispose);
      await open(tester, session, speech);
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      speech.words!('set rice to two kilograms');
      await tester.pump();
      expect(session.pantry.first.amount, '~1 kg');
      await tester.tap(find.text('Stop listening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview pantry change'));
      await tester.pumpAndSettle();
      expect(session.pantry.first.amount, '~1 kg');
      await tester.tap(find.text('Confirm pantry change'));
      await tester.pumpAndSettle();
      expect(session.pantry.first.amount, '2 kilograms');
      expect(speech.cancelled, true);
    },
  );
  testWidgets(
    'unavailable microphone allows typed removal and stale pantry changes are rejected',
    (tester) async {
      final session = SessionController();
      final speech = FakeSpeech()..available = false;
      addTearDown(session.dispose);
      await open(tester, session, speech);
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      expect(find.textContaining('permission or speech'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pantry-voice-transcript')),
        'remove rice',
      );
      await tester.tap(find.text('Preview pantry change'));
      await tester.pumpAndSettle();
      session.removePantry(session.pantry.last.id);
      await tester.tap(find.text('Confirm removal'));
      await tester.pumpAndSettle();
      expect(session.pantry.any((p) => p.name == 'Rice'), true);
      expect(find.textContaining('Your pantry changed'), findsOneWidget);
      await tester.tap(find.text('Preview pantry change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm removal'));
      await tester.pumpAndSettle();
      expect(session.pantry.any((p) => p.name == 'Rice'), false);
    },
  );
  testWidgets(
    'sign-out cancels capture and prevents a command crossing accounts',
    (tester) async {
      final session = SessionController();
      final speech = FakeSpeech();
      addTearDown(session.dispose);
      await open(tester, session, speech);
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      await session.signOut();
      await tester.pumpAndSettle();
      speech.words!('remove rice');
      await tester.pump();
      expect(
        find.textContaining('account or food records changed'),
        findsOneWidget,
      );
      expect(speech.cancelled, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('duplicate pantry names are never removed together by voice', (
    tester,
  ) async {
    final session = SessionController();
    final speech = FakeSpeech();
    addTearDown(session.dispose);
    session.savePantry(name: 'Rice', amount: '2 kg', kind: PantryKind.leftover);
    await open(tester, session, speech);
    await tester.enterText(
      find.byKey(const ValueKey('pantry-voice-transcript')),
      'remove rice',
    );
    await tester.tap(find.text('Preview pantry change'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('More than one pantry item matches'),
      findsOneWidget,
    );
    expect(find.text('Confirm removal'), findsNothing);
    expect(session.pantry.where((p) => p.name == 'Rice').length, 2);
  });
  test('batch parsing and application are all-or-nothing', () {
    final commands = parsePantryVoiceBatch(
      'add rice one kg and milk two litres, remove onion',
    );
    expect(commands, hasLength(3));
    expect(commands!.last.remove, true);
    final session = SessionController();
    addTearDown(session.dispose);
    final before = session.pantry.length;
    final result = session.applyPantryBatch([
      PantryBatchEdit(command: commands[0], id: session.pantry.first.id),
      const PantryBatchEdit(
        command: PantryVoiceCommand(remove: true, name: 'missing'),
        id: 999,
      ),
    ]);
    expect(result, isNotNull);
    expect(session.pantry.first.amount, '~1 kg');
    expect(session.pantry.length, before);
  });
  testWidgets(
    'natural inventory language previews all items and packaging before one save',
    (tester) async {
      final api = BackendApi(
        baseUrl: 'https://voice.test',
        accessToken: () async => 'test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/interpret')
                  ? {
                      'status': 'draft',
                      'operations': [
                        {'action': 'save', 'name': 'potato', 'amount': '1 kg'},
                        {
                          'action': 'save',
                          'name': 'milk',
                          'amount': '2 cartons (1 litre each)',
                        },
                      ],
                    }
                  : {'version': 1},
            }),
            200,
          ),
        ),
      );
      final session = SessionController()
        ..backendApi = api
        ..signedIn = true
        ..accountLoaded = true
        ..onboarded = true;
      addTearDown(session.dispose);
      addTearDown(api.close);
      await open(tester, session, FakeSpeech());
      await tester.enterText(
        find.byKey(const ValueKey('pantry-voice-transcript')),
        'I have a kg of potato and 2 cartons of milk 1 litre each',
      );
      await tester.tap(find.text('Preview pantry change'));
      await tester.pumpAndSettle();
      expect(find.text('Add milk: 2 cartons (1 litre each)'), findsOneWidget);
      expect(session.pantry.any((p) => p.name == 'milk'), false);
      await tester.ensureVisible(find.text('Confirm all 2 changes'));
      await tester.tap(find.text('Confirm all 2 changes'));
      await tester.pumpAndSettle();
      expect(
        session.pantry.firstWhere((p) => p.name == 'milk').amount,
        '2 cartons (1 litre each)',
      );
      expect(
        session.pantry.firstWhere((p) => p.name == 'potato').amount,
        '1 kg',
      );
    },
  );
  testWidgets(
    'continuing dictation appends items instead of replacing earlier words',
    (tester) async {
      final session = SessionController();
      final speech = FakeSpeech();
      addTearDown(session.dispose);
      await open(tester, session, speech);
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      speech.words!('add rice one kg');
      await tester.pump();
      await tester.tap(find.text('Stop listening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      speech.words!('add milk two litres');
      await tester.pump();
      await tester.tap(find.text('Stop listening'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview pantry change'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm all 2 changes'), findsOneWidget);
      expect(session.pantry.first.amount, '~1 kg');
    },
  );
}
