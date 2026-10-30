import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/ai_service.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:valora_mobile/core/models.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/app.dart';

class ChatServer {
  bool consent = true;
  final requests = <Map<String, dynamic>>[];
  Completer<http.Response>? pending;
  late final api = BackendApi(
    baseUrl: 'https://chat.test',
    accessToken: () async => 'token',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/consent'))
        return http.Response(
          jsonEncode({
            'data': {'enabled': consent},
          }),
          200,
        );
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (pending != null) return pending!.future;
      return reply();
    }),
  );
  http.Response reply() => http.Response(
    '{"data":{"text":"A practical suggestion.","provider":"nebius","model":"nvidia/nemotron-3-super-120b-a12b","usage":{}}}',
    200,
  );
  SessionController session() =>
      SessionController()
        ..aiService = ValoraAiService(api, onDeviceEnabled: false);
}

class LocalService extends ValoraAiService {
  LocalService(super.api, {this.fail = false, this.installed = false})
    : super(onDeviceEnabled: true, localOnly: true);
  final bool fail, installed;
  int localCalls = 0;
  @override
  Future<AiReply?> respondLocally({
    required AiTask task,
    required String prompt,
    String? context,
  }) async {
    localCalls++;
    if (fail) throw StateError('local inference failed');
    return installed
        ? const AiReply(text: 'Local answer', source: 'on_device_gemma')
        : null;
  }
}

class NebiusService extends ValoraAiService {
  NebiusService(super.api);
  int localCalls = 0;
  @override
  Future<AiReply?> respondLocally({
    required AiTask task,
    required String prompt,
    String? context,
  }) async {
    localCalls++;
    throw StateError('Nebius mode must never initialize a local model');
  }
}

