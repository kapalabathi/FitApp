import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'geo.dart';

/// Das GPS des Phones als Quelle für Standorte.
abstract final class PhoneGps {
  /// Prüft Standortdienst und Berechtigung und fragt sie bei Bedarf an.
  /// Gibt `null` zurück, wenn aufgezeichnet werden kann, sonst den Grund,
  /// warum nicht.
  static Future<String?> prepare() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Der Standortdienst des Geräts ist ausgeschaltet.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.whileInUse || LocationPermission.always => null,
      LocationPermission.deniedForever =>
        'Die Standort-Berechtigung wurde dauerhaft abgelehnt. Sie lässt sich '
            'in den Android-Einstellungen der App wieder erteilen.',
      _ => 'Ohne Standort-Berechtigung kann die Strecke nicht aufgezeichnet '
          'werden.',
    };
  }

  /// Liefert etwa jede Sekunde einen Standort, auch bei ausgeschaltetem
  /// Display und wenn die App im Hintergrund ist (Lastenheft A-022).
  static Stream<GpsFix> positions() {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            intervalDuration: const Duration(seconds: 1),
            // Die dauerhafte Benachrichtigung hält die Aufzeichnung am Leben,
            // wenn Android die App sonst schlafen legen würde.
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'FitApp zeichnet auf',
              notificationText: 'Die Strecke wird per GPS aufgezeichnet.',
              notificationChannelName: 'Aufzeichnung',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.best);
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => GpsFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyM: p.accuracy,
        altitudeM: p.hasAltitude ? p.altitude : null,
        speedMps: p.hasSpeed ? p.speed : null,
        speedAccuracyMps: p.hasSpeedAccuracy ? p.speedAccuracy : null,
      ),
    );
  }
}
