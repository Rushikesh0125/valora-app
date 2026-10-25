import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:valora_mobile/core/models.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/app.dart';

class AccountServer {
  Map<String, dynamic>? profile;
  Map<String, dynamic>? preferences;
  Map<String, dynamic>? foodState;
  int foodVersion = 0;
  String? foodMutationId;
  final memory = <String, Map<String, dynamic>>{};
  bool fail = false;
  Completer<void>? holdProfileSave;
  int writes = 0;

  BackendApi api() => BackendApi(
    baseUrl: 'https://account.test',
    accessToken: () async => 'test-token',
    client: MockClient((request) async {
      if (fail) return http.Response('{"error":"unavailable"}', 503);
      final path = request.url.path;
      Object? result;
      if (request.method == 'GET') {
        result = switch (path) {
          '/v1/profile' => profile,
          '/v1/preferences' => preferences,
          '/v1/memory' => memory.values.toList(),
          '/v1/food-state' => {'version': foodVersion, 'state': foodState},
          _ => throw StateError(path),
        };
      } else {
        writes++;
        final body = request.body.isEmpty
            ? null
            : jsonDecode(request.body) as Map<String, dynamic>;
        if (path == '/v1/food-state') {
          if (foodMutationId == body!['mutationId']) {
            if (jsonEncode(foodState) != jsonEncode(body['state'])) {
              return http.Response('{"error":"food_state_conflict"}', 409);
            }
          } else {
            if (body['expectedVersion'] != foodVersion) {
              return http.Response('{"error":"food_state_conflict"}', 409);
            }
            foodState = body['state'] as Map<String, dynamic>;
            foodMutationId = body['mutationId'] as String;
            foodVersion++;
          }
          result = {'version': foodVersion};
        } else if (path == '/v1/profile') {
          if (holdProfileSave != null) await holdProfileSave!.future;
          profile = body;
          result = body;
        } else if (path == '/v1/preferences') {
          preferences = body;
          result = body;
        } else if (path == '/v1/memory') {
          final key = body!['key'] as String;
          result = memory[key] = {...body, 'id': key};
        } else if (request.method == 'DELETE') {
          memory.remove(path.split('/').last);
          result = {'deleted': true};
        } else {
          throw StateError(path);
        }
      }
      return http.Response(jsonEncode({'data': result}), 200);
    }),
  );

  SessionController session() => SessionController()
    ..signedIn = true
    ..backendApi = api();
}

