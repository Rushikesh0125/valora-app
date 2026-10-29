import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleSignInService {
  GoogleSignInService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'valoranebius.access_token';
  static const _refreshKey = 'valoranebius.refresh_token';
  static const _expiryKey = 'valoranebius.access_expiry';
  static const _stateKey = 'valoranebius.oauth_state';
  Future<String?>? _refreshing;
  int _epoch = 0;
  bool _loggingOut = false;
  Future<void> _storageWrites = Future<void>.value();

  Future<bool> get signedIn async =>
      (await _storage.read(key: _refreshKey)) != null;

  Future<void> signIn() async {
    final state = _randomState();
    await _storage.write(key: _stateKey, value: state);
    final response = await _client
        .post(
          Uri.parse(baseUrl).resolve('/v1/auth/google/start'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'clientState': state}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('google_sign_in_unavailable');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final authorizationUrl = body['data']?['authorizationUrl'];
    if (authorizationUrl is! String ||
        !await launchUrl(
          Uri.parse(authorizationUrl),
          mode: LaunchMode.externalApplication,
        )) {
      throw Exception('could_not_open_sign_in');
    }
  }

  Future<bool> handleCallback(Uri uri) async {
    final epoch = _epoch;
    if (uri.scheme != 'valoranebius' ||
        uri.host != 'auth' ||
        uri.path != '/callback')
      return false;
    final expectedState = await _storage.read(key: _stateKey);
    await _storage.delete(key: _stateKey);
    if (expectedState == null ||
        uri.queryParameters['state'] != expectedState) {
      throw Exception('google_sign_in_state_invalid');
    }
    final code = uri.queryParameters['code'];
    if (uri.queryParameters.containsKey('error') || code == null) {
      throw Exception('google_sign_in_cancelled');
    }
    final response = await _client
        .post(
          Uri.parse(baseUrl).resolve('/v1/auth/exchange'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'code': code, 'state': expectedState}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('google_sign_in_exchange_failed');
    final data =
        (jsonDecode(response.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    await _saveTokens(data, epoch);
    return epoch == _epoch;
  }

  Future<String?> accessToken() async {
    if (_loggingOut) return null;
    final epoch = _epoch;
    final token = await _storage.read(key: _accessKey);
    final expiry =
        int.tryParse(await _storage.read(key: _expiryKey) ?? '0') ?? 0;
    if (epoch != _epoch) return null;
    if (token != null && DateTime.now().millisecondsSinceEpoch < expiry - 30000)
      return token;
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final epoch = _epoch;
    final refreshToken = await _storage.read(key: _refreshKey);
    if (refreshToken == null) return null;
    try {
      final response = await _client
          .post(
            Uri.parse(baseUrl).resolve('/v1/auth/refresh'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
      if (epoch != _epoch) return null;
      if (response.statusCode == 401) {
        await signOut();
        return null;
      }
      if (response.statusCode != 200)
        throw Exception('session_temporarily_unavailable');
      final data =
          (jsonDecode(response.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      await _saveTokens(data, epoch);
      if (epoch != _epoch) return null;
      return data['accessToken'] as String;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data, int epoch) {
    final work = _storageWrites.then((_) async {
      if (epoch != _epoch) return;
      final access = data['accessToken'] as String;
      final refresh = data['refreshToken'] as String;
      final expiresIn = data['expiresIn'] as int;
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
      await _storage.write(
        key: _expiryKey,
        value: '${DateTime.now().millisecondsSinceEpoch + expiresIn * 1000}',
      );
    });
    _storageWrites = work.catchError((Object _) {});
    return work;
  }

  Future<void> signOut() async {
    _epoch++;
    _loggingOut = true;
    String? refreshToken;
    try {
      final clearing = _storageWrites.then((_) async {
        refreshToken = await _storage.read(key: _refreshKey);
        await _storage.delete(key: _accessKey);
        await _storage.delete(key: _refreshKey);
        await _storage.delete(key: _expiryKey);
        await _storage.delete(key: _stateKey);
      });
      _storageWrites = clearing.catchError((Object _) {});
      await clearing;
      if (refreshToken != null) {
        try {
          await _client
              .post(
                Uri.parse(baseUrl).resolve('/v1/auth/logout'),
                headers: {'content-type': 'application/json'},
                body: jsonEncode({'refreshToken': refreshToken}),
              )
              .timeout(const Duration(seconds: 15));
        } catch (_) {}
      }
    } finally {
      _loggingOut = false;
    }
  }

  String _randomState() {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  void close() => _client.close();
}
