import 'dart:convert';

import '../data/database.dart';
import 'builtin_programs.dart';
import 'program_models.dart';

/// Eine Einheit eines Kurses: die Haltungen in ihrer Reihenfolge, danach
/// wahlweise eine Atemübung.
class CourseSession {
  const CourseSession({
    required this.title,
    required this.items,
    this.breathKey,
    this.breathMinutes = 0,
  });

  final String title;
  final List<ProgramItem> items;

  /// Die anschließende Atemübung (siehe `builtinBreathExercises`).
  final String? breathKey;
  final int breathMinutes;
}

/// Eine Stufe eines Kurses: einige Wochen mit festen Einheiten, die sich
/// reihum wiederholen.
class CourseStage {
  const CourseStage({
    required this.title,
    required this.weeks,
    required this.focus,
    required this.sessions,
  });

  final String title;
  final int weeks;

  /// Worauf es in dieser Stufe ankommt.
  final String focus;
  final List<CourseSession> sessions;
}

/// Ein aufbauender Kurs über mehrere Wochen (I-049).
class Course {
  const Course({
    required this.id,
    required this.name,
    required this.description,
    required this.sessionsPerWeek,
    required this.category,
    required this.stages,
  });

  final String id;
  final String name;
  final String description;
  final int sessionsPerWeek;
  final ExerciseCategory category;
  final List<CourseStage> stages;

  int get totalWeeks => stages.fold(0, (sum, s) => sum + s.weeks);

  /// So viele Einheiten umfasst eine Stufe.
  int sessionsIn(CourseStage stage) => stage.weeks * sessionsPerWeek;

  /// Die Einheit als abspielbares Programm.
  Program program(int stage, int session) {
    final s = stages[stage].sessions[session];
    return Program(
      name: '$name · Stufe ${stage + 1} · ${s.title}',
      category: category,
      items: s.items,
    );
  }
}

/// Wie weit der Nutzer in einem Kurs ist. Wird in den Einstellungen
/// gemerkt und zwischen den Geräten abgeglichen.
class CourseProgress {
  const CourseProgress({this.stage = 0, this.done = 0, this.updatedAt = 0});

  /// Die laufende Stufe, ab 0.
  final int stage;

  /// Absolvierte Einheiten in der laufenden Stufe.
  final int done;
  final int updatedAt;

  static String key(String courseId) => 'course.$courseId';

  static CourseProgress load(AppDatabase db, Course course) {
    final raw = db.setting(key(course.id));
    if (raw == null) return const CourseProgress();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return CourseProgress(
        stage: (j['stage'] as int).clamp(0, course.stages.length - 1),
        done: (j['done'] as int).clamp(0, 9999),
        updatedAt: j['updated_at'] as int? ?? 0,
      );
    } catch (_) {
      return const CourseProgress();
    }
  }

  /// Speichert den Stand; [updatedAt] nur beim Übernehmen von einem anderen
  /// Gerät angeben.
  void save(AppDatabase db, Course course, {int? updatedAt}) => db.setSetting(
    key(course.id),
    jsonEncode({
      'stage': stage,
      'done': done,
      'updated_at': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    }),
  );

  bool get started => stage > 0 || done > 0;

  /// Die nächste Einheit der Stufe: reihum Tag 1, 2, 3, 1, …
  int nextSession(Course course) => done % course.stages[stage].sessions.length;

  /// Alle Einheiten der Stufe sind geschafft; Zeit für die nächste Stufe.
  bool stageComplete(Course course) =>
      done >= course.sessionsIn(course.stages[stage]);

  bool isLastStage(Course course) => stage == course.stages.length - 1;

  CourseProgress sessionDone() => CourseProgress(stage: stage, done: done + 1);

  CourseProgress toStage(Course course, int stage) =>
      CourseProgress(stage: stage.clamp(0, course.stages.length - 1), done: 0);

  Map<String, Object?> toJson() => {
    'stage': stage,
    'done': done,
    'updated_at': updatedAt,
  };
}

