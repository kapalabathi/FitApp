import 'rep_counter.dart';

/// Ein Abschnitt: eine Übung mit fester Wiederholungszahl oder ein Lauf.
class HeroBlock {
  const HeroBlock(this.label, String this.exerciseKey, this.reps, this.kind)
      : meters = null;

  /// Ein Lauf endet von selbst mit der ersten Wiederholung der nächsten
  /// Übung oder von Hand.
  const HeroBlock.run(int this.meters, {this.label = 'Lauf'})
      : exerciseKey = null,
        reps = 0,
        kind = null;

  final String label;

  /// Dateiname der Grafik der Übung, zugleich ihre Kennung; `null` beim Lauf.
  final String? exerciseKey;
  final int reps;

  /// Wie die Kamera zählt; `null`, wenn nur von Hand gezählt werden kann.
  final RepKind? kind;

  /// Die Strecke eines Laufs in Metern.
  final int? meters;

  bool get isRun => meters != null;

  String get exerciseUuid => 'builtin-$exerciseKey';

  /// Der Abschnitt für die Anzeige, etwa „Lauf 1,6 km".
  String get title {
    final m = meters;
    if (m == null) return label;
    final distance = m >= 1000
        ? '${(m / 1000).toString().replaceAll('.', ',')} km'
        : '$m m';
    return '$label $distance';
  }
}

/// Zu welcher Familie von Benchmarks ein Workout gehört.
enum HeroFamily {
  hero('Hero'),
  girl('Girl');

  const HeroFamily(this.label);

  final String label;
}

/// Ein Workout, das auf Zeit durchgeturnt wird und bei dem die Kamera zählt.
class HeroWorkout {
  const HeroWorkout({
    required this.name,
    required this.description,
    required this.equipment,
    required this.blocks,
    this.family = HeroFamily.hero,
  });

  final String name;
  final String description;
  final String equipment;
  final List<HeroBlock> blocks;
  final HeroFamily family;

  /// Unter diesem Titel steht es im Verlauf; so findet sich die Bestzeit.
  String get title => '${family.label}: $name';
  String get abortedTitle => '$title (abgebrochen)';

  int get totalReps => blocks.fold(0, (sum, b) => sum + b.reps);
  int get runMeters => blocks.fold(0, (sum, b) => sum + (b.meters ?? 0));
}

const _pullUp = ('Klimmzüge', 'cali_05_klimmzug', RepKind.pullUp);
const _pushUp = ('Liegestütze', 'cali_01_liegestuetz', RepKind.pushUp);
const _squat = ('Kniebeugen', 'crossfit_01_air_squat', RepKind.squat);
const _pike = ('Pike-Liegestütze', 'cali_04_pike_pushup', RepKind.pikePushUp);
const _dip = ('Bank-Dips', 'cali_09_bank_dips', RepKind.benchDip);
const _burpee = ('Burpees', 'crossfit_02_burpee', RepKind.burpee);
const _sitUp = ('Sit-ups', 'crossfit_14_situp', RepKind.sitUp);
const _jump = ('Sprungkniebeugen', 'crossfit_21_strecksprung', RepKind.squat);
const _superman = ('Superman', 'cali_17_superman', null);

HeroBlock _b((String, String, RepKind?) e, int reps) =>
    HeroBlock(e.$1, e.$2, reps, e.$3);

const _stange = 'Klimmzugstange, Laufstrecke oder Laufband';
const _lauf = 'Laufstrecke oder Laufband';

List<HeroBlock> _murph(int run, int pullUps, int pushUps, int squats) => [
      HeroBlock.run(run),
      _b(_pullUp, pullUps),
      _b(_pushUp, pushUps),
      _b(_squat, squats),
      HeroBlock.run(run),
    ];

List<HeroBlock> _michael(int rounds, int run, int reps) => [
      for (var i = 0; i < rounds; i++) ...[
        HeroBlock.run(run),
        _b(_superman, reps),
        _b(_sitUp, reps),
      ],
    ];

List<HeroBlock> _griff(int forward, int backward) => [
      for (var i = 0; i < 2; i++) ...[
        HeroBlock.run(forward),
        HeroBlock.run(backward, label: 'Rückwärts'),
      ],
    ];

