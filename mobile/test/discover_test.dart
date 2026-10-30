import 'package:valora_mobile/core/backend_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valora_mobile/features/discover.dart';
import 'package:valora_mobile/core/qloo_session.dart';

class FakeSession extends QlooSession {
  FakeSession({
    this.authenticated = false,
    this.consent = false,
    this.failSearch = false,
  }) : super(
         api: BackendApi(
           baseUrl: 'https://test.invalid',
           accessToken: () async => 'test',
         ),
         isSignedIn: () => true,
         generation: () => 0,
       );
  bool authenticated, consent, failSearch;
  final calls = <String>[];
  @override
  bool get signedIn => authenticated;
  @override
  Future<void> initialize() async {}
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    calls.add('$method $path');
    if (path.endsWith('/consent')) return {'enabled': consent};
    if (path.endsWith('/tastes'))
      return {'selections': <Map<String, dynamic>>[]};
    if (path.endsWith('/search')) {
      if (failSearch) throw QlooApiException('qloo_key_pending');
      return {
        'choices': [
          {
            'id': 'urn:tag:genre:place:indian',
            'kind': 'tag',
            'label': 'Indian',
          },
        ],
      };
    }
    if (path.endsWith('/recommend'))
      return {
        'dining': [],
        'meals': [],
        'constraints': body!['constraints'],
        'toolCalls': 2,
        'unmetConstraints': ['No matching evidence.'],
      };
    throw StateError(path);
  }

  @override
  Future<void> logout() async {
    authenticated = false;
  }
}

Future<void> open(WidgetTester t, FakeSession session) async {
  await t.binding.setSurfaceSize(const Size(1100, 1000));
  await t.pumpWidget(MaterialApp(home: QlooHome(session: session)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'signed-out journey offers Google sign-in without fabricated cards',
    (t) async {
      await open(t, FakeSession());
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Discover meals & dining'), findsNothing);
      expect(find.textContaining('Live Qloo access'), findsOneWidget);
    },
  );
  testWidgets(
    'search displays choices without silently selecting or persisting',
    (t) async {
      final session = FakeSession(authenticated: true);
      await open(t, session);
      await t.enterText(find.byType(TextField).first, 'Indian');
      await t.tap(find.text('Find Qloo matches'));
      await t.pumpAndSettle();
      expect(find.text('Which match did you mean?'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      expect(session.calls.where((c) => c.startsWith('PUT')), isEmpty);
    },
  );
  testWidgets('missing key remains a truthful recoverable state', (t) async {
    await open(t, FakeSession(authenticated: true, failSearch: true));
    await t.enterText(find.byType(TextField).first, 'Indian');
    await t.tap(find.text('Find Qloo matches'));
    await t.pumpAndSettle();
    expect(find.textContaining('Qloo is not configured'), findsOneWidget);
    expect(find.text('Your shortlist'), findsNothing);
  });
  testWidgets('selection enables discovery and empty data stays empty', (
    t,
  ) async {
    final session = FakeSession(authenticated: true);
    await open(t, session);
    await t.enterText(find.byType(TextField).first, 'Indian');
    await t.tap(find.text('Find Qloo matches'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Select Indian'));
    await t.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Refine my options'),
          )
          .onPressed,
      isNotNull,
    );
    expect(session.calls.where((c) => c.contains('/consent')), isEmpty);
    await t.ensureVisible(find.text('Discover meals & dining'));
    await t.tap(find.text('Discover meals & dining'));
    await t.pumpAndSettle();
    expect(find.text('Your shortlist'), findsOneWidget);
    expect(
      find.text(
        'No verified catalog matches for these tastes and preferences. Try adjusting your search.',
      ),
      findsNWidgets(2),
    );
    expect(session.calls.where((c) => c.startsWith('PUT')), isEmpty);
  });
  testWidgets(
    'saving tastes asks for confirmation and cancelling sends no write',
    (t) async {
      final session = FakeSession(authenticated: true);
      await open(t, session);
      await t.ensureVisible(find.text('Review & save tastes'));
      await t.tap(find.text('Review & save tastes'));
      await t.pumpAndSettle();
      expect(find.text('Remember these tastes?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(session.calls.where((c) => c.startsWith('PUT')), isEmpty);
    },
  );
  testWidgets('confirmed tastes refresh the main meal agent after the save', (
    t,
  ) async {
    final session = FakeSession(authenticated: true);
    var refreshed = 0;
    await t.binding.setSurfaceSize(const Size(1100, 1000));
    await t.pumpWidget(
      MaterialApp(
        home: QlooHome(
          session: session,
          onTastesSaved: () async {
            expect(session.calls, contains('PUT /v1/qloo/tastes'));
            refreshed++;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Review & save tastes'));
    await t.tap(find.text('Review & save tastes'));
    await t.pumpAndSettle();
    expect(refreshed, 0);
    await t.tap(find.text('Save tastes'));
    await t.pumpAndSettle();
    expect(refreshed, 1);
  });
  testWidgets('refinement needs tastes and has no cloud opt-in switch', (
    t,
  ) async {
    await open(t, FakeSession(authenticated: true));
    final button = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Refine my options'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Allow cloud AI for conversation'), findsNothing);
    expect(
      find.textContaining(
        'Refinement requires your existing Nebius cloud AI consent.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('signed-in controls fit a narrow screen with large text', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(home: QlooHome(session: FakeSession(authenticated: true))),
    );
    await t.pumpAndSettle();
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await t.pumpAndSettle();
    await t.pump();
  });
}