/// Alle Kurse der App.
final List<Course> builtinCourses = [yogaBasicCourse];

Course? courseById(String id) =>
    builtinCourses.where((c) => c.id == id).firstOrNull;

// --- Yoga-Grundkurs ---
//
// Eigener Aufbau nach den Ordnungsregeln aus „Light on Yoga" (siehe
// docs/YOGA-STRUKTUR.md): Stehhaltungen zuerst, Entspannung zum Schluss,
// neue Haltungen schrittweise, eine Stufe zum Festigen mit längerem Halten,
// Atemübung nach den Haltungen.

ProgramItem _p(String key, int seconds, {int rest = 5, bool sides = false}) =>
    ProgramItem(
      exerciseUuid: 'builtin-$key',
      timed: true,
      amount: seconds,
      restS: rest,
      bothSides: sides,
    );

/// Einseitige Haltung, auf beiden Seiten gehalten.
ProgramItem _s(String key, int seconds) => _p(key, seconds, sides: true);

ProgramItem _savasana(int seconds) =>
    _p('yoga_20_totenstellung', seconds, rest: 0);

List<ProgramItem> _sun(int rounds) => [
  for (var i = 0; i < rounds; i++) ...sunSalutation,
  // Nach dem letzten Sonnengruß kurz in der Berghaltung ankommen.
  _p('yoga_01_berghaltung', 15),
];

const _berg = 'yoga_01_berghaltung';
const _hund = 'yoga_02_herabschauender_hund';
const _kobra = 'yoga_04_kobra';
const _kind = 'yoga_05_kindhaltung';
const _katzeKuh = 'yoga_06_katze_kuh';
const _krieger1 = 'yoga_07_krieger_1';
const _krieger2 = 'yoga_08_krieger_2';
const _krieger3 = 'yoga_09_krieger_3';
const _dreieck = 'yoga_10_dreieck';
const _baum = 'yoga_11_baum';
const _stuhl = 'yoga_12_stuhl';
const _vorbeuge = 'yoga_13_stehende_vorbeuge';
const _sitzVorbeuge = 'yoga_14_sitzende_vorbeuge';
const _bruecke = 'yoga_15_bruecke';
const _boot = 'yoga_16_boot';
const _taube = 'yoga_17_taube';
const _drehsitz = 'yoga_18_drehsitz';
const _ausfallschritt = 'yoga_19_tiefer_ausfallschritt';
const _halbeVorbeuge = 'yoga_21_halbe_vorbeuge';
const _winkel = 'yoga_24_seitliche_winkelhaltung';
const _umgKrieger = 'yoga_25_umgekehrter_krieger';
const _pyramide = 'yoga_26_pyramide';
const _graetsche = 'yoga_27_gegraetschte_vorbeuge';
const _halbmond = 'yoga_28_halbmond';
const _adler = 'yoga_29_adler';
const _taenzer = 'yoga_30_taenzer';
const _heuschrecke = 'yoga_31_heuschrecke';
const _bogen = 'yoga_32_bogen';
const _kamel = 'yoga_33_kamel';
const _sphinx = 'yoga_34_sphinx';
const _delfin = 'yoga_35_delfin';
const _tisch = 'yoga_36_umgekehrter_tisch';
const _kopfKnie = 'yoga_37_kopf_zu_knie';
const _baby = 'yoga_38_glueckliches_baby';
const _liegSchmetterling = 'yoga_39_liegender_schmetterling';
const _spagat = 'yoga_40_halber_spagat';
const _pflug = 'yoga_41_pflug';
const _schulterstand = 'yoga_42_schulterstand';
const _fisch = 'yoga_45_fisch';
const _beineWand = 'yoga_46_beine_an_der_wand';
const _heldensitz = 'yoga_47_heldensitz';
const _gedrDreieck = 'yoga_48_gedrehtes_dreieck';
const _gedrWinkel = 'yoga_49_gedrehter_winkel';
const _gedrStuhl = 'yoga_50_gedrehter_stuhl';
const _goettin = 'yoga_51_goettin';
const _hoherAusfallschritt = 'yoga_52_hoher_ausfallschritt';
const _handZumZeh = 'yoga_53_hand_zum_zeh';
const _welpe = 'yoga_54_welpe';
const _dreibeinHund = 'yoga_55_dreibeiniger_hund';
const _halbesBoot = 'yoga_57_halbes_boot';
const _marichy1 = 'yoga_59_marichyasana_1';
const _marichy3 = 'yoga_60_marichyasana_3';
const _bharadvaja = 'yoga_61_bharadvajasana';
const _tor = 'yoga_62_tor';
const _stehSpagat = 'yoga_63_stehender_spagat';
const _stock = 'yoga_64_stock';
const _liegHandZeh = 'yoga_65_liegende_hand_zum_zeh';
const _liegHeldensitz = 'yoga_66_liegender_heldensitz';
const _ohrendruck = 'yoga_67_ohrendruck';
const _schulterstandEinBein = 'yoga_68_schulterstand_ein_bein';
const _kuhgesicht = 'yoga_69_kuhgesicht';
const _schmetterling = 'dehnen_10_schmetterling';
const _liegDrehung = 'dehnen_14_wirbelsaeule_drehung';
const _kraehe = 'cali_20_kraehe';

