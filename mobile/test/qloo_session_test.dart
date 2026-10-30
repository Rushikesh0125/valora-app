import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/backend_api.dart';
import 'package:valora_mobile/core/qloo_session.dart';

void main() {
  test(
    'Discover uses existing bearer and backend without separate auth',
    () async {
      final backend = BackendApi(
        baseUrl: 'https://nebius.test',
        accessToken: () async => 'existing',
        client: MockClient((req) async {
          expect(req.url.host, 'nebius.test');
          expect(req.headers['authorization'], 'Bearer existing');
          return http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/consent')
                  ? {'enabled': false}
                  : {'selections': []},
            }),
            200,
          );
        }),
      );
      final api = QlooSession(
        api: backend,
        isSignedIn: () => true,
        generation: () => 0,
      );
      await api.initialize();
      expect(
        (await api.request('GET', '/v1/qloo/tastes'))['selections'],
        isEmpty,
      );
      api.close();
      expect(await backend.getCloudAiConsent(), isFalse);
    },
  );
  test(
    'late account response is discarded and adapter disposal does not close shared client',
    () async {
      var epoch = 0, calls = 0;
      final pending = Completer<http.Response>();
      final client = MockClient((req) async {
        calls++;
        return calls == 1
            ? pending.future
            : http.Response('{"data":{"selections":[]}}', 200);
      });
      final backend = BackendApi(
        baseUrl: 'https://nebius.test',
        accessToken: () async => 'existing',
        client: client,
      );
      final api = QlooSession(
        api: backend,
        isSignedIn: () => true,
        generation: () => epoch,
      );
      final request = api.request('GET', '/v1/qloo/tastes');
      final check = expectLater(request, throwsA(isA<QlooApiException>()));
      await Future<void>.delayed(Duration.zero);
      epoch++;
      pending.complete(http.Response('{"data":{"selections":[]}}', 200));
      await check;
      api.close();
      expect(
        (await backend.qlooRequest('GET', '/v1/qloo/tastes'))['selections'],
        isEmpty,
      );
    },
  );
  test('signed-out Discover never sends a request', () async {
    var calls = 0;
    final backend = BackendApi(
      baseUrl: 'https://nebius.test',
      accessToken: () async {
        calls++;
        return 'token';
      },
    );
    final api = QlooSession(
      api: backend,
      isSignedIn: () => false,
      generation: () => 1,
    );
    await expectLater(
      api.request('PUT', '/v1/qloo/tastes', {'selections': []}),
      throwsA(isA<QlooApiException>()),
    );
    expect(calls, 0);
  });
}
