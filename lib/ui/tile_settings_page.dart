import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../session/tile_layout.dart';

/// Legt fest, welche Kacheln die Trainingsansicht einer Sportart zeigt und
/// in welcher Reihenfolge. Jede Änderung wird sofort gespeichert.
class TileSettingsPage extends StatefulWidget {
  const TileSettingsPage({super.key, required this.db, required this.sport});

  final AppDatabase db;
  final Sport sport;

  @override
  State<TileSettingsPage> createState() => _TileSettingsPageState();
}

class _TileSettingsPageState extends State<TileSettingsPage> {
  late TileLayout _layout = TileLayout.load(widget.db, widget.sport);

  void _change(TileLayout layout) {
    layout.save(widget.db, widget.sport);
    setState(() => _layout = layout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Anzeige: ${widget.sport.label}')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Live-Kurve'),
            subtitle: const Text('Puls und Pace der letzten Minuten'),
            value: _layout.showChart,
            onChanged: (v) => _change(_layout.copyWith(showChart: v)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Kacheln: Schalter blendet aus, Ziehen am Griff ordnet um. Eine '
              'Kachel erscheint nur, wenn es ihren Wert im Training gibt.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _layout.order.length,
              onReorderItem: (from, to) {
                final order = [..._layout.order];
                order.insert(to, order.removeAt(from));
                _change(_layout.copyWith(order: order));
              },
              itemBuilder: (context, i) {
                final kind = _layout.order[i];
                return SwitchListTile(
                  key: ValueKey(kind),
                  // Platz für den Griff zum Verschieben am rechten Rand
                  contentPadding: const EdgeInsets.only(left: 16, right: 48),
                  title: Text(kind.label),
                  value: !_layout.hidden.contains(kind),
                  onChanged: (on) => _change(_layout.copyWith(hidden: {
                    for (final k in _layout.hidden)
                      if (k != kind) k,
                    if (!on) kind,
                  })),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
