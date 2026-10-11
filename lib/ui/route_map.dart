import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Die aufgezeichnete Strecke auf einer OpenStreetMap-Karte.
///
/// Die Kartenkacheln kommen aus dem Internet; ohne Verbindung bleibt der
/// Hintergrund leer und nur die Linie der Strecke ist zu sehen.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.points});

  /// Mindestens zwei Punkte.
  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(32),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.kapalabathi.fitapp',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: points, strokeWidth: 4, color: scheme.primary),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  child: const Icon(Icons.trip_origin, color: Colors.green),
                ),
                Marker(
                  point: points.last,
                  child: Icon(Icons.flag, color: scheme.error),
                ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap-Mitwirkende'),
            ),
          ],
        ),
      ),
    );
  }
}
