import 'program_models.dart';

/// Mitgelieferte Programme zum Ausprobieren (Lastenheft A-044).
/// Die Übungen sind über den Dateinamen ihrer Grafik benannt. Einseitige
/// Übungen laufen mit `sides: true` auf beiden Seiten.
const List<Program> builtinPrograms = [
  Program(
    name: 'Yoga: Sanfter Einstieg',
    category: ExerciseCategory.yoga,
    items: [
      _Timed('yoga_01_berghaltung', 30),
      _Timed('yoga_13_stehende_vorbeuge', 40),
      _Timed('yoga_06_katze_kuh', 45),
      _Timed('yoga_02_herabschauender_hund', 45),
      _Timed('yoga_04_kobra', 30),
      _Timed('yoga_05_kindhaltung', 45),
      _Timed('yoga_14_sitzende_vorbeuge', 45),
      _Timed('yoga_20_totenstellung', 90, rest: 0),
    ],
  ),
  Program(
    name: 'Yoga: Kraft und Balance',
    category: ExerciseCategory.yoga,
    items: [
      _Timed('yoga_12_stuhl', 30),
      _Timed('yoga_07_krieger_1', 30, sides: true),
      _Timed('yoga_08_krieger_2', 30, sides: true),
      _Timed('yoga_09_krieger_3', 20, sides: true),
      _Timed('yoga_10_dreieck', 30, sides: true),
      _Timed('yoga_11_baum', 30, sides: true),
      _Timed('yoga_16_boot', 20),
      _Timed('yoga_15_bruecke', 30),
    ],
  ),
  Program(
    name: 'Dehnen: Nach dem Laufen',
    category: ExerciseCategory.stretching,
    items: [
      _Timed('dehnen_06_wade_wand', 30, sides: true),
      _Timed('dehnen_07_oberschenkel_vorn', 30, sides: true),
      _Timed('dehnen_08_oberschenkel_hinten', 30, sides: true),
      _Timed('dehnen_09_hueftbeuger', 30, sides: true),
      _Timed('dehnen_12_figur_4', 30, sides: true),
      _Timed('dehnen_13_knie_zur_brust', 30),
    ],
  ),
  Program(
    name: 'Dehnen: Schreibtisch-Ausgleich',
    category: ExerciseCategory.stretching,
    items: [
      _Timed('dehnen_01_nacken', 30, sides: true),
      _Timed('dehnen_02_schulter', 30, sides: true),
      _Timed('dehnen_03_trizeps', 30, sides: true),
      _Timed('dehnen_04_brust_wand', 30, sides: true),
      _Timed('dehnen_05_seitbeuge', 30, sides: true),
      _Timed('dehnen_18_nadeloehr', 30, sides: true),
    ],
  ),
  Program(
    name: 'Calisthenics: Grundlagen',
    category: ExerciseCategory.calisthenics,
    rounds: 3,
    items: [
      _Reps('cali_01_liegestuetz', 10, rest: 30),
      _Reps('cali_07_australian_pullup', 8, rest: 30),
      _Reps('cali_09_bank_dips', 10, rest: 30),
      _Timed('cali_10_unterarmstuetz', 30, rest: 30),
      _Reps('cali_17_superman', 12, rest: 60),
    ],
  ),
  Program(
    name: 'Crossfit: Zirkel ohne Geräte',
    category: ExerciseCategory.crossfit,
    rounds: 4,
    items: [
      _Reps('crossfit_01_air_squat', 15, rest: 15),
      _Reps('crossfit_02_burpee', 8, rest: 15),
      _Timed('crossfit_12_mountain_climbers', 30, rest: 15),
      _Reps('crossfit_14_situp', 15, rest: 15),
      _Timed('crossfit_19_hampelmann', 30, rest: 45),
    ],
  ),
  Program(
    name: 'Crossfit: Kettlebell kurz',
    category: ExerciseCategory.crossfit,
    rounds: 3,
    items: [
      _Reps('crossfit_04_kettlebell_swing', 15, rest: 20),
      _Reps('crossfit_09_goblet_squat', 10, rest: 20),
      _Reps('crossfit_18_russian_twist', 20, rest: 20),
      _Timed('crossfit_16_farmers_carry', 40, rest: 60),
    ],
  ),
];

