import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valora_mobile/core/google_sign_in.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'valora.refresh_token': 'existing-refresh',
      'valora.access_token': 'expired',
      'valora.access_expiry': '0',
    }),
  );

  test('temporary provider failure preserves the session for retry', () async {
    final auth = GoogleSignInService(
      baseUrl: 'https://account.test',
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await expectLater(auth.accessToken(), throwsException);
    expect(await auth.signedIn, true);
    auth.close();
  });

  test(
    'a refresh response arriving after logout cannot restore the old account',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final auth = GoogleSignInService(
        baseUrl: 'https://account.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            started.complete();
            return pending.future;
          }
          return http.Response('{}', 200);
        }),
      );
      final refreshing = auth.accessToken();
      await started.future;
      await auth.signOut();
      pending.complete(
        http.Response(
          '{"data":{"accessToken":"late-access","refreshToken":"late-refresh","expiresIn":900}}',
          200,
        ),
      );
      expect(await refreshing, null);
      expect(await auth.signedIn, false);
      auth.close();
    },
  );

  test('invalid refresh credentials clear local tokens', () async {
    final auth = GoogleSignInService(
      baseUrl: 'https://account.test',
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    expect(await auth.accessToken(), null);
    expect(await auth.signedIn, false);
    auth.close();
  });

  test(
    'successful refresh rotates stored credentials and reuses the access token',
    () async {
      var calls = 0;
      final auth = GoogleSignInService(
        baseUrl: 'https://account.test',
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"data":{"accessToken":"new-access","refreshToken":"new-refresh","expiresIn":900}}',
            200,
          );
        }),
      );
      expect(await auth.accessToken(), 'new-access');
      expect(await auth.accessToken(), 'new-access');
      expect(calls, 1);
      expect(
        await const FlutterSecureStorage().read(key: 'valora.refresh_token'),
        'new-refresh',
      );
      auth.close();
    },
  );
}