void main() {
  testWidgets(
    'auth gate restores an existing profile and returns to sign-in after logout',
    (tester) async {
      final server = AccountServer()
        ..profile = (Profile()..acknowledged = true).toJson();
      final session = server.session()
        ..signedIn = false
        ..authResolved = true;
      addTearDown(session.dispose);
      await tester.pumpWidget(ValoraApp(session: session));
      expect(find.text('Continue with Google'), findsOneWidget);
      session.signedIn = true;
      await session.loadAccountData();
      await tester.pumpAndSettle();
      expect(find.text('What do you need\nright now?'), findsOneWidget);
      expect(find.text("Let's make food feel easier."), findsNothing);
      await session.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  test(
    'API time strings restore without seconds and remain valid on write',
    () async {
      final server = AccountServer()
        ..profile = (Profile()..acknowledged = true).toJson()
        ..preferences = {
          'locale': 'en-IN',
          'currency': 'INR',
          'notificationsEnabled': true,
          'notificationFrequency': 'Daily',
          'notificationCategories': ['Plan ready'],
          'quietStart': '22:15:00',
          'quietEnd': '07:30:00',
          'timeZone': 'Asia/Kolkata',
        };
      final session = server.session();
      await session.loadAccountData();
      expect(session.quietStart, '22:15');
      session.updateNotifications(() => session.notificationsEnabled = false);
      await session.saveAccountData();
      expect(server.preferences!['quietEnd'], '07:30');
      expect(server.preferences!['notificationsEnabled'], false);
      session.dispose();
    },
  );

  test(
    'sign-out stops queued writes after an already-issued request',
    () async {
      final server = AccountServer()
        ..profile = (Profile()..acknowledged = true).toJson();
      final session = server.session();
      await session.loadAccountData();
      server.holdProfileSave = Completer<void>();
      session.updateProfile(() => session.profile.budget = 9000);
      final saving = session.saveAccountData();
      await Future<void>.delayed(Duration.zero);
      await session.signOut();
      server.holdProfileSave!.complete();
      await saving;
      // The initial food draft saves before the held profile request.
      expect(server.writes, 2);
      expect(session.profile.budget, 2000);
      expect(session.hasUnsavedChanges, false);
      session.dispose();
    },
  );

  test(
    'confirmed onboarding and edits restore across new app sessions',
    () async {
      final server = AccountServer();
      final first = server.session();
      await first.loadAccountData();
      expect(first.onboarded, false);
      first.profile.acknowledged = true;
      await first.completeOnboarding();
      expect(first.onboarded, true);
      first.updateProfile(() {
        first.profile.pattern = 'Vegan';
        first.profile.coverage = 'Dinner only';
      });
      first.updateNotifications(() {
        first.quietStart = '21:30';
        first.frequency = 'Weekly';
      });
      await first.saveAccountData();
      expect(first.saveError, isEmpty);
      first.dispose();

      final second = server.session();
      await second.loadAccountData();
      expect(second.onboarded, true);
      expect(second.profile.pattern, 'Vegan');
      expect(second.profile.coverage, 'Dinner only');
      expect(second.quietStart, '21:30');
      expect(second.frequency, 'Weekly');
      second.dispose();
    },
  );

  test(
    'failed load cannot be mistaken for a new account or overwrite data',
    () async {
      final server = AccountServer()..fail = true;
      final session = server.session();
      await session.loadAccountData();
      expect(session.accountLoaded, false);
      expect(session.accountError, isNotEmpty);
      session.profile.acknowledged = true;
      await session.completeOnboarding();
      expect(session.onboarded, false);
      expect(server.writes, 0);
      session.dispose();
    },
  );

  test('failed onboarding stays on confirmation and retry saves it', () async {
    final server = AccountServer();
    final session = server.session();
    await session.loadAccountData();
    session.profile.acknowledged = true;
    server.fail = true;
    await session.completeOnboarding();
    expect(session.onboarded, false);
    expect(session.saveError, isNotEmpty);
    server.fail = false;
    await session.completeOnboarding();
    expect(session.onboarded, true);
    expect(session.hasUnsavedChanges, false);
    session.dispose();
  });

  test(
    'paused facts and removals persist without stale metadata restoring values',
    () async {
      final server = AccountServer()
        ..profile = (Profile()..acknowledged = true).toJson();
      final first = server.session();
      await first.loadAccountData();
      first.updateProfile(() => first.profile.allergies.add('Peanuts'));
      first.pauseFact('allergy:Peanuts');
      await first.saveAccountData();
      first.dispose();
      final restored = server.session();
      await restored.loadAccountData();
      expect(restored.safetyPaused, true);
      restored.removeFact('allergy:Peanuts');
      await restored.saveAccountData();
      expect(server.memory.containsKey('allergy:Peanuts'), false);
      restored.dispose();
      final again = server.session();
      await again.loadAccountData();
      expect(again.profile.allergies, isEmpty);
      expect(again.safetyPaused, false);
      again.dispose();
    },
  );

  test(
    'edits made during a save are serialized after the earlier revision',
    () async {
      final server = AccountServer()
        ..profile = (Profile()..acknowledged = true).toJson();
      final session = server.session();
      await session.loadAccountData();
      server.holdProfileSave = Completer<void>();
      session.updateProfile(() => session.profile.budget = 3000);
      final saving = session.saveAccountData();
      await Future<void>.delayed(Duration.zero);
      session.updateProfile(() => session.profile.budget = 4500);
      server.holdProfileSave!.complete();
      await saving;
      expect(server.profile!['weeklyBudgetInr'], 4500);
      expect(session.hasUnsavedChanges, false);
      session.dispose();
    },
  );

  test(
    'sign-out clears account data and ignores in-flight load results',
    () async {
      final response = Completer<http.Response>();
      final session = SessionController()..signedIn = true;
      session.backendApi = BackendApi(
        baseUrl: 'https://account.test',
        accessToken: () async => 'token',
        client: MockClient((_) => response.future),
      );
      session.profile.pattern = 'Vegan';
      session.pausedFacts.add('pattern');
      session.chat.add(const ChatEntry('private', true));
      final loading = session.loadAccountData();
      await session.signOut();
      response.complete(http.Response('{"data":null}', 200));
      await loading;
      expect(session.profile.pattern, 'Omnivore');
      expect(session.chat, isEmpty);
      expect(session.pausedFacts, isEmpty);
      expect(session.accountLoaded, false);
      expect(session.signedIn, false);
      session.dispose();
    },
  );
}