/// Die zweite Lieferung: Programme ohne Geräte, viele davon in zwei
/// Varianten (kurz und lang, leicht und fordernd).
const List<Program> builtinProgramsBatch2 = [
  Program(
    name: 'Yoga: Sonnengruß – 3 Runden',
    category: ExerciseCategory.yoga,
    rounds: 3,
    items: sunSalutation,
  ),
  Program(
    name: 'Yoga: Sonnengruß – 6 Runden',
    category: ExerciseCategory.yoga,
    rounds: 6,
    items: sunSalutation,
  ),
  Program(
    name: 'Yoga: Hüftöffner',
    category: ExerciseCategory.yoga,
    items: [
      _Timed('yoga_19_tiefer_ausfallschritt', 40, sides: true),
      _Timed('yoga_40_halber_spagat', 40, sides: true),
      _Timed('yoga_17_taube', 60, sides: true),
      _Timed('yoga_38_glueckliches_baby', 45),
      _Timed('yoga_39_liegender_schmetterling', 60),
    ],
  ),
  Program(
    name: 'Yoga: Rücken stärken',
    category: ExerciseCategory.yoga,
    items: [
      _Timed('yoga_06_katze_kuh', 45),
      _Timed('yoga_34_sphinx', 40),
      _Timed('yoga_04_kobra', 30),
      _Timed('yoga_31_heuschrecke', 30),
      _Timed('yoga_32_bogen', 25),
      _Timed('yoga_05_kindhaltung', 45),
      _Timed('yoga_15_bruecke', 30),
      _Timed('yoga_36_umgekehrter_tisch', 25),
      _Timed('yoga_05_kindhaltung', 45, rest: 0),
    ],
  ),
  Program(
    name: 'Yoga: Balance',
    category: ExerciseCategory.yoga,
    items: [
      _Timed('yoga_11_baum', 30, sides: true),
      _Timed('yoga_29_adler', 30, sides: true),
      _Timed('yoga_09_krieger_3', 25, sides: true),
      _Timed('yoga_28_halbmond', 25, sides: true),
      _Timed('yoga_30_taenzer', 25, sides: true),
    ],
  ),
  Program(
    name: 'Yoga: Abendruhe',
    category: ExerciseCategory.yoga,
    items: [
      _Timed('yoga_05_kindhaltung', 60),
      _Timed('yoga_14_sitzende_vorbeuge', 60),
      _Timed('yoga_37_kopf_zu_knie', 45, sides: true),
      _Timed('yoga_39_liegender_schmetterling', 90),
      _Timed('yoga_38_glueckliches_baby', 45),
      _Timed('yoga_20_totenstellung', 180, rest: 0),
    ],
  ),
  Program(
    name: 'Crossfit: Ohne Geräte – leicht',
    category: ExerciseCategory.crossfit,
    rounds: 3,
    items: [
      _Timed('crossfit_19_hampelmann', 30, rest: 30),
      _Reps('crossfit_01_air_squat', 12, rest: 30),
      _Reps('crossfit_30_schultertippen', 16, rest: 30),
      _Reps('crossfit_14_situp', 10, rest: 30),
      _Timed('crossfit_23_kniehebelauf', 20, rest: 45),
    ],
  ),
  Program(
    name: 'Crossfit: Ohne Geräte – fordernd',
    category: ExerciseCategory.crossfit,
    rounds: 5,
    items: [
      _Reps('crossfit_02_burpee', 10, rest: 20),
      _Reps('crossfit_21_strecksprung', 15, rest: 20),
      _Timed('crossfit_12_mountain_climbers', 40, rest: 20),
      _Reps('crossfit_31_klappmesser', 12, rest: 20),
      _Reps('crossfit_22_ausfallschritt_sprung', 16, rest: 45),
    ],
  ),
  Program(
    name: 'Crossfit: Tabata – 4 Minuten',
    category: ExerciseCategory.crossfit,
    rounds: 2,
    items: _tabata,
  ),
  Program(
    name: 'Crossfit: Tabata – 8 Minuten',
    category: ExerciseCategory.crossfit,
    rounds: 4,
    items: _tabata,
  ),
  Program(
    name: 'Crossfit: Rumpf-Zirkel',
    category: ExerciseCategory.crossfit,
    rounds: 3,
    items: [
      _Reps('crossfit_33_fahrrad_crunch', 20, rest: 20),
      _Timed('crossfit_32_flutter_kicks', 30, rest: 20),
      _Reps('crossfit_35_spiderman_stuetz', 12, rest: 20),
      _Reps('crossfit_31_klappmesser', 10, rest: 20),
      _Timed('crossfit_29_plank_jacks', 30, rest: 40),
    ],
  ),
  Program(
    name: 'Calisthenics: Ohne Geräte – Einsteiger',
    category: ExerciseCategory.calisthenics,
    rounds: 3,
    items: [
      _Reps('cali_02_liegestuetz_knie', 8, rest: 40),
      _Reps('cali_34_ausfallschritt_rueckwaerts', 12, rest: 40),
      _Reps('cali_28_vierfuessler_diagonal', 12, rest: 40),
      _Reps('cali_32_einbeinige_bruecke', 10, rest: 40, sides: true),
      _Timed('cali_10_unterarmstuetz', 20, rest: 60),
    ],
  ),
  Program(
    name: 'Calisthenics: Ohne Geräte – Fortgeschritten',
    category: ExerciseCategory.calisthenics,
    rounds: 4,
    items: [
      _Reps('cali_21_breiter_liegestuetz', 12, rest: 45),
      _Reps('cali_04_pike_pushup', 8, rest: 45),
      _Reps('cali_35_kosaken_kniebeuge', 10, rest: 45),
      _Reps('cali_23_hindu_liegestuetz', 8, rest: 45),
      _Timed('cali_40_hohlkoerper_wippe', 30, rest: 45),
      _Reps('cali_15_pistol_squat', 6, rest: 60, sides: true),
    ],
  ),
  Program(
    name: 'Calisthenics: Rumpf – kurz',
    category: ExerciseCategory.calisthenics,
    rounds: 2,
    items: [
      _Reps('cali_29_kaefer', 12, rest: 20),
      _Reps('cali_31_reverse_crunch', 12, rest: 20),
      _Timed('cali_11_seitstuetz', 25, rest: 20, sides: true),
      _Timed('cali_38_baerenstand', 25, rest: 30),
    ],
  ),
  Program(
    name: 'Calisthenics: Rumpf – lang',
    category: ExerciseCategory.calisthenics,
    rounds: 4,
    items: [
      _Reps('cali_29_kaefer', 12, rest: 20),
      _Reps('cali_31_reverse_crunch', 12, rest: 20),
      _Reps('cali_30_beinheben_liegend', 12, rest: 20),
      _Reps('cali_39_seitstuetz_hueftheben', 12, rest: 20, sides: true),
      _Timed('cali_12_hollow_body', 30, rest: 20),
      _Timed('cali_38_baerenstand', 25, rest: 40),
    ],
  ),
  Program(
    name: 'Dehnen: Morgens – kurz',
    category: ExerciseCategory.stretching,
    items: [
      _Timed('dehnen_40_ganzkoerper_strecken', 30),
      _Timed('dehnen_13_knie_zur_brust', 30),
      _Timed('yoga_06_katze_kuh', 40),
      _Timed('dehnen_05_seitbeuge', 30, sides: true),
      _Timed('dehnen_23_brustoeffner', 30),
      _Timed('dehnen_26_oberer_ruecken', 30, rest: 0),
    ],
  ),
  Program(
    name: 'Dehnen: Ganzkörper – lang',
    category: ExerciseCategory.stretching,
    items: [
      _Timed('dehnen_01_nacken', 30, sides: true),
      _Timed('dehnen_21_nacken_vorn', 30),
      _Timed('dehnen_02_schulter', 30, sides: true),
      _Timed('dehnen_23_brustoeffner', 30),
      _Timed('dehnen_27_seitliche_kindhaltung', 30, sides: true),
      _Timed('dehnen_09_hueftbeuger', 40, sides: true),
      _Timed('dehnen_34_beinrueckseite_liegend', 40, sides: true),
      _Timed('dehnen_12_figur_4', 40, sides: true),
      _Timed('dehnen_36_wade_im_hund', 40),
      _Timed('dehnen_14_wirbelsaeule_drehung', 40, sides: true),
    ],
  ),
  Program(
    name: 'Dehnen: Hüfte und Beine',
    category: ExerciseCategory.stretching,
    items: [
      _Timed('dehnen_32_eidechse', 40, sides: true),
      _Timed('dehnen_31_frosch', 60),
      _Timed('yoga_40_halber_spagat', 40, sides: true),
      _Timed('dehnen_30_gesaess_sitzend', 40, sides: true),
      _Timed('dehnen_33_oberschenkel_seitlage', 40, sides: true),
      _Timed('dehnen_38_sprunggelenk', 30),
    ],
  ),
  Program(
    name: 'Dehnen: Nacken und Schultern',
    category: ExerciseCategory.stretching,
    items: [
      _Timed('dehnen_01_nacken', 30, sides: true),
      _Timed('dehnen_22_nacken_drehen', 20),
      _Timed('dehnen_21_nacken_vorn', 30),
      _Timed('dehnen_24_kuhgesicht_arme', 30, sides: true),
      _Timed('dehnen_26_oberer_ruecken', 30),
      _Timed('dehnen_18_nadeloehr', 40, sides: true),
    ],
  ),
];

