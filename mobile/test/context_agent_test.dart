import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/ai_service.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/features/voice_chat.dart';
import 'pantry_voice_test.dart' show FakeSpeech;

class ContextServer {
  List<Map<String, dynamic>> actions = [];
  Map<String, dynamic>? savedProfile;
  final memory = <String, Map<String, dynamic>>{};
  late final api = BackendApi(
    baseUrl: 'https://context.test',
    accessToken: () async => 'test',
    client: MockClient((request) async {
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/consent'))
        return response({'enabled': true});
      if (request.url.path.endsWith('/respond'))
        return response({
          'text': 'Review these context changes.',
          'provider': 'nebius',
          'model': 'nemotron',
          'contextActions': actions,
        });
      if (request.url.path == '/v1/profile') savedProfile = body;
      if (request.url.path == '/v1/memory') {
        final fact = {'id': 'fact:${body['key']}', ...body};
        memory[body['key'] as String] = fact;
        return response(fact);
      }
      return response(body);
    }),
  );
  http.Response response(Map<String, dynamic> value) =>
      http.Response(jsonEncode({'data': value}), 200);
  SessionController session() => SessionController()
    ..backendApi = api
    ..aiService = ValoraAiService(api)
    ..signedIn = true
    ..accountLoaded = true
    ..onboarded = true;
}

void main() {
  test(
    'reported symptoms and comfort preference save only after confirmation and survive as memory',
    () async {
      final server = ContextServer()
        ..actions = [
          {'kind': 'temporary_health', 'value': 'fever'},
          {'kind': 'temporary_health', 'value': 'cold'},
          {'kind': 'meal_style', 'value': 'warm'},
        ];
      final session = server.session();
      addTearDown(session.dispose);
      addTearDown(server.api.close);
      await session.submitChat('I have fever and a cold today');
      expect(server.memory, isEmpty);
      expect(session.profile.health, isEmpty);
      expect(session.pendingContextActions, hasLength(3));
      await session.confirmContextActions();
      expect(session.pendingContextActions, isNull);
      expect(session.profile.health, isEmpty);
      expect(
        server.memory['temporary_health']!['value'],
        contains('fever, cold'),
      );
      expect(server.memory['meal_style']!['value'], contains('expiresAt'));
    },
  );
  test(
    'allergy and food exclusion proposals update persisted profile after confirmation',
    () async {
      final server = ContextServer()
        ..actions = [
          {'kind': 'add_allergy', 'value': 'peanut'},
          {'kind': 'avoid_food', 'value': 'eggplant'},
        ];
      final session = server.session();
      addTearDown(session.dispose);
      addTearDown(server.api.close);
      await session.submitChat('I am allergic to peanuts and avoid eggplant');
      expect(session.profile.allergies, isEmpty);
      await session.confirmContextActions();
      expect(session.profile.allergies, contains('Peanuts'));
      expect(server.savedProfile!['exclusions'], 'eggplant');
    },
  );
  test(
    'stale context proposals and sign-out cannot overwrite changed account data',
    () async {
      final server = ContextServer()
        ..actions = [
          {'kind': 'add_allergy', 'value': 'peanut'},
        ];
      final session = server.session();
      addTearDown(session.dispose);
      addTearDown(server.api.close);
      await session.submitChat('I am allergic to peanuts');
      session.profile.cookingMinutes = 15;
      await session.confirmContextActions();
      expect(session.profile.allergies, isEmpty);
      expect(session.pendingContextActions, isNull);
      await session.submitChat('I am allergic to peanuts');
      await session.signOut();
      expect(session.pendingContextActions, isNull);
    },
  );
  testWidgets(
    'voice chat keeps speech as an editable draft until Use in chat',
    (tester) async {
      final session = SessionController();
      final speech = FakeSpeech();
      addTearDown(session.dispose);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        VoiceChatSheet(session: session, speech: speech),
                  );
                },
                child: const Text('Speak'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Speak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start speaking'));
      await tester.pumpAndSettle();
      speech.words!('I have fever today');
      await tester.pump();
      expect(session.chat, isEmpty);
      expect(result, isNull);
      await tester.tap(find.text('Stop listening'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use in chat'));
      await tester.tap(find.text('Use in chat'));
      await tester.pumpAndSettle();
      expect(result, 'I have fever today');
      expect(session.chat, isEmpty);
      expect(speech.cancelled, true);
    },
  );
}
