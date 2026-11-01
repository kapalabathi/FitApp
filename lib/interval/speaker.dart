import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../platform/app_platform.dart';

/// Die Sprachausgabe des Geräts.
abstract class Speaker {
  factory Speaker.forDevice() =>
      AppPlatform.isLinux ? SpdSpeaker() : _TtsSpeaker();

  void say(String text);
  void stop();
}

class _TtsSpeaker implements Speaker {
  _TtsSpeaker() {
    _tts.setLanguage('de-DE');
  }

  final FlutterTts _tts = FlutterTts();

  @override
  void say(String text) => _tts.speak(text);

  @override
  void stop() => _tts.stop();
}

/// Unter Linux gibt es `flutter_tts` nicht; dort spricht speech-dispatcher.
/// Fehlt er, bleibt die Ansage aus, das Training läuft weiter.
class SpdSpeaker implements Speaker {
  /// `--` trennt die Schalter vom Text, falls der mit einem Strich beginnt.
  static List<String> arguments(String text) => ['-l', 'de', '--', text];

  @override
  void say(String text) {
    Process.run('spd-say', arguments(text)).catchError(
        (Object _) => ProcessResult(0, 1, '', ''));
  }

  @override
  void stop() {
    Process.run('spd-say', ['-S']).catchError(
        (Object _) => ProcessResult(0, 1, '', ''));
  }
}