/// Eine Runde Sonnengruß; die Haltungen gehen ohne Pause ineinander über.
const sunSalutation = [
  _Timed('yoga_01_berghaltung', 10, rest: 0),
  _Timed('yoga_13_stehende_vorbeuge', 15, rest: 0),
  _Timed('yoga_21_halbe_vorbeuge', 10, rest: 0),
  _Timed('yoga_22_brett', 15, rest: 0),
  _Timed('yoga_23_tiefes_brett', 8, rest: 0),
  _Timed('yoga_03_heraufschauender_hund', 12, rest: 0),
  _Timed('yoga_02_herabschauender_hund', 30, rest: 0),
  _Timed('yoga_21_halbe_vorbeuge', 10, rest: 0),
  _Timed('yoga_13_stehende_vorbeuge', 15, rest: 0),
];

/// Vier Übungen zu je 20 Sekunden Belastung und 10 Sekunden Pause.
const _tabata = [
  _Timed('crossfit_23_kniehebelauf', 20, rest: 10),
  _Timed('crossfit_29_plank_jacks', 20, rest: 10),
  _Timed('crossfit_24_anfersen', 20, rest: 10),
  _Timed('crossfit_40_schattenboxen', 20, rest: 10),
];

class _Timed extends ProgramItem {
  const _Timed(String key, int seconds, {int rest = 5, bool sides = false})
      : super(
            exerciseUuid: 'builtin-$key',
            timed: true,
            amount: seconds,
            restS: rest,
            bothSides: sides);
}

class _Reps extends ProgramItem {
  const _Reps(String key, int repetitions,
      {required int rest, bool sides = false})
      : super(
            exerciseUuid: 'builtin-$key',
            timed: false,
            amount: repetitions,
            restS: rest,
            bothSides: sides);
}
