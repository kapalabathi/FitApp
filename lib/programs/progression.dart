import '../data/models.dart';

/// Was nach dem letzten Training einer Übung als Nächstes dran ist.
enum Progression {
  none(''),

  /// Ohne Gewicht: weiter zur schwereren Variante.
  harder('3 × 12 sauber geschafft: Zeit für die schwerere Variante'),

  /// Mit Gewicht: dieselbe Übung, etwas mehr Gewicht.
  moreWeight('3 × 12 sauber geschafft: Zeit für etwas mehr Gewicht');

  const Progression(this.label);

  final String label;
}

/// So viele Sätze mit mindestens [progressionReps] Wiederholungen braucht
/// es im letzten Training einer Übung.
const progressionSets = 3;
const progressionReps = 12;

/// Prüft das letzte Training in [history] (neueste Sätze zuerst, wie
/// `exerciseHistory` sie liefert). Die Regel: Wer 3 Sätze mit je mindestens
/// 12 Wiederholungen schafft, ist bereit für die nächste Stufe.
Progression progressionAfter(List<SetLog> history, {required bool hasHarder}) {
  if (history.isEmpty) return Progression.none;
  final last = history.first.performedAt;
  final sets = [
    for (final s in history)
      if (s.performedAt == last && s.reps != null) s,
  ];
  final strong = sets.where((s) => s.reps! >= progressionReps).toList();
  if (strong.length < progressionSets) return Progression.none;
  if (strong.any((s) => s.weightKg != null && s.weightKg! > 0)) {
    return Progression.moreWeight;
  }
  return hasHarder ? Progression.harder : Progression.none;
}
