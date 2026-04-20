import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps Marathi speech I/O using the Android platform's native engines.
/// Both STT and TTS work offline once the mr-IN language pack is installed
/// (one-time setup from Settings → Languages, documented in the app's
/// onboarding flow).
class VoiceService {
  static const String _mrLocale = 'mr-IN';

  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _sttReady = false;

  Future<void> initialize() async {
    _sttReady = await _stt.initialize(
      onStatus: (s) {},
      onError: (e) {},
    );

    await _tts.setLanguage(_mrLocale);
    await _tts.setSpeechRate(0.45);   // Slower than default; clearer on speakers
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Force offline TTS when the mr-IN engine is installed locally.
    // On devices without it, this silently falls back to the network engine.
    await _tts.awaitSpeakCompletion(true);
  }

  bool get isAvailable => _sttReady;

  /// Starts listening and resolves when the user stops speaking.
  /// Returns the Devanagari transcript.
  Future<String> listen({Duration timeout = const Duration(seconds: 10)}) async {
    if (!_sttReady) throw StateError('STT not initialized');

    final completer = Completer<String>();
    String best = '';

    await _stt.listen(
      localeId: _mrLocale,
      listenFor: timeout,
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      onResult: (r) {
        best = r.recognizedWords;
        if (r.finalResult && !completer.isCompleted) {
          completer.complete(best);
        }
      },
    );

    // Safety: ensure we eventually resolve even if the engine stalls.
    Timer(timeout + const Duration(seconds: 1), () {
      if (!completer.isCompleted) {
        _stt.stop();
        completer.complete(best);
      }
    });

    return completer.future;
  }

  Future<void> stop() => _stt.stop();

  /// Speak a Marathi Devanagari string.
  Future<void> speak(String marathi) async {
    await _tts.stop();
    await _tts.speak(marathi);
  }

  void dispose() {
    _stt.cancel();
    _tts.stop();
  }
}
