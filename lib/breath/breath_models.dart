/// Was der Atem in einem Schritt einer Atemübung tut.
enum BreathAction {
  inhale('Einatmen'),
  exhale('Ausatmen'),
  holdIn('Halten'),
  holdOut('Leer halten'),

  /// Ein kurzer, kräftiger Atemstoß; die Einatmung geschieht von selbst.
  stroke('Stoß'),

  /// Frei und ruhig atmen, etwa zwischen zwei Runden.
  rest('Ruhig atmen');

  const BreathAction(this.label);

  final String label;

  bool get isHold => this == holdIn || this == holdOut;
}

/// Durch welche Nasenseite geatmet wird.
enum Nostril {
  both(''),
  left('links'),
  right('rechts'),

  /// Durch den Mund, etwa bei der kühlenden Atmung.
  mouth('durch den Mund');

  const Nostril(this.label);

  final String label;
}

/// Ein Schritt einer Atemübung.
class BreathStep {
  const BreathStep(this.action, this.seconds, {this.nostril = Nostril.both});

  final BreathAction action;
  final int seconds;
  final Nostril nostril;

  /// Ob der Atem dabei für längere Zeit angehalten wird. Kurze Pausen von
  /// bis zu [shortPauseS] Sekunden gelten nicht als Anhalten; sie gehören
  /// etwa zur gestuften Atmung.
  bool get isLongHold => action.isHold && seconds > shortPauseS;

  static const shortPauseS = 2;

  /// Der angesagte Text, z. B. „Einatmen links".
  String get label => nostril == Nostril.both
      ? action.label
      : '${action.label} ${nostril.label}';
}

/// Eine geführte Atemübung (Pranayama): ein Zyklus aus Schritten, der so
/// oft wiederholt wird, bis die gewählte Zeit erreicht ist.
class BreathExercise {
  const BreathExercise({
    required this.key,
    required this.name,
    this.sanskrit = '',
    required this.description,
    required this.posture,
    required this.cycle,
    this.defaultMinutes = 5,
    this.level = 1,
    this.caution = '',
  });

  /// Feste Kennung, unter der Einstellungen gemerkt werden.
  final String key;
  final String name;
  final String sanskrit;
  final String description;

  /// In welcher Haltung geübt wird.
  final String posture;

  /// Die Grafik zur Haltung: liegend die Totenstellung, sonst der bequeme
  /// Sitz.
  String get postureImageKey => posture.startsWith('Rückenlage')
      ? 'yoga_20_totenstellung'
      : 'yoga_56_bequemer_sitz';
  final List<BreathStep> cycle;
  final int defaultMinutes;

  /// 1 leicht, 2 mittel, 3 schwer.
  final int level;
  final String caution;

  int get cycleSeconds => cycle.fold(0, (sum, s) => sum + s.seconds);

  bool get hasLongHolds => cycle.any((s) => s.isLongHold);

  /// Schnelle Atmung: Schritte von einer Sekunde werden nicht angesagt,
  /// sondern bekommen nur einen kurzen Ton.
  bool get isRapid => cycle.any((s) => s.seconds <= 1);

  /// Der Zyklus ohne langes Anhalten des Atems, für alle, die das noch
  /// nicht freigeschaltet haben.
  List<BreathStep> cycleWithHolds(bool allowed) =>
      allowed ? cycle : [for (final s in cycle) if (!s.isLongHold) s];

  /// Der Rhythmus in Kurzform, z. B. „Ein 4 s · Aus 6 s".
  String rhythm({bool holdsAllowed = true}) {
    final steps = cycleWithHolds(holdsAllowed);
    if (isRapid) {
      final fast = steps.where((s) =>
          s.seconds <= 1 && s.action != BreathAction.inhale);
      final rest = steps.where((s) => s.action == BreathAction.rest);
      return '${fast.length} schnelle Atemzüge, dann '
          '${rest.fold(0, (a, s) => a + s.seconds)} s ruhig atmen';
    }
    String short(BreathStep s) => switch (s.action) {
          BreathAction.inhale => 'Ein',
          BreathAction.exhale => 'Aus',
          BreathAction.holdIn => 'Halten',
          BreathAction.holdOut => 'Leer',
          BreathAction.stroke => 'Stoß',
          BreathAction.rest => 'Ruhig',
        };
    return steps
        .map((s) => '${short(s)}${s.nostril == Nostril.both ? '' : ' ${s.nostril.label}'} ${s.seconds} s')
        .join(' · ');
  }
}

