import 'package:flutter/material.dart';

import '../ble/device_kind.dart';
import '../breath/breath_models.dart';
import '../breath/breath_run.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../interval/signals.dart';
import '../programs/program_models.dart';
import '../programs/program_run.dart';
import '../session/workout_session.dart';
import 'breath_player_page.dart';
import 'program_player_page.dart';
import 'workout_actions.dart';
import 'workout_detail_page.dart';

/// Ob der Nutzer das längere Anhalten des Atems freigeschaltet hat (I-052).
const breathHoldsKey = 'breath.holdsAllowed';

/// Die Pulssensoren, die bei [sport] zuletzt mitliefen; beim ersten Mal
/// alle gemerkten.
List<SavedDevice> heartRateSensors(AppDatabase db, Sport sport) {
  final sensors =
      db.devices().where((d) => d.kind == DeviceKind.heartRate).toList();
  final chosen = db.devicesForSport(sport);
  final used = sensors.where((d) => chosen.contains(d.deviceId)).toList();
  return used.isEmpty ? sensors : used;
}

/// Spielt [program] als Training ab. Gibt das gespeicherte Training zurück,
/// mit [title] als Titel, oder `null`, wenn nichts aufgezeichnet wurde.
Future<Workout?> playProgram(
  BuildContext context,
  AppDatabase db,
  Program program, {
  required List<SavedDevice> devices,
  String? title,
}) async {
  final exercises = {for (final e in db.exercises()) e.uuid: e};
  final session = WorkoutSession(
    db: db,
    sport: program.category.sport,
    devices: devices,
    program: ProgramRun(program, exercises),
    signals: createSignals(SignalSettings.load(db)),
  );
  final workout = await Navigator.of(context).push<Workout?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProgramPlayerPage(session: session),
    ),
  );
  return workout == null ? null : _titled(db, workout, title);
}

/// Führt durch eine Atemübung und speichert sie als Yoga-Training.
Future<Workout?> playBreath(
  BuildContext context,
  AppDatabase db,
  BreathExercise exercise, {
  required int minutes,
  required List<SavedDevice> devices,
}) async {
  final session = WorkoutSession(
    db: db,
    sport: Sport.yoga,
    devices: devices,
    breath: BreathRun(
      exercise,
      minutes: minutes,
      holdsAllowed: db.flag(breathHoldsKey, fallback: false),
    ),
    signals: createSignals(SignalSettings.load(db)),
  );
  final workout = await Navigator.of(context).push<Workout?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BreathPlayerPage(session: session),
    ),
  );
  return workout == null
      ? null
      : _titled(db, workout, 'Atemübung: ${exercise.name}');
}

Workout _titled(AppDatabase db, Workout workout, String? title) {
  if (title == null) return workout;
  db.updateWorkout(workout.id,
      title: title, sport: workout.sport, notes: workout.notes ?? '');
  return db.workout(workout.id) ?? workout;
}

/// Nach dem Speichern: Verlauf auffrischen, bei Bedarf hochladen und das
/// Training zeigen.
Future<void> showSavedWorkout(BuildContext context, AppDatabase db,
    Workout workout, VoidCallback onWorkoutSaved) async {
  onWorkoutSaved();
  autoUploadIfEnabled(context, db, workout);
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => WorkoutDetailPage(db: db, workoutId: workout.id),
  ));
}

/// Fragt vor dem ersten längeren Anhalten des Atems nach (I-052). Gibt
/// zurück, ob es danach freigeschaltet ist.
Future<bool> confirmBreathHolds(BuildContext context, AppDatabase db) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('Atemanhalten freischalten?'),
      content: const Text(
        'Einige Atemübungen halten den Atem mehrere Sekunden an. Das ist '
        'nichts für den Einstieg: Erst üben, wenn ruhiges, tiefes Ein- und '
        'Ausatmen ohne Ruck gelingt.\n\n'
        'Nicht anhalten bei hohem Blutdruck, Herz- oder Lungenbeschwerden, '
        'Epilepsie oder in der Schwangerschaft. Wird es eng, schwindelig '
        'oder entsteht Druck im Kopf, sofort normal weiteratmen.\n\n'
        'Ohne Freischaltung lässt die App das Anhalten einfach weg.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Nicht freischalten'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Verstanden, freischalten'),
        ),
      ],
    ),
  );
  if (confirmed == true) db.setFlag(breathHoldsKey, true);
  return confirmed == true;
}
