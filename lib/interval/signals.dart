import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/database.dart';
import 'interval_models.dart';
import 'interval_run.dart';

/// Welche Signale der Intervall-Timer gibt. Wird in der Datenbank gemerkt.
class SignalSettings {
  const SignalSettings({
    this.tone = true,
    this.vibration = true,
    this.voice = true,
  });

  SignalSettings.load(AppDatabase db)
      : tone = db.flag(_toneKey, fallback: true),
        vibration = db.flag(_vibrationKey, fallback: true),
        voice = db.flag(_voiceKey, fallback: true);

  static const _toneKey = 'signal.tone';
  static const _vibrationKey = 'signal.vibration';
  static const _voiceKey = 'signal.voice';

  final bool tone;
  final bool vibration;
  final bool voice;

  void save(AppDatabase db) {
    db
      ..setFlag(_toneKey, tone)
      ..setFlag(_vibrationKey, vibration)
      ..setFlag(_voiceKey, voice);
  }
}

/// Der gesprochene Text zu einem Ereignis, oder `null`, wenn nichts zu sagen
/// ist.
String? announcement(IntervalEvent event, TargetKind kind) {
  String describe(PlannedStep step) {
    final target = step.target;
    final name = step.label.isEmpty ? 'Nächster Abschnitt' : step.label;
    return target == null ? name : '$name, ${kind.format(target)}';
  }

  return switch (event) {
    StepEnding(secondsLeft: IntervalRun.warningFromS, next: final next?) =>
      'Gleich: ${describe(next)}',
    IntervalFinished() => 'Intervall beendet',
    _ => null,
  };
}

/// Gibt die Signale des Intervall-Timers aus.
abstract class Signals {
  void handle(IntervalEvent event, TargetKind kind);
  void dispose();
}

class SilentSignals implements Signals {
  const SilentSignals();

  @override
  void handle(IntervalEvent event, TargetKind kind) {}

  @override
  void dispose() {}
}

/// Töne, Vibration und Sprachansage über das Gerät.
class DeviceSignals implements Signals {
  DeviceSignals(this.settings) {
    if (settings.tone) {
      // Musik anderer Apps wird für den Ton kurz leiser, läuft aber weiter.
      AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build(),
      );
    }
    if (settings.voice) {
      _tts.setLanguage('de-DE');
    }
  }

  final SignalSettings settings;
  final Map<String, AudioPlayer> _players = {};
  final FlutterTts _tts = FlutterTts();

  @override
  void handle(IntervalEvent event, TargetKind kind) {
    switch (event) {
      case StepEnding(:final secondsLeft) when secondsLeft <= 3:
        _play('warn');
      case StepStarted():
        _play('change');
        _vibrate();
      case IntervalFinished():
        _play('finish');
        _vibrate();
      case StepEnding():
        break;
    }
    final text = announcement(event, kind);
    if (text != null && settings.voice) _tts.speak(text);
  }

  void _play(String sound) {
    if (!settings.tone) return;
    // Ein Spieler je Ton, damit kurz aufeinanderfolgende Töne sich nicht
    // gegenseitig abschneiden.
    final player = _players[sound] ??= AudioPlayer();
    player.play(AssetSource('sounds/$sound.wav'));
  }

  void _vibrate() {
    if (settings.vibration) HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _tts.stop();
  }
}
