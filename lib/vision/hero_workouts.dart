import 'rep_counter.dart';

/// Ein Abschnitt: eine Übung mit fester Wiederholungszahl oder ein Lauf.
class HeroBlock {
  const HeroBlock(this.label, this.exerciseKey, this.reps, this.kind)
    : meters = null,
      restS = null,
      isMax = false;

  /// So viele Wiederholungen wie möglich; endet von Hand.
  const HeroBlock.max(this.label, this.exerciseKey, this.kind)
    : reps = 0,
      meters = null,
      restS = null,
      isMax = true;

  /// Ein Lauf endet von selbst mit der ersten Wiederholung der nächsten
  /// Übung oder von Hand.
  const HeroBlock.run(int this.meters, {this.label = 'Lauf'})
    : exerciseKey = null,
      reps = 0,
      kind = null,
      restS = null,
      isMax = false;

  /// Eine feste Pause, die von selbst endet.
  const HeroBlock.rest(int this.restS)
    : label = 'Pause',
      exerciseKey = null,
      reps = 0,
      kind = null,
      meters = null,
      isMax = false;

  final String label;

  /// Dateiname der Grafik der Übung, zugleich ihre Kennung; `null`, wenn die
  /// App die Übung nicht kennt, und bei Lauf oder Pause.
  final String? exerciseKey;
  final int reps;

  /// Wie die Kamera zählt; `null`, wenn nur von Hand gezählt werden kann.
  final RepKind? kind;

  /// Die Strecke eines Laufs in Metern.
  final int? meters;

  /// Die Dauer einer Pause in Sekunden.
  final int? restS;

  bool get isRun => meters != null;
  bool get isRest => restS != null;

  /// Zählt so viele Wiederholungen wie möglich statt einer festen Menge.
  final bool isMax;

  /// Hat Wiederholungen, die sich zählen lassen.
  bool get counted => reps > 0 || isMax;

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

/// Wie ein Workout läuft und was es wertet.
enum HeroFormat {
  /// Feste Menge, gewertet wird die Zeit.
  forTime('Auf Zeit'),

  /// Feste Zeit, so viele Runden wie möglich.
  amrap('So viel wie möglich'),

  /// Jede Minute eine Runde, bis eine nicht mehr gelingt.
  emom('Jede Minute'),

  /// Feste Serien, jede bis zum Maximum.
  maxReps('Maximalwerte');

  const HeroFormat(this.label);

  final String label;
}

/// Ein Workout, bei dem die Kamera zählt.
class HeroWorkout {
  const HeroWorkout({
    required this.name,
    required this.description,
    required this.equipment,
    required this.blocks,
    this.family = HeroFamily.hero,
    this.deviations = const [],
    this.format = HeroFormat.forTime,
    this.capS,
  });

  final HeroFormat format;

  /// Die feste Zeit des Workouts in Sekunden, sonst `null`.
  final int? capS;

  /// Das Format mit Dauer für die Anzeige.
  String get formatLabel =>
      capS == null ? format.label : '${format.label}, ${capS! ~/ 60} min';

  final String name;
  final String description;
  final String equipment;
  final List<HeroBlock> blocks;
  final HeroFamily family;

  /// Jede Abweichung vom Original; leer beim Original selbst.
  final List<String> deviations;