/// Die Umkehrhaltungen gegen Ende der Einheit, vor der Entspannung, wie es
/// die Ordnungsregeln vorsehen; der Fisch gleicht danach den Nacken aus.
/// Ab Stufe 2; in Stufe 6 mit den Abwandlungen des Schulterstands.
List<ProgramItem> _inversions(
  int stand,
  int plough, {
  bool variations = false,
}) => [
  _p(_schulterstand, stand),
  if (variations) _s(_schulterstandEinBein, 20),
  _p(_pflug, plough),
  if (variations) _p(_ohrendruck, 30),
  _p(_fisch, (stand ~/ 4).clamp(20, 45)),
];

/// Stufe 1: statt Schulterstand die sanfte Umkehrhaltung an der Wand.
ProgramItem _legsUpTheWall() => _p(_beineWand, 120);

/// Stufen 3 und 4: gleiche Haltungen, in Stufe 4 länger gehalten.
List<CourseSession> _sunStage(
  int hold,
  int sunRounds,
  int savasana,
  List<(String, int)> breaths,
  List<ProgramItem> inversions,
) => [
  CourseSession(
    title: 'Tag 1 – Stehhaltungen',
    items: [
      ..._sun(sunRounds),
      _s(_krieger2, hold),
      _s(_winkel, hold),
      _s(_dreieck, hold),
      _s(_gedrDreieck, hold ~/ 2 + 5),
      _s(_krieger1, hold),
      _s(_hoherAusfallschritt, hold ~/ 2 + 5),
      _s(_krieger3, hold ~/ 2 + 5),
      _s(_halbmond, hold ~/ 2 + 5),
      _s(_pyramide, hold),
      _p(_graetsche, hold + 15),
      _p(_goettin, hold ~/ 2 + 5),
      _p(_kind, 45),
      ...inversions,
      _savasana(savasana),
    ],
    breathKey: breaths[0].$1,
    breathMinutes: breaths[0].$2,
  ),
  CourseSession(
    title: 'Tag 2 – Vorbeugen und Hüfte',
    items: [
      ..._sun(sunRounds),
      _s(_ausfallschritt, hold),
      _s(_spagat, hold),
      _p(_stock, 30),
      _p(_sitzVorbeuge, hold + 30),
      _s(_kopfKnie, hold),
      _s(_marichy1, hold ~/ 2 + 5),
      _s(_drehsitz, hold),
      _s(_marichy3, hold ~/ 2 + 5),
      _s(_taube, hold + 15),
      _p(_liegSchmetterling, 60),
      ...inversions,
      _s(_liegDrehung, 30),
      _savasana(savasana),
    ],
    breathKey: breaths[1].$1,
    breathMinutes: breaths[1].$2,
  ),
  CourseSession(
    title: 'Tag 3 – Rücken und Balance',
    items: [
      ..._sun(sunRounds),
      _s(_adler, hold - 5),
      _s(_baum, hold),
      _p(_stuhl, hold),
      _s(_tor, hold ~/ 2 + 5),
      _p(_heuschrecke, hold - 5),
      _p(_bogen, hold - 10),
      _p(_kind, 30),
      _p(_welpe, 30),
      _p(_delfin, hold - 10),
      _p(_bruecke, hold),
      _p(_tisch, hold - 10),
      _p(_boot, hold - 10),
      _p(_halbesBoot, hold - 10),
      _p(_heldensitz, 60),
      ...inversions,
      _p(_baby, 30),
      _savasana(savasana),
    ],
    breathKey: breaths[2].$1,
    breathMinutes: breaths[2].$2,
  ),
];

