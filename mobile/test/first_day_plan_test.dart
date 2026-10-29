import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:valora_mobile/core/first_day_planner.dart';
import 'package:valora_mobile/core/session_controller.dart';
import 'package:valora_mobile/features/first_day_plan.dart';

Map<String, dynamic> ready() => {
  'status': 'ready',
  'date': '2026-10-26',
  'timeZone': 'Asia/Kolkata',
  'provider': 'nebius',
  'model': 'nvidia/nemotron-3-super-120b-a12b',
  'meals': [
    {
      'meal': 'dinner',
      'recipe': {
        'name': 'Chickpea and cucumber bowl',
        'minutes': 10,
        'ingredients': ['chickpeas', 'cucumber'],
        'steps': ['Combine ingredients.'],
      },
    },
  ],
};

class PlanServer {
  bool consent = false, fail = false;
  int starts = 0;
  final profileSavedAtStart = <bool>[];
  bool profileSaved = false;
  Map<String, dynamic> state = {'status': 'not_started'};
  Completer<http.Response>? pending;
  late final api = BackendApi(
    baseUrl: 'https://plan.test',
    accessToken: () async => 'test',
    client: MockClient((request) async {
      final path = request.url.path;
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      if (path.endsWith('/consent')) {
        if (request.method == 'PUT') consent = body['enabled'] as bool;
        return response({'enabled': consent});
      }
      if (path == '/v1/first-day-plan') {
        if (request.method == 'GET') return response(state);
        starts++;
        profileSavedAtStart.add(profileSaved);
        if (pending != null) return pending!.future;
        state = !consent
            ? {'status': 'consent_required'}
            : fail
            ? {
                'status': 'failed',
                'error': 'ai_provider_timeout',
                'canRetryAutomatically': true,
              }
            : ready();
        return response(state);
      }
      if (path == '/v1/profile') profileSaved = true;
      return response({...body, if (path == '/v1/memory') 'id': body['key']});
    }),
  );
  http.Response response(Map<String, dynamic> data) =>
      http.Response(jsonEncode({'data': data}), 200);
}

