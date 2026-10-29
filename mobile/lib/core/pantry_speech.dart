import 'package:speech_to_text/speech_to_text.dart';

abstract class PantrySpeech {
  Future<bool> start({
    required void Function(String) onWords,
    required void Function(bool) onListening,
    required void Function(String) onError,
  });
  Future<void> stop();
  Future<void> cancel();
}

class DevicePantrySpeech implements PantrySpeech {
  static final shared = DevicePantrySpeech();
  final SpeechToText _speech = SpeechToText();
  void Function(bool)? _status;
  void Function(String)? _error;
  int _epoch = 0;
  Future<void> _canceling = Future<void>.value();
  @override
  Future<bool> start({
    required void Function(String) onWords,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) async {
    final epoch = ++_epoch;
    await _canceling;
    if (epoch != _epoch) return false;
    _status = onListening;
    _error = onError;
    try {
      final available = await _speech.initialize(
        onStatus: (status) => _status?.call(status == 'listening'),
        onError: (_) {
          _status?.call(false);
          _error?.call(
            'Speech input stopped. Check microphone permission or type your command.',
          );
        },
        options: [SpeechToText.androidNoBluetooth, SpeechToText.iosNoBluetooth],
      );
      if (epoch != _epoch) return false;
      if (!available) return false;
      final locales = await _speech.locales();
      if (epoch != _epoch) return false;
      final english =
          locales
              .where((l) => l.localeId.replaceAll('-', '_') == 'en_IN')
              .firstOrNull ??
          locales.where((l) => l.localeId.startsWith('en')).firstOrNull;
      onListening(true);
      await _speech.listen(
        onResult: (result) {
          if (epoch == _epoch) onWords(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: english?.localeId,
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: true,
          partialResults: true,
        ),
      );
      return true;
    } catch (_) {
      if (epoch == _epoch) {
        onListening(false);
        onError(
          'Speech recognition is unavailable. You can type your command.',
        );
      }
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      _error?.call(
        'Could not stop speech input. Close this panel and try again.',
      );
    }
  }

  @override
  Future<void> cancel() async {
    _epoch++;
    _status = null;
    _error = null;
    _canceling = _speech.cancel().catchError((Object _) {});
    await _canceling;
  }
}
