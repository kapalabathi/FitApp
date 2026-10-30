import 'rep_counter.dart';

/// Ein Abschnitt: eine Übung mit fester Wiederholungszahl.
class HeroBlock {
  const HeroBlock(this.label, this.exerciseKey, this.reps, this.kind);

  final String label;

  /// Dateiname der Grafik der Übung, zugleich ihre Kennung.
  final String exerciseKey;
  final int reps;
  final RepKind kind;

  String get exerciseUuid => 'builtin-$exerciseKey';
}

/// Ein Workout, das auf Zeit durchgeturnt wird und bei dem die Kamera zählt.
class HeroWorkout {
  const HeroWorkout({
    required this.name,
    required this.description,
    required this.equipment,
    required this.blocks,
  });

  final String name;
  final String description;
  final String equipment;
  final List<HeroBlock> blocks;

  /// Unter diesem Titel steht es im Verlauf; so findet sich die Bestzeit.
  String get title => 'Hero: $name';
  String get abortedTitle => '$title (abgebrochen)';

  int get totalReps => blocks.fold(0, (sum, b) => sum + b.reps);
}

const _pullUp = ('Klimmzüge', 'cali_05_klimmzug', RepKind.pullUp);
const _pushUp = ('Liegestütze', 'cali_01_liegestuetz', RepKind.pushUp);
const _squat = ('Kniebeugen', 'crossfit_01_air_squat', RepKind.squat);
const _pike = ('Pike-Liegestütze', 'cali_04_pike_pushup', RepKind.pikePushUp);
const _dip = ('Bank-Dips', 'cali_09_bank_dips', RepKind.benchDip);
const _burpee = ('Burpees', 'crossfit_02_burpee', RepKind.burpee);

HeroBlock _b((String, String, RepKind) e, int reps) =>
    HeroBlock(e.$1, e.$2, reps, e.$3);

/// Die mitgelieferten Workouts, auf Klimmzugstange und Körpergewicht
/// zugeschnitten: ohne Weste, Ringe und Laufstrecken.
final List<HeroWorkout> heroWorkouts = [
  HeroWorkout(
    name: 'Murph, halbiert',
    description: '10 Runden aus 5 Klimmzügen, 10 Liegestützen und 15 '
        'Kniebeugen. Halbe Menge des Originals, ohne die beiden Läufe und '
        'ohne Gewichtsweste.',
    equipment: 'Klimmzugstange',
    blocks: [
      for (var i = 0; i < 10; i++) ...[
        _b(_pullUp, 5),
        _b(_pushUp, 10),
        _b(_squat, 15),
      ],
    ],
  ),
  HeroWorkout(
    name: 'JT, skaliert',
    description: '21-15-9 aus Pike-Liegestützen, Bank-Dips und Liegestützen. '
        'Im Original Handstand-Liegestütze und Ring-Dips.',
    equipment: 'Bank oder stabiler Stuhl',
    blocks: [
      for (final reps in const [21, 15, 9]) ...[
        _b(_pike, reps),
        _b(_dip, reps),
        _b(_pushUp, reps),
      ],
    ],
  ),
  HeroWorkout(
    name: 'Ryan, skaliert',
    description: '5 Runden aus 7 Klimmzügen und 21 Burpees. Im Original '
        'Muscle-ups statt Klimmzüge.',
    equipment: 'Klimmzugstange',
    blocks: [
      for (var i = 0; i < 5; i++) ...[
        _b(_pullUp, 7),
        _b(_burpee, 21),
      ],
    ],
  ),
  HeroWorkout(
    name: 'Jason, skaliert',
    description: 'Kniebeugen 100, 75, 50, 25 im Wechsel mit 5, 10, 15, 20 '
        'Klimmzügen. Im Original Muscle-ups statt Klimmzüge.',
    equipment: 'Klimmzugstange',
    blocks: [
      _b(_squat, 100),
      _b(_pullUp, 5),
      _b(_squat, 75),
      _b(_pullUp, 10),
      _b(_squat, 50),
      _b(_pullUp, 15),
      _b(_squat, 25),
      _b(_pullUp, 20),
    ],
  ),
];

/// Was eine Änderung des Zählers bewirkt hat.
enum HeroChange { counted, blockDone, finished }

/// Ein abgeschlossener Abschnitt mit seiner Dauer.
class HeroSplit {
  const HeroSplit(this.block, this.reps, this.seconds, this.endT);

  final HeroBlock block;

  /// Tatsächlich gezählt; beim Überspringen weniger als geplant.
  final int reps;
  final int seconds;
  final int endT;
}

/// Führt durch ein Workout: zählt, schaltet weiter, misst die Abschnitte.
///
/// Kennt weder Kamera noch Uhr; [elapsedS] kommt jeweils von außen.
class HeroRun {
  HeroRun(this.workout);

  final HeroWorkout workout;
  final List<HeroSplit> splits = [];

  int _index = 0;
  int _startT = 0;

  /// Wiederholungen im laufenden Abschnitt.
  int count = 0;

  bool get finished => _index >= workout.blocks.length;
  HeroBlock? get current => finished ? null : workout.blocks[_index];
  int get blockNumber => _index + 1;
  int get blockTotal => workout.blocks.length;

  /// Anteil der geschafften Wiederholungen, 0 bis 1.
  double get progress {
    final done = splits.fold(0, (sum, s) => sum + s.block.reps) + count;
    return workout.totalReps == 0 ? 1 : done / workout.totalReps;
  }

  /// Eine Wiederholung ist vollendet.
  HeroChange? addRep(int elapsedS) {
    final block = current;
    if (block == null) return null;
    count++;
    return count >= block.reps ? _closeBlock(elapsedS) : HeroChange.counted;
  }

  /// Nimmt eine zu viel gezählte Wiederholung zurück.
  void removeRep() {
    if (count > 0) count--;
  }

  /// Schließt den Abschnitt ab, wenn die Kamera nicht alles gezählt hat.
  HeroChange? skipBlock(int elapsedS) =>
      finished ? null : _closeBlock(elapsedS);

  HeroChange _closeBlock(int elapsedS) {
    splits.add(
        HeroSplit(current!, count, elapsedS - _startT, elapsedS));
    _startT = elapsedS;
    count = 0;
    _index++;
    return finished ? HeroChange.finished : HeroChange.blockDone;
  }
}