/// Stufen 5 und 6: Fließen, Drehungen im Stand, tiefere Rückbeugen und
/// Balance.
List<CourseSession> _flowStage(
  int hold,
  int sunRounds,
  int savasana,
  List<(String, int)> breaths,
  List<ProgramItem> inversions, {
  bool crow = false,
}) => [
  CourseSession(
    title: 'Tag 1 – Stehhaltungen',
    items: [
      ..._sun(sunRounds),
      _s(_krieger2, hold),
      _s(_umgKrieger, hold - 15),
      _s(_winkel, hold),
      _s(_gedrWinkel, hold - 15),
      _s(_dreieck, hold),
      _s(_gedrDreieck, hold - 15),
      _s(_halbmond, hold - 15),
      _s(_krieger1, hold),
      _s(_krieger3, hold - 15),
      _s(_pyramide, hold),
      _s(_stehSpagat, hold - 20),
      _p(_graetsche, hold + 15),
      _p(_kind, 45),
      ...inversions,
      _savasana(savasana),
    ],
    breathKey: breaths[0].$1,
    breathMinutes: breaths[0].$2,
  ),
  CourseSession(
    title: 'Tag 2 – Vorbeugen und Hüfte',
    items: [
      ..._sun(sunRounds),
      _p(_hund, 60),
      _s(_dreibeinHund, 20),
      _p(_delfin, hold - 15),
      _s(_ausfallschritt, hold),
      _s(_spagat, hold),
      _p(_stock, 30),
      _p(_sitzVorbeuge, hold + 45),
      _s(_kopfKnie, hold + 15),
      _s(_marichy1, hold - 15),
      _s(_marichy3, hold - 15),
      _s(_taube, hold + 15),
      _s(_kuhgesicht, hold - 15),
      _p(_liegSchmetterling, 90),
      ...inversions,
      _savasana(savasana),
    ],
    breathKey: breaths[1].$1,
    breathMinutes: breaths[1].$2,
  ),
  CourseSession(
    title: 'Tag 3 – Rücken und Balance',
    items: [
      ..._sun(sunRounds),
      _s(_handZumZeh, hold - 25),
      _s(_taenzer, hold - 20),
      _s(_adler, hold - 15),
      _s(_baum, hold),
      _s(_gedrStuhl, hold - 20),
      _p(_heuschrecke, hold - 15),
      _p(_bogen, hold - 20),
      _p(_kamel, hold - 25),
      _p(_kind, 45),
      _p(_bruecke, hold - 5),
      _p(_tisch, hold - 20),
      if (crow) _p(_kraehe, 15),
      _p(_boot, hold - 15),
      _p(_heldensitz, 45),
      _p(_liegHeldensitz, hold - 15),
      ...inversions,
      _s(_liegDrehung, 45),
      _savasana(savasana),
    ],
    breathKey: breaths[2].$1,
    breathMinutes: breaths[2].$2,
  ),
];

