import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../export/fit_writer.dart';
import '../export/xml_writers.dart';
import '../gps/phone_gps.dart';
import '../import/file_import.dart';
import '../strava/strava_api.dart';
import '../strava/strava_service.dart';
import 'format.dart';

enum ExportFormat {
  fit('FIT', 'fit'),

  /// Wie [fit], aber Trainings ohne Strecke bekommen den gemerkten
  /// Trainingsort als Standort. Gedacht für Programme, die nur Dateien mit
  /// Standort annehmen.
  fitWithLocation('FIT mit Trainingsort', 'fit'),
  gpx('GPX', 'gpx'),
  tcx('TCX', 'tcx');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}

/// Der Inhalt der Exportdatei eines Trainings, oder `null`, wenn es sich in
/// diesem Format nicht darstellen lässt (GPX ohne Strecke).
List<int>? exportBytes(AppDatabase db, Workout w, ExportFormat format) {
  final samples = db.samples(w.id);
  return switch (format) {
    ExportFormat.fit => buildFit(w, samples, db.laps(w.id)),
    ExportFormat.fitWithLocation => buildFit(w, samples, db.laps(w.id),
        fixedLocation: trainingLocation(db)),
    ExportFormat.gpx => switch (buildGpx(w, samples)) {
        final gpx? => utf8.encode(gpx),
        null => null,
      },
    ExportFormat.tcx => utf8.encode(buildTcx(w, samples)),
  };
}

const _locationLatKey = 'export.locationLat';
const _locationLonKey = 'export.locationLon';

/// Der gemerkte Ort, an dem die Trainingsgeräte stehen, oder `null`.
({double latitude, double longitude})? trainingLocation(AppDatabase db) {
  final lat = double.tryParse(db.setting(_locationLatKey) ?? '');
  final lon = double.tryParse(db.setting(_locationLonKey) ?? '');
  return lat == null || lon == null ? null : (latitude: lat, longitude: lon);
}

/// Merkt sich den aktuellen Standort des Geräts als Trainingsort. Gibt
/// `null` zurück, wenn das geklappt hat, sonst den Grund.
Future<String?> rememberTrainingLocation(AppDatabase db) async {
  final problem = await PhoneGps.prepare();
  if (problem != null) return problem;
  try {
    final here = await PhoneGps.current();
    db
      ..setSetting(_locationLatKey, '${here.latitude}')
      ..setSetting(_locationLonKey, '${here.longitude}');
    return null;
  } catch (e) {
    return 'Der Standort ließ sich nicht bestimmen: $e';
  }
}

/// Der Dateiname eines exportierten Trainings. Die Nummer am Ende hält die
/// Namen auseinander, wenn zwei Trainings in derselben Minute begonnen haben.
String exportFileName(Workout w, ExportFormat format) {
  final stamp = DateFormat('yyyy-MM-dd_HHmm').format(w.startedAt);
  final suffix = format == ExportFormat.fitWithLocation ? '_ort' : '';
  return 'fitapp_${stamp}_${w.sport.id}_${w.id}$suffix.${format.extension}';
}

/// Schreibt Trainings als Dateien und öffnet das Teilen-Menü von Android,
/// über das sie sich speichern oder an eine andere App geben lassen.
Future<void> exportWorkouts(BuildContext context, AppDatabase db,
    List<Workout> workouts, ExportFormat format) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (format == ExportFormat.fitWithLocation &&
        trainingLocation(db) == null) {
      // Beim ersten Mal wird der Ort festgelegt, an dem das Gerät gerade
      // ist; danach gilt er für alle weiteren Exporte.
      final problem = await rememberTrainingLocation(db);
      if (problem != null) {
        messenger.showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
      messenger.showSnackBar(const SnackBar(
          content: Text('Aktueller Standort als Trainingsort gemerkt.')));
    }
    final directory = (await getTemporaryDirectory()).path;
    final files = <XFile>[];
    for (final w in workouts) {
      final bytes = exportBytes(db, w, format);
      if (bytes == null) continue;
      final file = File(p.join(directory, exportFileName(w, format)));
      await file.writeAsBytes(bytes);
      files.add(XFile(file.path));
    }
    final skipped = workouts.length - files.length;
    if (files.isEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text(workouts.length == 1
              ? 'Dieses Training hat keine Strecke für eine GPX-Datei.'
              : 'Keines der Trainings hat eine Strecke für eine GPX-Datei.')));
      return;
    }
    if (skipped > 0) {
      messenger.showSnackBar(SnackBar(
          content: Text('$skipped ohne Strecke ausgelassen; '
              '${files.length} werden exportiert.')));
    }
    await SharePlus.instance.share(ShareParams(
      files: files,
      subject: workouts.length == 1
          ? workouts.single.title ?? workouts.single.sport.label
          : '${files.length} Trainings aus FitApp',
    ));
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')));
  }
}

