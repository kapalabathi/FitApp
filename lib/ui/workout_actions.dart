import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../export/fit_writer.dart';
import '../export/xml_writers.dart';
import '../strava/strava_api.dart';
import '../strava/strava_service.dart';
import 'format.dart';

enum ExportFormat {
  fit('FIT', 'fit'),
  gpx('GPX', 'gpx'),
  tcx('TCX', 'tcx');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}

/// Schreibt ein Training als Datei und öffnet das Teilen-Menü von Android,
/// über das sie sich speichern oder an eine andere App geben lässt.
Future<void> exportWorkout(
    BuildContext context, AppDatabase db, Workout w, ExportFormat format) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final samples = db.samples(w.id);
    final List<int>? bytes = switch (format) {
      ExportFormat.fit => buildFit(w, samples, db.laps(w.id)),
      ExportFormat.gpx => switch (buildGpx(w, samples)) {
          final gpx? => utf8.encode(gpx),
          null => null,
        },
      ExportFormat.tcx => utf8.encode(buildTcx(w, samples)),
    };
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Dieses Training hat keine Strecke für eine '
              'GPX-Datei.')));
      return;
    }
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(w.startedAt);
    final file = File(p.join((await getTemporaryDirectory()).path,
        'fitapp_${stamp}_${w.sport.id}.${format.extension}'));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: w.title ?? w.sport.label,
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
      say('Die App ist nicht mit Strava verbunden. Die Verbindung richtest '
          'du im Verlauf über das Wolken-Symbol ein.');
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
