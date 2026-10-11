import 'package:flutter/material.dart';

import '../programs/program_models.dart';

/// Zeigt die Körperbereiche, die eine Übung oder ein Programm trainiert,
/// als kleine Marken.
class AreaChips extends StatelessWidget {
  const AreaChips({super.key, required this.areas, this.centered = false});

  final List<BodyArea> areas;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final area in areas)
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                area.label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
          ),
      ],
    );
  }
}

/// Die Körperbereiche eines Programms, die am häufigsten vorkommenden zuerst.
List<BodyArea> programAreas(Program program, Map<String, Exercise> exercises) {
  final counts = <BodyArea, int>{};
  for (final item in program.items) {
    for (final area in exercises[item.exerciseUuid]?.areas ?? const <BodyArea>[]) {
      counts[area] = (counts[area] ?? 0) + 1;
    }
  }
  return counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.index.compareTo(b.index);
    });
}
