import 'program_models.dart';

/// Mitgelieferte Programme zum Ausprobieren (Lastenheft A-044).
/// Die Übungen sind über den Dateinamen ihrer Grafik benannt.
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
    rounds: 2,
    items: [
      _Timed('yoga_12_stuhl', 30),
      _Timed('yoga_07_krieger_1', 30),
      _Timed('yoga_08_krieger_2', 30),
      _Timed('yoga_09_krieger_3', 20),
      _Timed('yoga_10_dreieck', 30),
      _Timed('yoga_11_baum', 30),
      _Timed('yoga_16_boot', 20),
      _Timed('yoga_15_bruecke', 30),
    ],
  ),
  Program(
    name: 'Dehnen: Nach dem Laufen',
    category: ExerciseCategory.stretching,
    rounds: 2,
    items: [
      _Timed('dehnen_06_wade_wand', 30),
      _Timed('dehnen_07_oberschenkel_vorn', 30),
      _Timed('dehnen_08_oberschenkel_hinten', 30),
      _Timed('dehnen_09_hueftbeuger', 30),
      _Timed('dehnen_12_figur_4', 30),
      _Timed('dehnen_13_knie_zur_brust', 30),
    ],
  ),
  Program(
    name: 'Dehnen: Schreibtisch-Ausgleich',
    category: ExerciseCategory.stretching,
    rounds: 2,
    items: [
      _Timed('dehnen_01_nacken', 30),
      _Timed('dehnen_02_schulter', 30),
      _Timed('dehnen_03_trizeps', 30),
      _Timed('dehnen_04_brust_wand', 30),
      _Timed('dehnen_05_seitbeuge', 30),
      _Timed('dehnen_18_nadeloehr', 30),
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

class _Timed extends ProgramItem {
  const _Timed(String key, int seconds, {int rest = 5})
      : super(
            exerciseUuid: 'builtin-$key',
            timed: true,
            amount: seconds,
            restS: rest);
}

class _Reps extends ProgramItem {
  const _Reps(String key, int repetitions, {required int rest})
      : super(
            exerciseUuid: 'builtin-$key',
            timed: false,
            amount: repetitions,
            restS: rest);
}
