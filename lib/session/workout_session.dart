import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/device_kind.dart';
import '../ble/sensor_connection.dart';
import '../data/database.dart';
import '../data/models.dart';
import 'workout_recorder.dart';

/// Ein laufendes Training: verbindet die gewählten Geräte, treibt die
/// Aufzeichnung im Sekundentakt und hält den Bildschirm an.
class WorkoutSession extends ChangeNotifier {
  WorkoutSession({
    required AppDatabase db,
    required Sport sport,
    required List<SavedDevice> devices,
  }) : recorder = WorkoutRecorder(db: db, sport: sport) {
    for (final device in devices) {
      recorder.addSource(
        device.deviceId,
        dedicatedHeartRate: device.kind == DeviceKind.heartRate,
      );
      final connection = SensorConnection(device, onData: _onData)
        ..addListener(notifyListeners);
      connections.add(connection);
      connection.start();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      recorder.tick();
      notifyListeners();
    });
    WakelockPlus.enable();
  }

  final WorkoutRecorder recorder;
  final List<SensorConnection> connections = [];
  late final Timer _timer;

  Sport get sport => recorder.sport;

  void _onData(SavedDevice device, Map<Metric, double> values) {
    recorder.onData(device.deviceId, values);
  }

  void togglePause() {
    recorder.paused ? recorder.resume() : recorder.pause();
    notifyListeners();
  }

  void preferHeartRateFrom(String deviceId) {
    recorder.preferredHeartRateSource = deviceId;
    notifyListeners();
  }

  /// Beendet das Training und trennt die Geräte. Gibt das gespeicherte
  /// Training zurück oder `null`, wenn nichts aufgezeichnet wurde.
  Future<Workout?> finish() async {
    _timer.cancel();
    final workout = recorder.finish();
    await WakelockPlus.disable();
    for (final c in connections) {
      c.removeListener(notifyListeners);
      await c.stop();
    }
    return workout;
  }
}