List<BreathStep> _rapid(BreathStep step, int count, int restS) => [
      for (var i = 0; i < count; i++) step,
      BreathStep(BreathAction.rest, restS),
    ];

/// Die mitgelieferten Atemübungen, von leicht nach schwer.
final List<BreathExercise> builtinBreathExercises = [
  const BreathExercise(
    key: 'bauchatmung',
    name: 'Bauchatmung',
    description:
        'Eine Hand auf den Bauch legen. Beim Einatmen hebt sich der Bauch, '
        'beim Ausatmen sinkt er. Brust und Schultern bleiben ruhig. Gut als '
        'Einstieg und zum Ankommen nach dem Üben.',
    posture: 'Rückenlage, Beine lang oder aufgestellt',
    cycle: [
      BreathStep(BreathAction.inhale, 4),
      BreathStep(BreathAction.exhale, 6),
    ],
    defaultMinutes: 5,
  ),
  const BreathExercise(
    key: 'ujjayi',
    name: 'Siegreicher Atem',
    sanskrit: 'Ujjayi',
    description:
        'Durch die Nase atmen und die Kehle leicht verengen, sodass ein '
        'leises, gleichmäßiges Rauschen entsteht. Ein- und Ausatmen sind '
        'gleich lang, tief und ohne Ruck. Die Grundlage der übrigen Übungen.',
    posture: 'Rückenlage in der Totenstellung oder aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 5),
      BreathStep(BreathAction.exhale, 5),
    ],
  ),
  const BreathExercise(
    key: 'langes_ausatmen',
    name: 'Langes Ausatmen',
    sanskrit: 'Visama Vritti',
    description:
        'Doppelt so lang aus- wie einatmen, mit dem Ujjayi-Rauschen. Beruhigt '
        'und eignet sich zum Abschluss oder vor dem Schlafen.',
    posture: 'Aufrechter Sitz oder Rückenlage',
    cycle: [
      BreathStep(BreathAction.inhale, 4),
      BreathStep(BreathAction.exhale, 8),
    ],
  ),
  const BreathExercise(
    key: 'summen',
    name: 'Summender Atem',
    sanskrit: 'Bhramari',
    description:
        'Durch die Nase einatmen, beim Ausatmen mit geschlossenem Mund '
        'gleichmäßig summen wie eine Biene. Die Zeigefinger dürfen die '
        'Ohren verschließen.',
    posture: 'Aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 4),
      BreathStep(BreathAction.exhale, 8),
    ],
  ),
  const BreathExercise(
    key: 'kuehlend',
    name: 'Kühlender Atem',
    sanskrit: 'Sitali',
    description:
        'Die Zunge zu einer Röhre rollen und durch sie einatmen; wem das '
        'nicht gelingt, atmet zwischen den Zähnen ein. Den Mund schließen '
        'und durch die Nase ausatmen.',
    posture: 'Aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 5, nostril: Nostril.mouth),
      BreathStep(BreathAction.exhale, 6),
    ],
    caution: 'Nicht bei niedrigem Blutdruck oder Erkältung.',
  ),
  const BreathExercise(
    key: 'wechselatmung',
    name: 'Wechselatmung',
    sanskrit: 'Nadi Shodhana',
    description:
        'Mit Daumen und Ringfinger der rechten Hand abwechselnd ein '
        'Nasenloch verschließen. Links ein, rechts aus, rechts ein, links '
        'aus: das ist ein Zyklus.',
    posture: 'Aufrechter Sitz, Schneidersitz oder Fersensitz',
    cycle: [
      BreathStep(BreathAction.inhale, 4, nostril: Nostril.left),
      BreathStep(BreathAction.exhale, 6, nostril: Nostril.right),
      BreathStep(BreathAction.inhale, 4, nostril: Nostril.right),
      BreathStep(BreathAction.exhale, 6, nostril: Nostril.left),
    ],
    defaultMinutes: 8,
    level: 2,
  ),
  const BreathExercise(
    key: 'sonnenatmung',
    name: 'Sonnenatmung',
    sanskrit: 'Surya Bhedana',
    description:
        'Immer rechts einatmen und links ausatmen; das jeweils andere '
        'Nasenloch bleibt mit den Fingern verschlossen.',
    posture: 'Aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 5, nostril: Nostril.right),
      BreathStep(BreathAction.exhale, 7, nostril: Nostril.left),
    ],
    level: 2,
    caution: 'Nicht bei hohem Blutdruck oder Herzbeschwerden.',
  ),
  const BreathExercise(
    key: 'gestuft',
    name: 'Einatmen in Stufen',
    sanskrit: 'Viloma',
    description:
        'In drei Abschnitten einatmen, jeweils mit einer kurzen Pause, bis die '
        'Lunge voll ist; dann langsam und ohne Unterbrechung ausatmen. '
        'Danach zwei ruhige Atemzüge.',
    posture: 'Rückenlage oder aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 2),
      BreathStep(BreathAction.holdIn, 2),
      BreathStep(BreathAction.inhale, 2),
      BreathStep(BreathAction.holdIn, 2),
      BreathStep(BreathAction.inhale, 2),
      BreathStep(BreathAction.holdIn, 2),
      BreathStep(BreathAction.exhale, 8),
      BreathStep(BreathAction.rest, 10),
    ],
    level: 2,
  ),
  const BreathExercise(
    key: 'ujjayi_halten',
    name: 'Siegreicher Atem mit Halten',
    sanskrit: 'Ujjayi mit Antara Kumbhaka',
    description:
        'Wie der siegreiche Atem, nach dem Einatmen wird der Atem kurz '
        'gehalten, ohne Druck in Kopf und Gesicht. Erst üben, wenn das '
        'gleichmäßige Ujjayi-Atmen sicher sitzt.',
    posture: 'Aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 5),
      BreathStep(BreathAction.holdIn, 5),
      BreathStep(BreathAction.exhale, 7),
    ],
    level: 3,
    caution: 'Nicht bei hohem Blutdruck, Herzbeschwerden oder in der '
        'Schwangerschaft. Wird es eng oder schwindelig, sofort normal atmen.',
  ),
  const BreathExercise(
    key: 'kastenatmung',
    name: 'Kastenatmung',
    sanskrit: 'Sama Vritti',
    description:
        'Einatmen, halten, ausatmen, leer halten, alles gleich lang. Ohne '
        'freigeschaltetes Atemanhalten bleiben nur Ein- und Ausatmen.',
    posture: 'Aufrechter Sitz',
    cycle: [
      BreathStep(BreathAction.inhale, 4),
      BreathStep(BreathAction.holdIn, 4),
      BreathStep(BreathAction.exhale, 4),
      BreathStep(BreathAction.holdOut, 4),
    ],
    level: 3,
    caution: 'Nicht bei hohem Blutdruck, Herzbeschwerden oder in der '
        'Schwangerschaft.',
  ),
  BreathExercise(
    key: 'feueratem',
    name: 'Feueratem',
    sanskrit: 'Kapalabhati',
    description:
        'Kurze, kräftige Atemstöße durch die Nase aus dem Bauch heraus; das '
        'Einatmen geschieht von selbst. Eine Runde aus 20 Stößen, dann ruhig '
        'atmen. Mit jedem Ton ein Stoß.',
    posture: 'Aufrechter Sitz',
    cycle: _rapid(const BreathStep(BreathAction.stroke, 1), 20, 30),
    level: 3,
    caution: 'Nicht bei hohem Blutdruck, Herzbeschwerden, Epilepsie, '
        'Bauchbeschwerden oder in der Schwangerschaft. Bei Schwindel aufhören.',
  ),
  BreathExercise(
    key: 'blasebalg',
    name: 'Blasebalg-Atmung',
    sanskrit: 'Bhastrika',
    description:
        'Kräftig und gleich stark ein- und ausatmen, je eine Sekunde, wie ein '
        'Blasebalg. Zehn Atemzüge, dann ruhig atmen.',
    posture: 'Aufrechter Sitz',
    cycle: [
      for (var i = 0; i < 10; i++) ...const [
        BreathStep(BreathAction.inhale, 1),
        BreathStep(BreathAction.exhale, 1),
      ],
      const BreathStep(BreathAction.rest, 30),
    ],
    level: 3,
    caution: 'Nicht bei hohem Blutdruck, Herzbeschwerden, Epilepsie oder in '
        'der Schwangerschaft. Bei Schwindel aufhören.',
  ),
];

BreathExercise? breathExerciseByKey(String key) =>
    builtinBreathExercises.where((b) => b.key == key).firstOrNull;