/// Lädt ein Training zu Strava hoch. Liegt dort schon eine ähnliche
/// Aktivität, fragt die App vorher nach (Lastenheft A-067); mit
/// [askOnSimilar] `false` unterbleibt der Upload dann stattdessen.
///
/// Gibt zurück, ob hochgeladen wurde.
Future<bool> uploadToStrava(
  BuildContext context,
  AppDatabase db,
  Workout w, {
  bool askOnSimilar = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));
  final service = StravaService(db, createStravaApi());
  try {
    if (!await service.api.isConnected) {
      say('Die App ist nicht mit Strava verbunden. Ohne Strava-Abo geht es '
          'so: als FIT exportieren und bei Strava von Hand hochladen.');
      return false;
    }
    final similar = await service.similarActivity(w);
    if (similar != null) {
      final what = '„${similar.name}" vom ${formatDateTime(similar.start)}';
      if (!askOnSimilar) {
        say('Nicht automatisch hochgeladen: Bei Strava liegt schon $what.');
        return false;
      }
      if (!context.mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ähnliche Aktivität bei Strava'),
          content: Text('Bei Strava liegt im selben Zeitraum schon $what. '
              'Trotzdem hochladen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nicht hochladen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trotzdem hochladen'),
            ),
          ],
        ),
      );
      if (proceed != true) return false;
    }
    say('Lade zu Strava hoch …');
    await service.upload(w);
    say('Bei Strava hochgeladen.');
    return true;
  } on StravaException catch (e) {
    say(e.message);
  } catch (e) {
    say('Upload fehlgeschlagen: $e');
  }
  return false;
}

/// Lädt ein eben beendetes Training hoch, wenn der Nutzer das so
/// eingestellt hat (Lastenheft A-065).
Future<void> autoUploadIfEnabled(
    BuildContext context, AppDatabase db, Workout w) async {
  if (!db.flag(StravaService.autoUploadKey, fallback: false)) return;
  await uploadToStrava(context, db, w, askOnSimilar: false);
}

/// Das Ergebnis eines Datei-Imports, als Satz für den Nutzer.
class ImportSummary {
  int imported = 0;
  int duplicates = 0;
  final List<String> failures = [];

  String get message => [
        imported == 1 ? '1 Training importiert' : '$imported Trainings importiert',
        if (duplicates > 0) '$duplicates schon vorhanden',
        if (failures.isNotEmpty) 'nicht lesbar: ${failures.join('; ')}',
      ].join(', ');
}

/// Übernimmt eine gelesene Datei als Training, sofern es nicht schon eines
/// mit demselben Beginn gibt.
void importParsedFile(
    AppDatabase db, String name, List<int> bytes, ImportSummary summary) {
  try {
    final activity = parseActivityFile(name, Uint8List.fromList(bytes));
    if (db.hasWorkoutNear(activity.startedAt)) {
      summary.duplicates++;
      return;
    }
    db.importWorkout(
      sport: activity.sport,
      startedAt: activity.startedAt,
      title: activity.title ?? '',
      samples: activity.samples,
      ascentM: activity.ascentM,
    );
    summary.imported++;
  } on ImportException catch (e) {
    summary.failures.add('$name (${e.message})');
  }
}

/// Lässt den Nutzer FIT-, GPX- und TCX-Dateien wählen und übernimmt sie als
/// Trainings (Lastenheft A-063). Gibt zurück, ob etwas importiert wurde.
Future<bool> importFiles(BuildContext context, AppDatabase db) async {
  final messenger = ScaffoldMessenger.of(context);
  final summary = ImportSummary();
  try {
    final files = await FilePicker.pickFiles(
        dialogTitle: 'FIT-, GPX- oder TCX-Dateien wählen');
    if (files.isEmpty) return false;
    for (final file in files) {
      importParsedFile(db, file.name, await file.readAsBytes(), summary);
    }
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: $e')));
    return false;
  }
  messenger.showSnackBar(SnackBar(
    content: Text(summary.message),
    duration: Duration(seconds: summary.failures.isEmpty ? 4 : 10),
  ));
  return summary.imported > 0;
}