void main() {
  test(
    'explicit consent generates a plan and another login restores without inference',
    () async {
      final server = PlanServer();
      final planner = FirstDayPlanner(server.api);
      addTearDown(server.api.close);
      addTearDown(planner.dispose);
      await planner.refresh();
      expect(planner.status, 'consent_required');
      expect(server.consent, false);
      await planner.refresh(enableConsent: true, retry: true);
      expect(planner.status, 'ready');
      expect(server.consent, true);
      final previous = server.starts;
      final restored = FirstDayPlanner(server.api);
      addTearDown(restored.dispose);
      await restored.refresh();
      expect(restored.status, 'ready');
      expect(server.starts, previous);
    },
  );
  test('onboarding saves the profile before starting the first plan', () async {
    final server = PlanServer();
    final session = SessionController()
      ..backendApi = server.api
      ..signedIn = true
      ..accountLoaded = true
      ..firstPlanConsent = true;
    session.profile.acknowledged = true;
    session.firstDayPlanner = FirstDayPlanner(server.api);
    addTearDown(session.dispose);
    await session.completeOnboarding();
    await Future<void>.delayed(Duration.zero);
    expect(server.profileSaved, true);
    expect(server.profileSavedAtStart, [true]);
    expect(session.onboarded, true);
    expect(session.firstDayPlanner!.status, 'ready');
    expect(server.starts, 1);
    expect(server.consent, true);
  });
  test('onboarding without consent does not enable cloud AI', () async {
    final server = PlanServer();
    final session = SessionController()
      ..backendApi = server.api
      ..signedIn = true
      ..accountLoaded = true;
    session.profile.acknowledged = true;
    session.firstDayPlanner = FirstDayPlanner(server.api);
    addTearDown(session.dispose);
    await session.completeOnboarding();
    await Future<void>.delayed(Duration.zero);
    expect(server.consent, false);
    expect(session.firstDayPlanner!.status, 'consent_required');
  });
  test('sign-out ignores a late generation response', () async {
    final server = PlanServer()
      ..consent = true
      ..pending = Completer<http.Response>();
    final session = SessionController()..backendApi = server.api;
    final planner = FirstDayPlanner(server.api);
    session.firstDayPlanner = planner;
    final request = planner.refresh(enableConsent: true);
    await Future<void>.delayed(Duration.zero);
    expect(server.starts, 1);
    await session.signOut();
    server.pending!.complete(server.response(ready()));
    await request;
    expect(session.firstDayPlanner, isNull);
    expect(planner.status, isNot('ready'));
    session.dispose();
  });
  test(
    'preference edits hide saved results until the edited profile is saved',
    () async {
      final server = PlanServer()..consent = true;
      final planner = FirstDayPlanner(server.api);
      addTearDown(planner.dispose);
      addTearDown(server.api.close);
      await planner.refresh(enableConsent: true);
      expect(planner.status, 'ready');
      planner.preferencesChanged();
      await planner.refresh(retry: true);
      expect(planner.status, 'review_required');
      expect(planner.preferencesPending, true);
      expect(server.starts, 1);
      planner.preferencesSaved();
      expect(planner.preferencesPending, false);
    },
  );
  testWidgets('automatic retries stop after three generation requests', (
    tester,
  ) async {
    final server = PlanServer()
      ..consent = true
      ..fail = true;
    final planner = FirstDayPlanner(server.api);
    addTearDown(planner.dispose);
    addTearDown(server.api.close);
    await planner.refresh(enableConsent: true);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
    }
    expect(server.starts, 3);
    expect(planner.status, 'failed');
  });
  testWidgets('completed plan shows actual recipes and no five-day examples', (
    tester,
  ) async {
    final server = PlanServer()..consent = true;
    final planner = FirstDayPlanner(server.api);
    addTearDown(planner.dispose);
    addTearDown(server.api.close);
    await planner.refresh(enableConsent: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstDayPlanView(planner: planner, onReview: () {}),
          ),
        ),
      ),
    );
    expect(find.text('dinner · Chickpea and cucumber bowl'), findsOneWidget);
    expect(find.text('Ingredients: chickpeas, cucumber'), findsOneWidget);
    expect(find.textContaining('Five-day'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('consent-required screen offers an explicit opt-in', (
    tester,
  ) async {
    final server = PlanServer();
    final planner = FirstDayPlanner(server.api);
    addTearDown(planner.dispose);
    addTearDown(server.api.close);
    await planner.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstDayPlanView(planner: planner, onReview: () {}),
        ),
      ),
    );
    expect(find.text('Allow & prepare today’s meals'), findsOneWidget);
    expect(server.consent, false);
    expect(find.textContaining('Chickpea'), findsNothing);
  });
  testWidgets(
    'every saved meal offers ingredients and dish ordering with honest unavailable states',
    (tester) async {
      final server = PlanServer()..consent = true;
      final planner = FirstDayPlanner(server.api);
      addTearDown(planner.dispose);
      addTearDown(server.api.close);
      await planner.refresh(enableConsent: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstDayPlanView(planner: planner, onReview: () {}),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ingredients to order'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not a live cart'), findsOneWidget);
      expect(find.text('• chickpeas'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Order this dish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Restaurant availability'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('meal proposal only changes saved plan after confirmation', () async {
    var confirmed = false;
    final api = BackendApi(
      baseUrl: 'https://proposal.test',
      accessToken: () async => 'token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/confirm')) {
          confirmed = true;
          return http.Response(jsonEncode({'data': ready()}), 200);
        }
        return http.Response(
          jsonEncode({
            'data': {
              'status': 'proposal',
              'id': 'proposal-id',
              'meal': 'dinner',
              'recipe': {'name': 'Pasta'},
            },
          }),
          200,
        );
      }),
    );
    final planner = FirstDayPlanner(api);
    addTearDown(planner.dispose);
    addTearDown(api.close);
    await planner.proposeChange('Italian tonight');
    expect(planner.status, 'not_started');
    expect(planner.proposal, isNotNull);
    expect(confirmed, false);
    await planner.confirmChange();
    expect(planner.status, 'ready');
    expect(planner.proposal, isNull);
    expect(confirmed, true);
  });
  test(
    'saving changed preferences regenerates without a review step',
    () async {
      final server = PlanServer()..consent = true;
      final planner = FirstDayPlanner(server.api);
      addTearDown(planner.dispose);
      addTearDown(server.api.close);
      await planner.refresh(enableConsent: true);
      planner.preferencesChanged();
      server.state = {
        'status': 'review_required',
        'error': 'preferences_changed',
        'canRetryAutomatically': true,
      };
      planner.preferencesSaved();
      await Future<void>.delayed(Duration.zero);
      expect(server.starts, 2);
      expect(planner.status, 'ready');
    },
  );
}