void main() {
  test(
    'Nebius defaults bypass local inference and honor consent revocation',
    () async {
      final server = ChatServer();
      final service = NebiusService(server.api);
      addTearDown(server.api.close);
      for (final complexity in AiComplexity.values) {
        final reply = await service.respond(
          task: AiTask.conversation,
          complexity: complexity,
          prompt: 'A lunch idea',
        );
        expect(reply.source, 'nebius');
        expect(reply.model, 'nvidia/nemotron-3-super-120b-a12b');
      }
      server.consent = false;
      await expectLater(
        service.respond(
          task: AiTask.conversation,
          complexity: AiComplexity.routine,
          prompt: 'Another idea',
        ),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'code',
            'cloud_ai_consent_required',
          ),
        ),
      );
      expect(server.requests.length, 2);
      expect(service.localCalls, 0);
      expect(service.onDeviceEnabled, false);
      expect(service.localOnly, false);
    },
  );

  testWidgets(
    'busy send preserves the next draft and exposes retry/settings controls',
    (tester) async {
      final server = ChatServer()..pending = Completer<http.Response>();
      final session = server.session()..onboarded = true;
      addTearDown(session.dispose);
      addTearDown(server.api.close);
      await tester.pumpWidget(ValoraApp(session: session));
      final input = find.byKey(const ValueKey('chat-input'));
      await tester.enterText(input, 'Help with lunch');
      await tester.tap(find.byTooltip('Send request'));
      await tester.pump();
      await tester.enterText(input, 'A follow-up draft');
      await tester.tap(find.byTooltip('Send request'));
      await tester.pump();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'A follow-up draft',
      );
      expect(server.requests.length, 1);
      expect(find.byTooltip('AI settings'), findsOneWidget);
      server.pending!.complete(server.reply());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Powered by NVIDIA Nemotron via Nebius · nvidia/nemotron-3-super-120b-a12b',
        ),
        findsOneWidget,
      );
    },
  );

  test(
    'connected saved-state reads use current account values without AI calls',
    () async {
      final server = ChatServer();
      final session = server.session();
      session.profile.pattern = 'Vegan';
      for (final entry in {
        "What's in my pantry?": ChatFocus.pantry,
        'Show my next plan': ChatFocus.plan,
        'Show my meal plan for today': ChatFocus.plan,
        'What am I eating today?': ChatFocus.plan,
        'What allergies do you have saved?': ChatFocus.rules,
        'What is my budget?': ChatFocus.limits,
        'Show my meal preferences': ChatFocus.profile,
        'Show my saved facts': ChatFocus.memory,
      }.entries) {
        await session.submitChat(entry.key);
        expect(session.focus, entry.value);
        expect(session.conversation, false);
      }
      expect(server.requests, isEmpty);
      expect(session.profile.pattern, 'Vegan');
      expect(session.chat, isEmpty);
      session.dispose();
      server.api.close();
    },
  );

  test(
    'compound edit requests use conversation and do not mutate saved state',
    () async {
      final server = ChatServer();
      final session = server.session();
      await session.submitChat('Show my pantry and update rice to 900 g');
      expect(server.requests.length, 1);
      expect(session.conversation, true);
      expect(session.pantry.first.amount, '~1 kg');
      session.dispose();
      server.api.close();
    },
  );

  test(
    'follow-ups receive role-preserving history without duplicating the current message',
    () async {
      final server = ChatServer();
      final session = server.session();
      await session.submitChat('Help me think of a simple lunch');
      await session.submitChat('Can it be quicker?');
      final context =
          jsonDecode(server.requests.last['context'] as String)
              as Map<String, dynamic>;
      final history = context['history'] as List;
      expect(history.length, 2);
      expect(history.first['role'], 'user');
      expect(history.first['text'], 'Help me think of a simple lunch');
      expect(history.last['role'], 'assistant');
      expect(context.containsKey('foodPreferences'), false);
      session.dispose();
      server.api.close();
    },
  );

  test(
    'food context requires opt-in and excludes health, arbitrary memory, and paused fields',
    () async {
      final server = ChatServer();
      final session = server.session();
      session.profile.health.add('private-health-marker');
      session.profile.otherHealth = 'private-health-detail';
      session.profile.goals.add('sensitive-goal');
      session.profile.cuisines.add('private-paused-cuisine');
      session.pausedFacts.add('cuisines');
      session.profile.pattern = 'Vegan';
      session.profile.budget = 3200;
      await session.submitChat('Give me a dinner idea');
      expect(server.requests.last['context'], isNot(contains('Vegan')));
      session.setShareFoodContext(true);
      await session.submitChat('Give me another dinner idea');
      final encoded = server.requests.last['context'] as String;
      expect(encoded, contains('Vegan'));
      expect(encoded, contains('3200'));
      expect(encoded, isNot(contains('private-health')));
      expect(encoded, isNot(contains('sensitive-goal')));
      expect(encoded, isNot(contains('private-paused-cuisine')));
      session.dispose();
      server.api.close();
    },
  );

  test(
    'retry after enabling consent keeps one user message and excludes the failed attempt from history',
    () async {
      final server = ChatServer()..consent = false;
      final session = server.session();
      await session.submitChat('Help me with lunch');
      expect(session.chat.last.isError, true);
      expect(session.canRetryChat, true);
      expect(server.requests, isEmpty);
      server.consent = true;
      await session.retryChat();
      expect(session.chat.length, 2);
      expect(session.chat.where((e) => e.isUser).length, 1);
      expect(session.chat.last.isError, false);
      expect(session.canRetryChat, false);
      expect(
        (jsonDecode(server.requests.single['context'] as String)
            as Map)['history'],
        isEmpty,
      );
      session.dispose();
      server.api.close();
    },
  );

  test(
    'logout ignores a pending AI response and clears context-sharing state',
    () async {
      final server = ChatServer()..pending = Completer<http.Response>();
      final session = server.session();
      session.setShareFoodContext(true);
      final request = session.submitChat('Give me a lunch idea');
      await Future<void>.delayed(Duration.zero);
      expect(session.aiBusy, true);
      await session.signOut();
      server.pending!.complete(server.reply());
      await request;
      expect(session.chat, isEmpty);
      expect(session.shareFoodContext, false);
      expect(session.aiBusy, false);
      session.dispose();
      server.api.close();
    },
  );

  test('local-only test mode never falls back to cloud', () async {
    final server = ChatServer()..consent = false;
    final service = LocalService(server.api, fail: true);
    await expectLater(
      service.respond(
        task: AiTask.conversation,
        complexity: AiComplexity.routine,
        prompt: 'lunch idea',
      ),
      throwsA(
        isA<BackendException>().having(
          (e) => e.message,
          'code',
          'local_ai_inference_failed',
        ),
      ),
    );
    expect(server.requests, isEmpty);
    server.consent = true;
    await expectLater(
      service.respond(
        task: AiTask.conversation,
        complexity: AiComplexity.complex,
        prompt: 'compare several meal ideas',
      ),
      throwsA(isA<BackendException>()),
    );
    expect(server.requests, isEmpty);
    server.api.close();
  });

  test(
    'explicit local-only mode answers routine and complex requests without cloud',
    () async {
      final server = ChatServer()..consent = false;
      final service = LocalService(server.api, installed: true);
      final result = await service.respond(
        task: AiTask.conversation,
        complexity: AiComplexity.routine,
        prompt: 'lunch idea',
      );
      expect(result.source, 'on_device_gemma');
      final complex = await service.respond(
        task: AiTask.conversation,
        complexity: AiComplexity.complex,
        prompt: 'compare these choices',
      );
      expect(complex.source, 'on_device_gemma');
      expect(service.localCalls, 2);
      expect(server.requests, isEmpty);
      server.api.close();
    },
  );

  test(
    'history stays within the API context limit and clear removes it',
    () async {
      final server = ChatServer();
      final session = server.session();
      for (var i = 0; i < 7; i++) {
        await session.submitChat(
          'Question $i ${List.filled(1000, '\n').join()} end',
        );
      }
      expect(
        (server.requests.last['context'] as String).length,
        lessThanOrEqualTo(18000),
      );
      session.clearChat();
      await session.submitChat('A fresh question');
      expect(
        (jsonDecode(server.requests.last['context'] as String)
            as Map)['history'],
        isEmpty,
      );
      session.dispose();
      server.api.close();
    },
  );
}