final Course yogaBasicCourse = Course(
  id: 'yoga-grundkurs',
  name: 'Yoga-Grundkurs',
  description:
      'Zwölf Wochen in sechs Stufen, drei Einheiten je Woche. Jede Stufe '
      'hat drei Einheiten mit eigenem Schwerpunkt: Stehhaltungen, Vorbeugen '
      'und Hüfte, Rücken und Balance. Neue Haltungen kommen schrittweise '
      'dazu, die Haltezeiten wachsen von 20 auf 60 Sekunden. Jede Einheit '
      'endet mit einer Umkehrhaltung: anfangs Beine an der Wand, ab Stufe 2 '
      'Schulterstand, Pflug und Fisch. Nach den Haltungen folgt eine '
      'Atemübung. Weiter geht es erst, wenn die Haltungen einer Stufe sicher '
      'sitzen.',
  sessionsPerWeek: 3,
  category: ExerciseCategory.yoga,
  stages: [
    CourseStage(
      title: 'Ankommen und Stehen',
      weeks: 2,
      focus:
          'Die Grundhaltungen kennenlernen: fester Stand, gestreckte '
          'Beine, ruhiger Atem. Lieber kürzer und sauber halten. Zum Schluss '
          'die Beine an der Wand als sanfte Umkehrhaltung.',
      sessions: [
        CourseSession(
          title: 'Tag 1 – Stehhaltungen',
          items: [
            _p(_berg, 30),
            _s(_baum, 20),
            _s(_dreieck, 20),
            _s(_winkel, 20),
            _s(_krieger2, 20),
            _s(_krieger1, 20),
            _s(_pyramide, 20),
            _p(_vorbeuge, 30),
            _p(_kind, 45),
            _legsUpTheWall(),
            _savasana(180),
          ],
          breathKey: 'bauchatmung',
          breathMinutes: 3,
        ),
        CourseSession(
          title: 'Tag 2 – Vorbeugen und Hüfte',
          items: [
            _p(_berg, 30),
            _p(_katzeKuh, 45),
            _p(_hund, 30),
            _p(_kind, 30),
            _p(_vorbeuge, 30),
            _p(_stock, 30),
            _p(_sitzVorbeuge, 30),
            _s(_kopfKnie, 20),
            _s(_bharadvaja, 20),
            _p(_schmetterling, 45),
            _s(_liegHandZeh, 30),
            _s(_liegDrehung, 30),
            _legsUpTheWall(),
            _savasana(180),
          ],
          breathKey: 'bauchatmung',
          breathMinutes: 3,
        ),
        CourseSession(
          title: 'Tag 3 – Rücken und Balance',
          items: [
            _p(_berg, 30),
            _s(_baum, 20),
            _s(_krieger2, 20),
            _s(_dreieck, 20),
            _s(_tor, 20),
            _p(_sphinx, 30),
            _p(_kobra, 20),
            _p(_kind, 30),
            _p(_bruecke, 20),
            _p(_baby, 30),
            _legsUpTheWall(),
            _savasana(180),
          ],
          breathKey: 'bauchatmung',
          breathMinutes: 3,
        ),
      ],
    ),
    CourseStage(
      title: 'Festigen und Erweitern',
      weeks: 2,
      focus:
          'Haltungen 30 Sekunden halten, neue dazu: gedrehtes Dreieck, hoher '
          'Ausfallschritt, Stuhl, Adler, Drehungen im Sitz und als erste '
          'echte Umkehrhaltungen Schulterstand und Pflug, mit einer gefalteten '
          'Decke unter den Schultern, danach der Fisch. Nach den Haltungen der '
          'siegreiche Atem im Heldensitz.',
      sessions: [
        CourseSession(
          title: 'Tag 1 – Stehhaltungen',
          items: [
            _p(_berg, 30),
            _s(_baum, 30),
            _s(_dreieck, 30),
            _s(_gedrDreieck, 20),
            _s(_winkel, 30),
            _s(_krieger2, 30),
            _s(_umgKrieger, 20),
            _s(_krieger1, 30),
            _s(_hoherAusfallschritt, 20),
            _s(_pyramide, 30),
            _p(_graetsche, 40),
            _p(_stuhl, 20),
            _p(_kind, 45),
            ..._inversions(30, 20),
            _savasana(180),
          ],
          breathKey: 'ujjayi',
          breathMinutes: 5,
        ),
        CourseSession(
          title: 'Tag 2 – Vorbeugen und Hüfte',
          items: [
            _p(_berg, 30),
            _p(_katzeKuh, 45),
            _p(_hund, 40),
            _p(_vorbeuge, 40),
            _p(_halbeVorbeuge, 15),
            _p(_stock, 30),
            _p(_sitzVorbeuge, 45),
            _s(_kopfKnie, 30),
            _s(_marichy1, 20),
            _s(_bharadvaja, 30),
            _s(_drehsitz, 30),
            _p(_liegSchmetterling, 60),
            _s(_liegHandZeh, 30),
            _s(_liegDrehung, 30),
            ..._inversions(30, 20),
            _savasana(180),
          ],
          breathKey: 'ujjayi',
          breathMinutes: 5,
        ),
        CourseSession(
          title: 'Tag 3 – Rücken und Balance',
          items: [
            _p(_berg, 30),
            _s(_adler, 20),
            _s(_baum, 30),
            _s(_krieger2, 30),
            _s(_dreieck, 30),
            _s(_tor, 30),
            _p(_sphinx, 30),
            _p(_heuschrecke, 20),
            _p(_kobra, 20),
            _p(_kind, 30),
            _p(_bruecke, 30),
            _p(_boot, 15),
            _p(_halbesBoot, 15),
            _p(_heldensitz, 60),
            _p(_baby, 30),
            ..._inversions(30, 20),
            _savasana(180),
          ],
          breathKey: 'ujjayi',
          breathMinutes: 5,
        ),
      ],
    ),
    CourseStage(
      title: 'Sonnengruß und Kraft',
      weeks: 2,
      focus:
          'Jede Einheit beginnt mit zwei Sonnengrüßen. Neu: Krieger III, '
          'Halbmond, Göttin, Taube, Marichyasana, Bogen, Welpe, Delfin. '
          'Erstmals die Wechselatmung.',
      sessions: _sunStage(30, 2, 240, [
        ('ujjayi', 6),
        ('wechselatmung', 5),
        ('langes_ausatmen', 5),
      ], _inversions(60, 30)),
    ),
    CourseStage(
      title: 'Festigung: länger halten',
      weeks: 2,
      focus:
          'Dieselben Haltungen wie in Stufe 3, jetzt 45 Sekunden und mit '
          'drei Sonnengrüßen. Ziel: ruhig atmen, auch wenn es anstrengt.',
      sessions: _sunStage(45, 3, 300, [
        ('ujjayi', 8),
        ('wechselatmung', 8),
        ('gestuft', 6),
      ], _inversions(90, 45)),
    ),
    CourseStage(
      title: 'Fließen und Rückbeugen',
      weeks: 2,
      focus:
          'Neu: gedrehter seitlicher Winkel, stehender Spagat, Hand zum Zeh, '
          'Tänzer und Kamel, dazu Kuhgesicht und liegender Heldensitz. Die '
          'Vorbeugen werden länger gehalten.',
      sessions: _flowStage(45, 3, 300, [
        ('ujjayi', 8),
        ('wechselatmung', 10),
        ('gestuft', 8),
      ], _inversions(120, 60)),
    ),
    CourseStage(
      title: 'Vertiefen',
      weeks: 2,
      focus:
          'Die Haltungen eine Minute halten, vier Sonnengrüße, dazu die '
          'Krähe als erste Armbalance und die Abwandlungen des Schulterstands. '
          'Danach lässt sich jede Stufe beliebig wiederholen.',
      sessions: _flowStage(
        60,
        4,
        300,
        [('ujjayi', 10), ('wechselatmung', 10), ('sonnenatmung', 8)],
        _inversions(180, 60, variations: true),
        crow: true,
      ),
    ),
  ],
);
