import 'dart:math';

/// Ein Standort vom GPS des Phones.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    this.altitudeM,
    this.speedMps,
    this.speedAccuracyMps,
  });

  final double latitude;
  final double longitude;

  /// Geschätzter Fehler der Position in Metern; kleiner ist besser.
  final double accuracyM;
  final double? altitudeM;

  /// Vom GPS gemessene Geschwindigkeit, falls es eine liefert.
  final double? speedMps;

  /// Geschätzter Fehler von [speedMps], falls das GPS ihn angibt.
  final double? speedAccuracyMps;
}

/// Entfernung zweier Punkte auf der Erdoberfläche in Metern (Haversine).
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusM = 6371000.0;
  double rad(double deg) => deg * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
}
