import '../data/database.dart';
import '../data/models.dart';

/// Die Kacheln der Trainingsansicht. [id] steht in den Einstellungen.
enum LiveTileKind {
  time('time', 'Zeit'),
  heartRate('heartRate', 'Puls'),
  distance('distance', 'Distanz'),
  pace('pace', 'Pace bzw. Geschwindigkeit'),
  power('power', 'Leistung'),
  cadence('cadence', 'Tritt-, Schritt- oder Schlagfrequenz'),
  incline('incline', 'Steigung'),
  resistance('resistance', 'Widerstand'),
  energy('energy', 'Energie'),
  ascent('ascent', 'Anstieg'),
  lap('lap', 'Laufende Runde');

  const LiveTileKind(this.id, this.label);

  final String id;
  final String label;
}

/// Welche Kacheln die Trainingsansicht einer Sportart zeigt und in welcher
/// Reihenfolge, dazu ob die Live-Kurve erscheint.
///
/// Eine Kachel erscheint nur, wenn es ihren Wert im Training auch gibt; die
/// Auswahl hier kann sie zusätzlich ausblenden.
class TileLayout {
  const TileLayout({
    this.order = LiveTileKind.values,
    this.hidden = const {},
    this.showChart = true,
  });

  /// Liest die gespeicherte Anordnung. Kacheln, die es beim Speichern noch
  /// nicht gab, stehen sichtbar am Ende.
  factory TileLayout.parse(String? stored, {bool showChart = true}) {
    final order = <LiveTileKind>[];
    final hidden = <LiveTileKind>{};
    for (var id in (stored ?? '').split(',')) {
      final off = id.startsWith('-');
      if (off) id = id.substring(1);
      for (final kind in LiveTileKind.values) {
        if (kind.id == id && !order.contains(kind)) {
          order.add(kind);
          if (off) hidden.add(kind);
        }
      }
    }
    for (final kind in LiveTileKind.values) {
      if (!order.contains(kind)) order.add(kind);
    }
    return TileLayout(order: order, hidden: hidden, showChart: showChart);
  }

  factory TileLayout.load(AppDatabase db, Sport sport) => TileLayout.parse(
        db.setting(_key(sport)),
        showChart: db.flag(_chartKey(sport), fallback: true),
      );

  static String _key(Sport sport) => 'tiles.${sport.id}';
  static String _chartKey(Sport sport) => 'tiles.${sport.id}.chart';

  final List<LiveTileKind> order;
  final Set<LiveTileKind> hidden;

  /// Ob über den Kacheln die Kurve von Puls und Pace mitläuft.
  final bool showChart;

  /// Die sichtbaren Kacheln in ihrer Reihenfolge.
  Iterable<LiveTileKind> get visible => order.where((k) => !hidden.contains(k));

  /// Die Anordnung als Text: Kennungen mit Komma getrennt, ausgeblendete mit
  /// vorangestelltem Minus.
  String get stored =>
      order.map((k) => hidden.contains(k) ? '-${k.id}' : k.id).join(',');

  TileLayout copyWith({
    List<LiveTileKind>? order,
    Set<LiveTileKind>? hidden,
    bool? showChart,
  }) =>
      TileLayout(
        order: order ?? this.order,
        hidden: hidden ?? this.hidden,
        showChart: showChart ?? this.showChart,
      );

  void save(AppDatabase db, Sport sport) {
    db
      ..setSetting(_key(sport), stored)
      ..setFlag(_chartKey(sport), showChart);
  }
}
