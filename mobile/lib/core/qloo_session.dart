import 'backend_api.dart';

class QlooApiException implements Exception {
  QlooApiException(this.code);
  final String code;
  @override
  String toString() => switch (code) {
    'cloud_ai_consent_required' =>
      'Enable Nebius cloud AI consent in AI settings before refining.',
    'qloo_key_pending' =>
      'Qloo is not configured. Your saved plan is unchanged.',
    'selection_needs_resolution' =>
      'Search again to refresh these Qloo matches.',
    'refinement_needs_clarification' => 'Try “milder”, “softer” or “quicker”.',
    'account_rate_limited' ||
    'qloo_rate_limited' => 'Please wait a minute before retrying.',
    'unauthorized' =>
      'Your session changed. Open Discover again after signing in.',
    _ => 'Could not complete discovery ($code). Please retry.',
  };
}

/// Shares the existing authenticated client. Never owns or closes it.
class QlooSession {
  QlooSession({
    required this.api,
    required this.isSignedIn,
    required this.generation,
  });
  final BackendApi api;
  final bool Function() isSignedIn;
  final int Function() generation;
  bool get signedIn => isSignedIn();
  Future<void> initialize() async {}
  Future<void> start() async => throw QlooApiException('unauthorized');
  Future<void> logout() async =>
      throw QlooApiException('use_main_account_controls');
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final epoch = generation();
    if (!signedIn) throw QlooApiException('unauthorized');
    try {
      final result = await api.qlooRequest(method, path, body);
      if (epoch != generation() || !signedIn)
        throw QlooApiException('unauthorized');
      return result;
    } on BackendException catch (e) {
      throw QlooApiException(e.message);
    }
  }

  void close() {}
}