  bool get isOriginal => deviations.isEmpty;

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

// Übungen der Originale. Wo die App keine Übung oder keinen Zähler hat, wird
// von Hand gezählt.
const _muscleUp = ('Muscle-ups', null, null);
const _hspu = ('Handstand-Liegestütze', null, null);
const _ringDip = ('Ring-Dips', null, null);
const _backExt = ('Rückenstrecker', null, null);
const _doubleUnder = ('Double-Unders', 'crossfit_47_doppelsprung', null);
const _swing24 = (
  'Kettlebell Swings 24 kg',
  'crossfit_04_kettlebell_swing',
  null,
);
const _swing32 = (
  'Kettlebell Swings 32 kg',
  'crossfit_04_kettlebell_swing',
  null,
);
const _boxJump = ('Box Jumps 60 cm', 'crossfit_03_box_jump', null);
const _wallBall = ('Wall Balls 9 kg', 'crossfit_06_wall_ball', RepKind.squat);
const _pistol = ('Pistols', 'cali_15_pistol_squat', RepKind.squat);
const _ohs = ('Overhead Squats 43 kg', null, RepKind.squat);
const _thruster43 = ('Thruster 43 kg', 'crossfit_05_thruster', RepKind.squat);
const _thruster20 = ('Thruster 20 kg', 'crossfit_05_thruster', RepKind.squat);
const _deadlift102 = ('Kreuzheben 102 kg', 'crossfit_08_kreuzheben', null);
const _deadlift70 = ('Kreuzheben 70 kg', 'crossfit_08_kreuzheben', null);
const _hangClean = ('Hang Power Cleans 70 kg', null, null);
const _pushJerk = ('Push Jerks 70 kg', null, null);
const _clean61 = ('Cleans 61 kg', null, null);
const _cleanJerk = ('Clean & Jerks 61 kg', null, null);
const _snatch = ('Snatches 61 kg', null, null);
const _squatSnatch = ('Squat Snatches 61 kg', null, null);
const _lindaDead = (
  'Kreuzheben 1,5 × Körpergewicht',
  'crossfit_08_kreuzheben',
  null,
);
const _lindaBench = ('Bankdrücken 1 × Körpergewicht', null, null);
const _lindaClean = ('Cleans 0,75 × Körpergewicht', null, null);

HeroBlock _b((String, String?, RepKind?) e, int reps) =>
    HeroBlock(e.$1, e.$2, reps, e.$3);

HeroBlock _max((String, String?, RepKind?) e) =>
    HeroBlock.max(e.$1, e.$2, e.$3);

const _stange = 'Klimmzugstange, Laufstrecke oder Laufband';
const _lauf = 'Laufstrecke oder Laufband';
const _hantel = 'Langhantel mit Gewichten';

const _noVest = 'Ohne 9-kg-Weste';

List<HeroBlock> _murph(int run, int pullUps, int pushUps, int squats) => [
  HeroBlock.run(run),
  _b(_pullUp, pullUps),
  _b(_pushUp, pushUps),
  _b(_squat, squats),
  HeroBlock.run(run),
];

List<HeroBlock> _griff(int forward, int backward) => [
  for (var i = 0; i < 2; i++) ...[
    HeroBlock.run(forward),
    HeroBlock.run(backward, label: 'Rückwärts'),
  ],
];

/// Runden aus einem Lauf und ein oder zwei Übungen.
List<HeroBlock> _rounds(
  int rounds,
  int run,
  HeroBlock first, [
  HeroBlock? second,
]) => [
  for (var i = 0; i < rounds; i++) ...[HeroBlock.run(run), first, ?second],
];

/// Runden ohne Lauf.
List<HeroBlock> _repeat(int rounds, List<HeroBlock> blocks) => [
  for (var i = 0; i < rounds; i++) ...blocks,
];

/// Eine Leiter wie 21-15-9 über mehrere Übungen.
List<HeroBlock> _ladder(
  List<int> reps,
  List<(String, String?, RepKind?)> exercises,
) => [
  for (final n in reps)
    for (final e in exercises) _b(e, n),
];

/// Die mitgelieferten Workouts. Ohne [HeroWorkout.deviations] sind es die
/// Originale, sonst steht dort jede Abweichung.
final List<HeroWorkout> heroWorkouts = [
  // --- Hero ---
  HeroWorkout(
    name: 'Murph',
    description:
        '1,6 km Lauf, 100 Klimmzüge, 200 Liegestütze, 300 Kniebeugen, '
        '1,6 km Lauf, alles mit 9-kg-Weste. Die Mitte darf aufgeteilt werden.',
    equipment: '$_stange, 9-kg-Weste',
    blocks: _murph(1600, 100, 200, 300),
  ),
  HeroWorkout(
    name: 'Murph, ohne Weste',
    description:
        '1,6 km Lauf, 100 Klimmzüge, 200 Liegestütze, 300 Kniebeugen, '
        '1,6 km Lauf.',
    equipment: _stange,
    deviations: const [_noVest],
    blocks: _murph(1600, 100, 200, 300),
  ),
  HeroWorkout(
    name: 'Murph, halbe Menge mit Lauf',
    description:
        '800 m Lauf, 50 Klimmzüge, 100 Liegestütze, 150 Kniebeugen, '
        '800 m Lauf.',
    equipment: _stange,
    deviations: const [
      'Läufe 800 m statt 1,6 km',
      '50 statt 100 Klimmzüge',
      '100 statt 200 Liegestütze',
      '150 statt 300 Kniebeugen',
      _noVest,
    ],
    blocks: _murph(800, 50, 100, 150),
  ),
  HeroWorkout(
    name: 'Murph, halbiert',
    description:
        '10 Runden aus 5 Klimmzügen, 10 Liegestützen und 15 '
        'Kniebeugen.',
    equipment: 'Klimmzugstange',
    deviations: const [
      'Beide Läufe entfallen',
      '50 statt 100 Klimmzüge',
      '100 statt 200 Liegestütze',
      '150 statt 300 Kniebeugen',
      'In 10 Runden aufgeteilt statt am Stück',
      _noVest,
    ],
    blocks: _repeat(10, [_b(_pullUp, 5), _b(_pushUp, 10), _b(_squat, 15)]),
  ),
  HeroWorkout(
    name: 'JT',
    description:
        '21-15-9 aus Handstand-Liegestützen, Ring-Dips und '
        'Liegestützen.',
    equipment: 'Wand, Ringe',
    blocks: _ladder(const [21, 15, 9], [_hspu, _ringDip, _pushUp]),
  ),
  HeroWorkout(
    name: 'JT, skaliert',
    description: '21-15-9 aus Pike-Liegestützen, Bank-Dips und Liegestützen.',
    equipment: 'Bank oder stabiler Stuhl',
    deviations: const [
      'Pike-Liegestütze statt Handstand-Liegestütze',
      'Bank-Dips statt Ring-Dips',
    ],
    blocks: _ladder(const [21, 15, 9], [_pike, _dip, _pushUp]),
  ),
  HeroWorkout(
    name: 'Ryan',
    description:
        '5 Runden aus 7 Muscle-ups und 21 Burpees. Beim Burpee zu '
        'einem Ziel 30 cm über der Reichhöhe springen.',
    equipment: 'Klimmzugstange oder Ringe',
    blocks: _repeat(5, [_b(_muscleUp, 7), _b(_burpee, 21)]),
  ),
  HeroWorkout(
    name: 'Ryan, skaliert',
    description: '5 Runden aus 7 Klimmzügen und 21 Burpees.',
    equipment: 'Klimmzugstange',
    deviations: const [
      'Klimmzüge statt Muscle-ups',
      'Burpees ohne Sprungziel über der Reichhöhe',
    ],
    blocks: _repeat(5, [_b(_pullUp, 7), _b(_burpee, 21)]),
  ),
  HeroWorkout(
    name: 'Jason',
    description:
        'Kniebeugen 100, 75, 50, 25 im Wechsel mit 5, 10, 15, 20 '
        'Muscle-ups.',
    equipment: 'Klimmzugstange oder Ringe',
    blocks: [
      for (final (squats, ups) in const [
        (100, 5),
        (75, 10),
        (50, 15),
        (25, 20),
      ]) ...[_b(_squat, squats), _b(_muscleUp, ups)],
    ],
  ),
  HeroWorkout(
    name: 'Jason, skaliert',
    description:
        'Kniebeugen 100, 75, 50, 25 im Wechsel mit 5, 10, 15, 20 '
        'Klimmzügen.',
    equipment: 'Klimmzugstange',
    deviations: const ['Klimmzüge statt Muscle-ups'],
    blocks: [
      for (final (squats, ups) in const [
        (100, 5),
        (75, 10),
        (50, 15),
        (25, 20),
      ]) ...[_b(_squat, squats), _b(_pullUp, ups)],
    ],
  ),
  HeroWorkout(
    name: 'Michael',
    description: '3 Runden aus 800 m Lauf, 50 Rückenstreckern und 50 Sit-ups.',
    equipment: '$_lauf, Bank für Rückenstrecker',
    blocks: _rounds(3, 800, _b(_backExt, 50), _b(_sitUp, 50)),
  ),
  HeroWorkout(
    name: 'Michael, skaliert',
    description: '3 Runden aus 800 m Lauf, 50 Superman und 50 Sit-ups.',
    equipment: _lauf,
    deviations: const ['Superman statt Rückenstrecker'],
    blocks: _rounds(3, 800, _b(_superman, 50), _b(_sitUp, 50)),
  ),
  HeroWorkout(
    name: 'Michael, kurz',
    description: '3 Runden aus 400 m Lauf, 25 Superman und 25 Sit-ups.',
    equipment: _lauf,
    deviations: const [
      'Läufe 400 m statt 800 m',
      '25 Superman statt 50 Rückenstrecker',
      '25 statt 50 Sit-ups',
    ],
    blocks: _rounds(3, 400, _b(_superman, 25), _b(_sitUp, 25)),
  ),
  HeroWorkout(
    name: 'Griff',
    description:
        '800 m Lauf, 400 m rückwärts, 800 m Lauf, 400 m rückwärts. '
        'Jeden Abschnitt schließt du von Hand ab.',
    equipment: _lauf,
    blocks: _griff(800, 400),
  ),
  HeroWorkout(
    name: 'Griff, kurz',
    description: '400 m Lauf, 200 m rückwärts, 400 m Lauf, 200 m rückwärts.',
    equipment: _lauf,
    deviations: const [
      'Läufe 400 m statt 800 m',
      'Rückwärts 200 m statt 400 m',
    ],
    blocks: _griff(400, 200),
  ),
  HeroWorkout(
    name: 'DT',
    description:
        '5 Runden aus 12 Kreuzheben, 9 Hang Power Cleans und 6 Push '
        'Jerks, alles mit 70 kg.',
    equipment: _hantel,
    blocks: _repeat(5, [
      _b(_deadlift70, 12),
      _b(_hangClean, 9),
      _b(_pushJerk, 6),
    ]),
  ),

  // --- Girls ---
  HeroWorkout(
    name: 'Angie',
    family: HeroFamily.girl,
    description:
        '100 Klimmzüge, 100 Liegestütze, 100 Sit-ups, 100 Kniebeugen, '
        'der Reihe nach.',
    equipment: 'Klimmzugstange',
    blocks: [
      _b(_pullUp, 100),
      _b(_pushUp, 100),
      _b(_sitUp, 100),
      _b(_squat, 100),
    ],
  ),
  HeroWorkout(
    name: 'Barbara',
    family: HeroFamily.girl,
    description:
        '5 Runden aus 20 Klimmzügen, 30 Liegestützen, 40 Sit-ups und '
        '50 Kniebeugen, nach jeder Runde 3 Minuten Pause.',
    equipment: 'Klimmzugstange',
    blocks: _repeat(5, [
      _b(_pullUp, 20),
      _b(_pushUp, 30),
      _b(_sitUp, 40),
      _b(_squat, 50),
      const HeroBlock.rest(180),
    ]),
  ),
  HeroWorkout(
    name: 'Annie',
    family: HeroFamily.girl,
    description: '50-40-30-20-10 aus Double-Unders und Sit-ups.',
    equipment: 'Springseil',
    blocks: _ladder(const [50, 40, 30, 20, 10], [_doubleUnder, _sitUp]),
  ),
  HeroWorkout(
    name: 'Karen',
    family: HeroFamily.girl,
    description: '150 Wall Balls mit 9 kg.',
    equipment: '9-kg-Medizinball, Zielmarke',
    blocks: [_b(_wallBall, 150)],
  ),
  HeroWorkout(
    name: 'Fran',
    family: HeroFamily.girl,
    description: '21-15-9 aus Thrustern mit 43 kg und Klimmzügen.',
    equipment: '$_hantel, Klimmzugstange',
    blocks: _ladder(const [21, 15, 9], [_thruster43, _pullUp]),
  ),
  HeroWorkout(
    name: 'Diane',
    family: HeroFamily.girl,
    description:
        '21-15-9 aus Kreuzheben mit 102 kg und '
        'Handstand-Liegestützen.',
    equipment: '$_hantel, Wand',
    blocks: _ladder(const [21, 15, 9], [_deadlift102, _hspu]),
  ),
  HeroWorkout(
    name: 'Elizabeth',
    family: HeroFamily.girl,
    description: '21-15-9 aus Cleans mit 61 kg und Ring-Dips.',
    equipment: '$_hantel, Ringe',
    blocks: _ladder(const [21, 15, 9], [_clean61, _ringDip]),
  ),
  HeroWorkout(
    name: 'Grace',
    family: HeroFamily.girl,
    description: '30 Clean & Jerks mit 61 kg.',
    equipment: _hantel,
    blocks: [_b(_cleanJerk, 30)],
  ),
  HeroWorkout(
    name: 'Isabel',
    family: HeroFamily.girl,
    description: '30 Snatches mit 61 kg.',
    equipment: _hantel,
    blocks: [_b(_snatch, 30)],
  ),
  HeroWorkout(
    name: 'Jackie',
    family: HeroFamily.girl,
    description: '1000 m Rudern, 50 Thruster mit 20 kg, 30 Klimmzüge.',
    equipment: 'Rudergerät, $_hantel, Klimmzugstange',
    blocks: [
      const HeroBlock.run(1000, label: 'Rudern'),
      _b(_thruster20, 50),
      _b(_pullUp, 30),
    ],
  ),
  HeroWorkout(
    name: 'Linda',
    family: HeroFamily.girl,
    description:
        '10 bis 1 Wiederholungen aus Kreuzheben, Bankdrücken und '
        'Cleans, Gewichte nach Körpergewicht.',
    equipment: '$_hantel, Bank',
    blocks: _ladder(
      const [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
      [_lindaDead, _lindaBench, _lindaClean],
    ),
  ),
  HeroWorkout(
    name: 'Amanda',
    family: HeroFamily.girl,
    description: '9-7-5 aus Muscle-ups und Squat Snatches mit 61 kg.',
    equipment: '$_hantel, Ringe',
    blocks: _ladder(const [9, 7, 5], [_muscleUp, _squatSnatch]),
  ),
  HeroWorkout(
    name: 'Cindy',
    family: HeroFamily.girl,
    format: HeroFormat.amrap,
    capS: 1200,
    description:
        '20 Minuten so viele Runden wie möglich aus 5 Klimmzügen, 10 '
        'Liegestützen und 15 Kniebeugen.',
    equipment: 'Klimmzugstange',
    blocks: [_b(_pullUp, 5), _b(_pushUp, 10), _b(_squat, 15)],
  ),
  HeroWorkout(
    name: 'Cindy, kurz',
    family: HeroFamily.girl,
    format: HeroFormat.amrap,
    capS: 600,
    description:
        '10 Minuten so viele Runden wie möglich aus 5 Klimmzügen, 10 '
        'Liegestützen und 15 Kniebeugen.',
    equipment: 'Klimmzugstange',
    deviations: const ['10 statt 20 Minuten'],
    blocks: [_b(_pullUp, 5), _b(_pushUp, 10), _b(_squat, 15)],
  ),
  HeroWorkout(
    name: 'Chelsea',
    family: HeroFamily.girl,
    format: HeroFormat.emom,
    capS: 1800,
    description:
        'Jede Minute 5 Klimmzüge, 10 Liegestütze und 15 Kniebeugen, '
        '30 Minuten lang. Schaffst du eine Minute nicht, endet das Workout.',
    equipment: 'Klimmzugstange',
    blocks: [_b(_pullUp, 5), _b(_pushUp, 10), _b(_squat, 15)],
  ),
  HeroWorkout(
    name: 'Chelsea, kurz',
    family: HeroFamily.girl,
    format: HeroFormat.emom,
    capS: 900,
    description:
        'Jede Minute 5 Klimmzüge, 10 Liegestütze und 15 Kniebeugen, '
        '15 Minuten lang.',
    equipment: 'Klimmzugstange',
    deviations: const ['15 statt 30 Minuten'],
    blocks: [_b(_pullUp, 5), _b(_pushUp, 10), _b(_squat, 15)],
  ),
  HeroWorkout(
    name: 'Chelsea, leicht',
    family: HeroFamily.girl,
    format: HeroFormat.emom,
    capS: 1800,
    description:
        'Jede Minute 3 Klimmzüge, 6 Liegestütze und 9 Kniebeugen, 30 '
        'Minuten lang.',
    equipment: 'Klimmzugstange',
    deviations: const [
      '3 statt 5 Klimmzüge',
      '6 statt 10 Liegestütze',
      '9 statt 15 Kniebeugen',
    ],
    blocks: [_b(_pullUp, 3), _b(_pushUp, 6), _b(_squat, 9)],
  ),
  HeroWorkout(
    name: 'Mary',
    family: HeroFamily.girl,
    format: HeroFormat.amrap,
    capS: 1200,
    description:
        '20 Minuten so viele Runden wie möglich aus 5 '
        'Handstand-Liegestützen, 10 Pistols im Wechsel und 15 Klimmzügen.',
    equipment: 'Wand, Klimmzugstange',
    blocks: [_b(_hspu, 5), _b(_pistol, 10), _b(_pullUp, 15)],
  ),
  HeroWorkout(
    name: 'Mary, skaliert',
    family: HeroFamily.girl,
    format: HeroFormat.amrap,
    capS: 1200,
    description:
        '20 Minuten so viele Runden wie möglich aus 5 '
        'Pike-Liegestützen, 20 Kniebeugen und 15 Klimmzügen.',
    equipment: 'Klimmzugstange',
    deviations: const [
      'Pike-Liegestütze statt Handstand-Liegestütze',
      '20 Kniebeugen statt 10 Pistols',
    ],
    blocks: [_b(_pike, 5), _b(_squat, 20), _b(_pullUp, 15)],
  ),
  HeroWorkout(
    name: 'Nicole',
    family: HeroFamily.girl,
    format: HeroFormat.amrap,
    capS: 1200,
    description:
        '20 Minuten im Wechsel 400 m laufen und so viele Klimmzüge '
        'wie möglich am Stück. Gewertet werden alle Klimmzüge. Eine '
        'Klimmzug-Serie beendest du mit „Weiter".',
    equipment: _stange,
    blocks: [const HeroBlock.run(400), _max(_pullUp)],
  ),
  HeroWorkout(
    name: 'Nicole, kurz',
    family: HeroFamily.girl,
    format: HeroFormat.amrap,
    capS: 600,
    description:
        '10 Minuten im Wechsel 200 m laufen und so viele Klimmzüge '
        'wie möglich am Stück.',
    equipment: _stange,
    deviations: const ['10 statt 20 Minuten', 'Läufe 200 m statt 400 m'],
    blocks: [const HeroBlock.run(200), _max(_pullUp)],
  ),
  HeroWorkout(
    name: 'Lynne',
    family: HeroFamily.girl,
    format: HeroFormat.maxReps,
    description:
        '5 Runden aus maximal vielen Wiederholungen Bankdrücken mit '
        'dem Körpergewicht und maximal vielen Klimmzügen. Jede Serie beendest '
        'du mit „Weiter".',
    equipment: '$_hantel, Bank, Klimmzugstange',
    blocks: _repeat(5, [_max(_lindaBench), _max(_pullUp)]),
  ),
  HeroWorkout(
    name: 'Lynne, skaliert',
    family: HeroFamily.girl,
    format: HeroFormat.maxReps,
    description:
        '5 Runden aus maximal vielen Liegestützen und maximal vielen '
        'Klimmzügen. Jede Serie beendest du mit „Weiter".',
    equipment: 'Klimmzugstange',
    deviations: const ['Liegestütze statt Bankdrücken mit dem Körpergewicht'],
    blocks: _repeat(5, [_max(_pushUp), _max(_pullUp)]),
  ),
  HeroWorkout(
    name: 'Helen',
    family: HeroFamily.girl,
    description:
        '3 Runden aus 400 m Lauf, 21 Kettlebell Swings mit 24 kg und '
        '12 Klimmzügen.',
    equipment: '$_stange, 24-kg-Kettlebell',
    blocks: _rounds(3, 400, _b(_swing24, 21), _b(_pullUp, 12)),
  ),
  HeroWorkout(
    name: 'Helen, skaliert',
    family: HeroFamily.girl,
    description:
        '3 Runden aus 400 m Lauf, 21 Sprungkniebeugen und 12 '
        'Klimmzügen.',
    equipment: _stange,
    deviations: const ['Sprungkniebeugen statt Kettlebell Swings mit 24 kg'],
    blocks: _rounds(3, 400, _b(_jump, 21), _b(_pullUp, 12)),
  ),
  HeroWorkout(
    name: 'Helen, kurz',
    family: HeroFamily.girl,
    description:
        '3 Runden aus 200 m Lauf, 12 Sprungkniebeugen und 6 '
        'Klimmzügen.',
    equipment: _stange,
    deviations: const [
      'Läufe 200 m statt 400 m',
      '12 Sprungkniebeugen statt 21 Kettlebell Swings mit 24 kg',
      '6 statt 12 Klimmzüge',
    ],
    blocks: _rounds(3, 200, _b(_jump, 12), _b(_pullUp, 6)),
  ),
  HeroWorkout(
    name: 'Eva',
    family: HeroFamily.girl,
    description:
        '5 Runden aus 800 m Lauf, 30 Kettlebell Swings mit 32 kg und '
        '30 Klimmzügen.',
    equipment: '$_stange, 32-kg-Kettlebell',
    blocks: _rounds(5, 800, _b(_swing32, 30), _b(_pullUp, 30)),
  ),
  HeroWorkout(
    name: 'Eva, skaliert',
    family: HeroFamily.girl,
    description:
        '5 Runden aus 800 m Lauf, 30 Sprungkniebeugen und 30 '
        'Klimmzügen.',
    equipment: _stange,
    deviations: const ['Sprungkniebeugen statt Kettlebell Swings mit 32 kg'],
    blocks: _rounds(5, 800, _b(_jump, 30), _b(_pullUp, 30)),
  ),
  HeroWorkout(
    name: 'Eva, kurz',
    family: HeroFamily.girl,
    description:
        '3 Runden aus 400 m Lauf, 15 Sprungkniebeugen und 10 '
        'Klimmzügen.',
    equipment: _stange,
    deviations: const [
      '3 statt 5 Runden',
      'Läufe 400 m statt 800 m',
      '15 Sprungkniebeugen statt 30 Kettlebell Swings mit 32 kg',
      '10 statt 30 Klimmzüge',
    ],
    blocks: _rounds(3, 400, _b(_jump, 15), _b(_pullUp, 10)),
  ),
  HeroWorkout(
    name: 'Kelly',
    family: HeroFamily.girl,
    description:
        '5 Runden aus 400 m Lauf, 30 Box Jumps mit 60 cm und 30 Wall '
        'Balls mit 9 kg.',
    equipment: '$_lauf, Box, 9-kg-Medizinball',
    blocks: _rounds(5, 400, _b(_boxJump, 30), _b(_wallBall, 30)),
  ),
  HeroWorkout(
    name: 'Kelly, skaliert',
    family: HeroFamily.girl,
    description:
        '5 Runden aus 400 m Lauf, 30 Sprungkniebeugen und 30 '
        'Kniebeugen.',
    equipment: _lauf,
    deviations: const [
      'Sprungkniebeugen statt Box Jumps mit 60 cm',
      'Kniebeugen statt Wall Balls mit 9 kg',
    ],
    blocks: _rounds(5, 400, _b(_jump, 30), _b(_squat, 30)),
  ),
  HeroWorkout(
    name: 'Kelly, kurz',
    family: HeroFamily.girl,
    description:
        '3 Runden aus 400 m Lauf, 15 Sprungkniebeugen und 15 '
        'Kniebeugen.',
    equipment: _lauf,
    deviations: const [
      '3 statt 5 Runden',
      '15 Sprungkniebeugen statt 30 Box Jumps mit 60 cm',
      '15 Kniebeugen statt 30 Wall Balls mit 9 kg',
    ],
    blocks: _rounds(3, 400, _b(_jump, 15), _b(_squat, 15)),
  ),
  HeroWorkout(
    name: 'Nancy',
    family: HeroFamily.girl,
    description: '5 Runden aus 400 m Lauf und 15 Overhead Squats mit 43 kg.',
    equipment: '$_lauf, $_hantel',
    blocks: _rounds(5, 400, _b(_ohs, 15)),
  ),
  HeroWorkout(
    name: 'Nancy, skaliert',
    family: HeroFamily.girl,
    description: '5 Runden aus 400 m Lauf und 15 Kniebeugen.',
    equipment: _lauf,
    deviations: const ['Kniebeugen statt Overhead Squats mit 43 kg'],
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
/// Je nach [HeroWorkout.format] endet das Workout mit dem letzten Abschnitt,
/// nach Ablauf der Zeit oder, beim Minutentakt, in der ersten Minute, die
/// nicht geschafft wurde.
///
/// Kennt weder Kamera noch Uhr; [elapsedS] kommt jeweils von außen.
class HeroRun {
  HeroRun(this.workout);

  /// So lange zählt am Anfang eines Laufs keine Wiederholung. Wer an der
  /// Kamera vorbeiläuft, beendet den Lauf damit nicht versehentlich.
  static const minRunS = 30;

  /// Das Warten auf die nächste Minute beim Minutentakt.
  static const _minuteRest = HeroBlock.rest(60);

  final HeroWorkout workout;
  final List<HeroSplit> splits = [];

  int _index = 0;
  int _startT = 0;
  bool _finished = false;
  bool _waiting = false;
  int _nextMinuteT = 60;

  /// Wiederholungen im laufenden Abschnitt.
  int count = 0;

  /// Vollständig geschaffte Runden, bei Zeit- und Minutenformaten.
  int rounds = 0;

  /// Alle gezählten Wiederholungen des Workouts.
  int totalCounted = 0;

  bool get finished => _finished;
  HeroBlock? get current => _finished
      ? null
      : _waiting
      ? _minuteRest
      : workout.blocks[_index];
  HeroBlock? get _next {
    if (_index + 1 < workout.blocks.length) {
      return workout.blocks[_index + 1];
    }
    return workout.format == HeroFormat.amrap ? workout.blocks.first : null;
  }

  int get blockNumber => _index + 1;
  int get blockTotal => workout.blocks.length;

  /// Die Übung, auf die die Kamera gerade achtet: im Lauf schon die nächste.
  RepKind? get countingKind {
    final block = current;
    if (block == null) return null;
    return block.isRun ? _next?.kind : block.kind;
  }

  /// Das Ergebnis, wenn nicht die Zeit zählt.
  String? get score => switch (workout.format) {
    HeroFormat.forTime => null,
    HeroFormat.emom => '$rounds Runden',
    HeroFormat.maxReps => '$totalCounted Wiederholungen',
    HeroFormat.amrap =>
      workout.blocks.any((b) => b.isMax)
          ? '$totalCounted Wiederholungen'
          : '$totalCounted Wiederholungen ($rounds Runden + '
                '${totalCounted - rounds * workout.totalReps})',
  };

  /// Sekunden bis zum Ende einer festen Zeit, sonst `null`.
  int? timeLeft(int elapsedS) {
    final cap = workout.capS;
    return cap == null ? null : (cap - elapsedS).clamp(0, cap);
  }

  /// Sekunden bis zum Ende einer Pause.
  int restLeft(int elapsedS) => _waiting
      ? _nextMinuteT - elapsedS
      : (current?.restS ?? 0) - blockSeconds(elapsedS);

  /// Einmal je Sekunde aufzurufen: beendet Pausen, Minuten und feste Zeiten.
  HeroChange? tick(int elapsedS) {
    if (_finished) return null;
    final cap = workout.capS;
    if (cap != null && elapsedS >= cap) return _finish(elapsedS);
    if (workout.format == HeroFormat.emom && elapsedS >= _nextMinuteT) {
      // Wer in der Minute nicht fertig wurde, ist am Ende angekommen.
      if (!_waiting) return _finish(elapsedS);
      _waiting = false;
      _startT = elapsedS;
      _nextMinuteT += 60;
      return HeroChange.blockDone;
    }
    final rest = current?.restS;
    if (_waiting || rest == null || blockSeconds(elapsedS) < rest) return null;
    return _closeBlock(elapsedS);
  }

  /// Sekunden im laufenden Abschnitt.
  int blockSeconds(int elapsedS) => elapsedS - _startT;

  /// Fortschritt von 0 bis 1: nach der Zeit oder den Abschnitten.
  double progressAt(int elapsedS) {
    final cap = workout.capS;
    if (cap != null) return (elapsedS / cap).clamp(0, 1);
    final block = current;
    if (block == null) return 1;
    final inBlock = block.reps == 0 ? 0.0 : count / block.reps;
    return (_index + inBlock) / workout.blocks.length;
  }

  /// Die Kamera meldet eine vollendete Wiederholung.
  HeroChange? addRep(int elapsedS) {
    final block = current;
    if (block == null) return null;
    if (block.isRest) return null;
    if (!block.isRun) return _countRep(block, elapsedS);
    // Die erste Wiederholung der nächsten Übung beendet den Lauf.
    if (_next?.kind == null || blockSeconds(elapsedS) < minRunS) return null;
    _closeBlock(elapsedS);
    final change = _countRep(current!, elapsedS);
    return change == HeroChange.counted ? HeroChange.blockDone : change;
  }

  /// Eine Wiederholung von Hand; in Lauf und Pause gibt es keine.
  HeroChange? addManualRep(int elapsedS) {
    final block = current;
    if (block == null || !block.counted) return null;
    return _countRep(block, elapsedS);
  }

  HeroChange _countRep(HeroBlock block, int elapsedS) {
    count++;
    totalCounted++;
    return !block.isMax && count >= block.reps
        ? _closeBlock(elapsedS)
        : HeroChange.counted;
  }

  /// Nimmt eine zu viel gezählte Wiederholung zurück.
  void removeRep() {
    if (count > 0) {
      count--;
      totalCounted--;
    }
  }

  /// Schließt den Abschnitt von Hand ab, etwa den letzten Lauf.
  HeroChange? skipBlock(int elapsedS) =>
      _finished || _waiting ? null : _closeBlock(elapsedS);

  HeroChange _closeBlock(int elapsedS) {
    _addSplit(elapsedS);
    _index++;
    if (_index < workout.blocks.length) return HeroChange.blockDone;
    rounds++;
    _index = 0;
    switch (workout.format) {
      case HeroFormat.amrap:
        return HeroChange.blockDone;
      case HeroFormat.emom:
        _waiting = true;
        return HeroChange.blockDone;
      case HeroFormat.forTime || HeroFormat.maxReps:
        _finished = true;
        return HeroChange.finished;
    }
  }

  /// Beendet das Workout mitten im Abschnitt; Angefangenes zählt noch.
  HeroChange _finish(int elapsedS) {
    if (count > 0 || current?.isRun == true) _addSplit(elapsedS);
    _finished = true;
    return HeroChange.finished;
  }

  void _addSplit(int elapsedS) {
    splits.add(HeroSplit(current!, count, elapsedS - _startT, elapsedS));
    _startT = elapsedS;
    count = 0;
  }
}
