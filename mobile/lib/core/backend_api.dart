import 'dart:convert';

import 'package:http/http.dart' as http;

/// Typed client for Valora's authenticated backend. No token means no request;
/// the API never silently falls back to demo identities or data.
class BackendApi {
  BackendApi({
    required this.baseUrl,
    required this.accessToken,
    this.onUnauthorized,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() accessToken;
  final void Function()? onUnauthorized;
  final http.Client _client;

  Future<Map<String, dynamic>> interpretPantry(String transcript) async =>
      (await _request(
            'POST',
            '/v1/pantry/interpret',
            body: {'transcript': transcript},
            timeout: const Duration(seconds: 60),
          ))['data']
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> getFirstDayPlan() async =>
      (await _request('GET', '/v1/first-day-plan'))['data']
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> generateFirstDayPlan({
    bool retry = false,
    bool confirmedPreferences = false,
  }) async =>
      (await _request(
            'POST',
            '/v1/first-day-plan',
            body: {
              'retry': retry,
              'confirmedPreferences': confirmedPreferences,
            },
            timeout: const Duration(seconds: 60),
          ))['data']
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> proposeMealChange(String request) async =>
      (await _request(
            'POST',
            '/v1/meal-plan/proposals',
            body: {'request': request},
            timeout: const Duration(seconds: 60),
          ))['data']
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> confirmMealChange(String id) async =>
      (await _request('POST', '/v1/meal-plan/proposals/$id/confirm'))['data']
          as Map<String, dynamic>;

  Future<Map<String, dynamic>?> getProfile() => _get('/v1/profile');
  Future<Map<String, dynamic>> getFoodState() async =>
      (await _request('GET', '/v1/food-state'))['data'] as Map<String, dynamic>;
  Future<int> saveFoodState(Map<String, dynamic> write) async =>
      (await _put('/v1/food-state', write))['data']['version'] as int;
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profile) =>
      _put('/v1/profile', profile);
  Future<Map<String, dynamic>?> getPreferences() => _get('/v1/preferences');
  Future<Map<String, dynamic>> savePreferences(
    Map<String, dynamic> preferences,
  ) => _put('/v1/preferences', preferences);
  Future<List<Map<String, dynamic>>> getMemory() async {
    final data = await _request('GET', '/v1/memory');
    return (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> saveMemory(Map<String, dynamic> fact) =>
      _request('POST', '/v1/memory', body: fact);
  Future<Map<String, dynamic>> updateMemoryStatus(String id, String status) =>
      _request('PATCH', '/v1/memory/$id', body: {'status': status});
  Future<void> deleteMemory(String id) async =>
      _request('DELETE', '/v1/memory/$id');

  Future<bool> getCloudAiConsent() async =>
      (await _request('GET', '/v1/ai/consent'))['data']['enabled'] as bool;
  Future<bool> setCloudAiConsent(bool enabled) async =>
      ((await _request(
            'PUT',
            '/v1/ai/consent',
            body: {'enabled': enabled},
          ))['data']['enabled'])
          as bool;
  Future<Map<String, dynamic>> requestCloudAi({
    required String task,
    required String complexity,
    required String prompt,
    String? context,
  }) => _request(
    'POST',
    '/v1/ai/respond',
    timeout: const Duration(seconds: 60),
    body: {
      'task': task,
      'complexity': complexity,
      'prompt': prompt,
      if (context != null) 'context': context,
    },
  );

  Future<Map<String, dynamic>?> _get(String path) async =>
      (await _request('GET', path))['data'] as Map<String, dynamic>?;
  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      onUnauthorized?.call();
      throw const BackendException(
        'Sign in to connect to your saved Valora data.',
      );
    }
    final uri = Uri.parse(baseUrl).resolve(path);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'authorization': 'Bearer $token',
        'accept': 'application/json',
      })
      ..body = body == null ? '' : jsonEncode(body);
    if (body != null) request.headers['content-type'] = 'application/json';
    final response = await (() async {
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    })().timeout(timeout);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) onUnauthorized?.call();
      throw BackendException(
        decoded['error'] as String? ??
            'Backend request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  void close() => _client.close();
}

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
