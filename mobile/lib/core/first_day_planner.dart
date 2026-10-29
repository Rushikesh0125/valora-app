import 'dart:async';
import 'package:flutter/foundation.dart';
import 'backend_api.dart';

/// A bounded foreground generation session. Saved results live on the server.
class FirstDayPlanner extends ChangeNotifier {
  FirstDayPlanner(this.api);
  final BackendApi api;
  Map<String, dynamic> state = {'status': 'not_started'};
  bool busy = false;
  bool _disposed = false;
  int _requests = 0;
  int _generation = 0;
  bool _foodConsentGiven = false;
  bool preferencesPending = false;
  void preferencesChanged() {
    _generation++;
    _timer?.cancel();
    proposal = null;
    changeBusy = false;
    changeMessage = '';
    preferencesPending = true;
    busy = false;
    state = {'status': 'review_required', 'error': 'preferences_unsaved'};
    notifyListeners();
  }

  void preferencesSaved() {
    if (!preferencesPending) return;
    preferencesPending = false;
    state = {'status': 'review_required', 'error': 'preferences_changed'};
    notifyListeners();
    unawaited(refresh(retry: true));
  }

  Map<String, dynamic>? proposal;
  bool changeBusy = false;
  String changeMessage = '';
  Future<Map<String, dynamic>?> proposeChange(String request) async {
    if (_disposed || busy || changeBusy || preferencesPending) return null;
    final generation = _generation;
    changeBusy = true;
    changeMessage = '';
    notifyListeners();
    try {
      final result = await api.proposeMealChange(request);
      if (_disposed || generation != _generation) return null;
      proposal = result['status'] == 'proposal' ? result : null;
      return result;
    } finally {
      if (!_disposed && generation == _generation) {
        changeBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> confirmChange() async {
    final pending = proposal;
    if (_disposed ||
        pending == null ||
        busy ||
        changeBusy ||
        preferencesPending)
      return;
    final generation = _generation;
    changeBusy = true;
    changeMessage = '';
    notifyListeners();
    try {
      final result = await api.confirmMealChange(pending['id'] as String);
      if (_disposed || generation != _generation) return;
      if (result['status'] == 'ready') {
        state = result;
        proposal = null;
        changeMessage = 'Meal updated in My Plan.';
      } else {
        proposal = null;
        changeMessage =
            'The plan or your preferences changed, or the proposal expired. Ask for a fresh suggestion.';
      }
    } catch (_) {
      if (!_disposed && generation == _generation)
        changeMessage =
            'Could not confirm the update. Retry to check the saved result.';
    } finally {
      if (!_disposed && generation == _generation) {
        changeBusy = false;
        notifyListeners();
      }
    }
  }

  void cancelChange() {
    if (changeBusy) return;
    final hadProposal = proposal != null;
    proposal = null;
    changeMessage = hadProposal ? 'Kept your existing meal.' : '';
    notifyListeners();
  }

  Timer? _timer;
  DateTime? _deadline;
  String get status => state['status'] as String? ?? 'not_started';

  Future<void> refresh({bool enableConsent = false, bool retry = false}) async {
    if (_disposed || busy || changeBusy || preferencesPending) return;
    final generation = _generation;
    _timer?.cancel();
    busy = true;
    if (retry || _deadline == null) {
      _requests = 0;
      _deadline = DateTime.now().add(const Duration(minutes: 5));
    }
    notifyListeners();
    try {
      if (enableConsent) {
        await api.setCloudAiConsent(true);
        _foodConsentGiven = true;
      }
      if (_disposed || generation != _generation) return;
      var result = await api.getFirstDayPlan();
      if (_disposed || generation != _generation) return;
      if (result['status'] == 'not_started' && !_foodConsentGiven) {
        state = {'status': 'consent_required'};
        return;
      }
      if (['plan_outdated', 'preferences_changed'].contains(result['error'])) {
        _requests = 0;
        _deadline = DateTime.now().add(const Duration(minutes: 5));
      }
      final shouldStart =
          result['status'] == 'not_started' ||
          (retry && result['status'] != 'ready') ||
          result['canRetryAutomatically'] == true;
      if (shouldStart) {
        if (_requests >= 3 || DateTime.now().isAfter(_deadline!)) {
          state = {'status': 'failed', 'error': 'generation_deadline'};
          return;
        }
        _requests++;
        state = {'status': 'generating'};
        notifyListeners();
        result = await api.generateFirstDayPlan(
          retry:
              retry ||
              [
                'plan_outdated',
                'preferences_changed',
              ].contains(result['error']),
          confirmedPreferences: _foodConsentGiven,
        );
      }
      if (_disposed || generation != _generation) return;
      state = result;
      final serverDeadline = result['deadlineAt'] as int?;
      if (serverDeadline != null) {
        _deadline = DateTime.fromMillisecondsSinceEpoch(serverDeadline * 1000);
      }
      if (result['error'] == 'consent_required') {
        state = {'status': 'consent_required'};
      } else if (status == 'generating' ||
          result['canRetryAutomatically'] == true) {
        _schedule();
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      final code = error is BackendException ? error.message : 'network_error';
      state = {'status': 'failed', 'error': code};
      if (code != 'unauthorized' && _requests < 3) _schedule();
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _schedule() {
    if (_disposed) return;
    if (DateTime.now().isAfter(_deadline!)) {
      state = {'status': 'failed', 'error': 'generation_deadline'};
      return;
    }
    _timer = Timer(const Duration(seconds: 5), () => refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