/// Runden aus einem Lauf und zwei Übungen.
List<HeroBlock> _rounds(int rounds, int run, HeroBlock first, [HeroBlock? second]) =>
    [
      for (var i = 0; i < rounds; i++) ...[
        HeroBlock.run(run),
        first,
        ?second,
      ],
    ];

/// Die mitgelieferten Workouts, auf Klimmzugstange und Körpergewicht
/// zugeschnitten. Angepasste Fassungen tragen das im Namen.
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
    name: 'Murph',
    description: '1,6 km Lauf, 100 Klimmzüge, 200 Liegestütze, 300 Kniebeugen, '
        '1,6 km Lauf, der Reihe nach. Das Original läuft mit 9-kg-Weste; '
        'hier ohne.',
    equipment: _stange,
    blocks: _murph(1600, 100, 200, 300),
  ),
  HeroWorkout(
    name: 'Murph, halbe Menge mit Lauf',
    description: '800 m Lauf, 50 Klimmzüge, 100 Liegestütze, 150 Kniebeugen, '
        '800 m Lauf.',
    equipment: _stange,
    blocks: _murph(800, 50, 100, 150),
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
  HeroWorkout(
    name: 'Michael',
    description: '3 Runden aus 800 m Lauf, 50 Superman und 50 Sit-ups. Im '
        'Original Rückenstrecker statt Superman. Superman zählst du von Hand.',
    equipment: _lauf,
    blocks: _michael(3, 800, 50),
  ),
  HeroWorkout(
    name: 'Michael, kurz',
    description: '3 Runden aus 400 m Lauf, 25 Superman und 25 Sit-ups. '
        'Superman zählst du von Hand.',
    equipment: _lauf,
    blocks: _michael(3, 400, 25),
  ),
  HeroWorkout(
    name: 'Griff',
    description: '800 m Lauf, 400 m rückwärts, 800 m Lauf, 400 m rückwärts. '
        'Reine Laufzeiten: Jeden Abschnitt schließt du von Hand ab.',
    equipment: _lauf,
    blocks: _griff(800, 400),
  ),
  HeroWorkout(
    name: 'Griff, kurz',
    description: '400 m Lauf, 200 m rückwärts, 400 m Lauf, 200 m rückwärts.',
    equipment: _lauf,
    blocks: _griff(400, 200),
  ),
  HeroWorkout(
    name: 'Helen, skaliert',
    family: HeroFamily.girl,
    description: '3 Runden aus 400 m Lauf, 21 Sprungkniebeugen und 12 '
        'Klimmzügen. Im Original Kettlebell Swings statt Sprungkniebeugen.',
    equipment: _stange,
    blocks: _rounds(3, 400, _b(_jump, 21), _b(_pullUp, 12)),
  ),
  HeroWorkout(
    name: 'Helen, kurz',
    family: HeroFamily.girl,
    description: '3 Runden aus 200 m Lauf, 12 Sprungkniebeugen und 6 '
        'Klimmzügen.',
    equipment: _stange,
    blocks: _rounds(3, 200, _b(_jump, 12), _b(_pullUp, 6)),
  ),
  HeroWorkout(
    name: 'Eva, skaliert',
    family: HeroFamily.girl,
    description: '5 Runden aus 800 m Lauf, 30 Sprungkniebeugen und 30 '
        'Klimmzügen. Im Original Kettlebell Swings.',
    equipment: _stange,
    blocks: _rounds(5, 800, _b(_jump, 30), _b(_pullUp, 30)),
  ),
  HeroWorkout(
    name: 'Eva, kurz',
    family: HeroFamily.girl,
    description: '3 Runden aus 400 m Lauf, 15 Sprungkniebeugen und 10 '
        'Klimmzügen.',
    equipment: _stange,
    blocks: _rounds(3, 400, _b(_jump, 15), _b(_pullUp, 10)),
  ),
  HeroWorkout(
    name: 'Kelly, skaliert',
    family: HeroFamily.girl,
    description: '5 Runden aus 400 m Lauf, 30 Sprungkniebeugen und 30 '
        'Kniebeugen. Im Original Box Jumps und Wall Balls.',
    equipment: _lauf,
    blocks: _rounds(5, 400, _b(_jump, 30), _b(_squat, 30)),
  ),
  HeroWorkout(
    name: 'Kelly, kurz',
    family: HeroFamily.girl,
    description: '3 Runden aus 400 m Lauf, 15 Sprungkniebeugen und 15 '
        'Kniebeugen.',
    equipment: _lauf,
    blocks: _rounds(3, 400, _b(_jump, 15), _b(_squat, 15)),
  ),
  HeroWorkout(
    name: 'Nancy, skaliert',
    family: HeroFamily.girl,
    description: '5 Runden aus 400 m Lauf und 15 Kniebeugen. Im Original '
        'Overhead Squats mit 43 kg.',
    equipment: _lauf,
    blocks: _rounds(5, 400, _b(_squat, 15)),
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
/// Ein Lauf hat keinen eigenen Zähler. Er endet, sobald die nächste Übung ihre
/// erste Wiederholung meldet; der Lauf ist also die Zeit bis dahin. Ein Lauf,
/// nach dem keine zählbare Übung kommt, endet von Hand.
///
/// Kennt weder Kamera noch Uhr; [elapsedS] kommt jeweils von außen.
class HeroRun {
  HeroRun(this.workout);

  /// So lange zählt am Anfang eines Laufs keine Wiederholung. Wer an der
  /// Kamera vorbeiläuft, beendet den Lauf damit nicht versehentlich.
  static const minRunS = 30;

  final HeroWorkout workout;
  final List<HeroSplit> splits = [];

  int _index = 0;
  int _startT = 0;

  /// Wiederholungen im laufenden Abschnitt.
  int count = 0;

  bool get finished => _index >= workout.blocks.length;
  HeroBlock? get current => finished ? null : workout.blocks[_index];
  HeroBlock? get _next =>
      _index + 1 < workout.blocks.length ? workout.blocks[_index + 1] : null;
  int get blockNumber => _index + 1;
  int get blockTotal => workout.blocks.length;

  /// Die Übung, auf die die Kamera gerade achtet: im Lauf schon die nächste.
  RepKind? get countingKind {
    final block = current;
    if (block == null) return null;
    return block.isRun ? _next?.kind : block.kind;
  }

  /// Sekunden im laufenden Abschnitt.
  int blockSeconds(int elapsedS) => elapsedS - _startT;

  /// Anteil der geschafften Abschnitte, 0 bis 1.
  double get progress {
    final block = current;
    if (block == null) return 1;
    final inBlock = block.reps == 0 ? 0.0 : count / block.reps;
    return (_index + inBlock) / workout.blocks.length;
  }

  /// Die Kamera meldet eine vollendete Wiederholung.
  HeroChange? addRep(int elapsedS) {
    final block = current;
    if (block == null) return null;
    if (!block.isRun) return _countRep(block, elapsedS);
    // Die erste Wiederholung der nächsten Übung beendet den Lauf.
    if (_next?.kind == null || blockSeconds(elapsedS) < minRunS) return null;
    _closeBlock(elapsedS);
    final change = _countRep(current!, elapsedS);
    return change == HeroChange.counted ? HeroChange.blockDone : change;
  }

  /// Eine Wiederholung von Hand; im Lauf gibt es keine.
  HeroChange? addManualRep(int elapsedS) {
    final block = current;
    if (block == null || block.isRun) return null;
    return _countRep(block, elapsedS);
  }

  HeroChange _countRep(HeroBlock block, int elapsedS) {
    count++;
    return count >= block.reps ? _closeBlock(elapsedS) : HeroChange.counted;
  }

  /// Nimmt eine zu viel gezählte Wiederholung zurück.
  void removeRep() {
    if (count > 0) count--;
  }

  /// Schließt den Abschnitt von Hand ab, etwa den letzten Lauf.
  HeroChange? skipBlock(int elapsedS) =>
      finished ? null : _closeBlock(elapsedS);

  HeroChange _closeBlock(int elapsedS) {
    splits.add(HeroSplit(current!, count, elapsedS - _startT, elapsedS));
    _startT = elapsedS;
    count = 0;
    _index++;
    return finished ? HeroChange.finished : HeroChange.blockDone;
  }
}
