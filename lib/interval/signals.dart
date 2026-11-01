import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../platform/app_platform.dart';
import 'interval_models.dart';
import 'interval_run.dart';
import 'speaker.dart';

/// Welche Signale die App im Training gibt. Wird in der Datenbank gemerkt.
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

/// Die Signale, die Timer, Programme und Rundenansagen auslösen.
abstract class Signals {
  /// Kurzer Ton: gleich wechselt etwas.
  void warn();

  /// Langer Ton und Vibration: ein neuer Abschnitt beginnt.
  void change();

  /// Tonfolge und Vibration: der Ablauf ist zu Ende.
  void finish();

  /// Sprachansage.
  void say(String text);

  void dispose();
}

/// Der gesprochene Text zu einem Intervall-Ereignis, oder `null`, wenn
/// nichts zu sagen ist.
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

/// Gibt die Signale zu einem Intervall-Ereignis aus.
void signalInterval(Signals signals, IntervalEvent event, TargetKind kind) {
  switch (event) {
    case StepEnding(:final secondsLeft) when secondsLeft <= 3:
      signals.warn();
    case StepStarted():
      signals.change();
    case IntervalFinished():
      signals.finish();
    case StepEnding():
      break;
  }
  final text = announcement(event, kind);
  if (text != null) signals.say(text);
}

class SilentSignals implements Signals {
  const SilentSignals();

  @override
  void warn() {}

  @override
  void change() {}

  @override
  void finish() {}

  @override
  void say(String text) {}

  @override
  void dispose() {}
}

/// Erzeugt die Signale für ein Training. Tests setzen hier stumme Signale
/// ein, weil es dort weder Lautsprecher noch Sprachausgabe gibt.
Signals Function(SignalSettings settings) createSignals = DeviceSignals.new;

/// Töne, Vibration und Sprachansage über das Gerät.
class DeviceSignals implements Signals {
  DeviceSignals(this.settings) {
    if (settings.tone && !AppPlatform.isDesktop) {
      // Musik anderer Apps wird für den Ton kurz leiser, läuft aber weiter.
      AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build(),
      );
    }
  }

  final SignalSettings settings;
  final Map<String, AudioPlayer> _players = {};
  late final Speaker _speaker = Speaker.forDevice();

  @override
  void warn() => _play('warn');

  @override
  void change() {
    _play('change');
    _vibrate();
  }

  @override
  void finish() {
    _play('finish');
    _vibrate();
  }

  @override
  void say(String text) {
    if (settings.voice) _speaker.say(text);
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
    if (settings.voice) _speaker.stop();
  }
}
