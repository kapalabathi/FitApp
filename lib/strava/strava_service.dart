import 'package:http/http.dart' as http;

import '../data/database.dart';
import '../data/models.dart';
import '../export/fit_writer.dart';
import 'strava_api.dart';

/// Erzeugt die Verbindung zu Strava. Tests setzen hier eine Attrappe ein.
StravaApi Function() createStravaApi =
    () => StravaApi(http.Client(), const SecureSecretStore());

/// Unter welcher Sportart Strava ein Training führt und ob es als
/// Indoor-Training gilt.
({String type, bool trainer}) stravaSport(Sport sport) => switch (sport) {
      Sport.running => (type: 'Run', trainer: false),
      Sport.treadmill => (type: 'Run', trainer: true),
      Sport.indoorBike => (type: 'Ride', trainer: true),
      Sport.skiErg => (type: 'NordicSki', trainer: true),
      Sport.hiking => (type: 'Hike', trainer: false),
      Sport.cycling => (type: 'Ride', trainer: false),
      Sport.yoga => (type: 'Yoga', trainer: false),
      Sport.crossfit => (type: 'Crossfit', trainer: false),
      Sport.calisthenics ||
      Sport.stretching ||
      Sport.other =>
        (type: 'Workout', trainer: false),
    };

/// Die Sportart der App zu einer Strava-Aktivität.
Sport sportFromStrava(String? type, {required bool trainer}) => switch (type) {
      'Run' || 'VirtualRun' || 'TrailRun' =>
        trainer || type == 'VirtualRun' ? Sport.treadmill : Sport.running,
      'Walk' || 'Hike' => Sport.hiking,
      'Ride' || 'VirtualRide' when trainer || type == 'VirtualRide' =>
        Sport.indoorBike,
      'Ride' => Sport.cycling,
      'NordicSki' when trainer => Sport.skiErg,
      'Yoga' => Sport.yoga,
      'Crossfit' => Sport.crossfit,
      _ => Sport.other,
    };

/// Eine Aktivität bei Strava, so weit die App sie braucht.
/// Das Ergebnis eines Uploads mehrerer Trainings.
class StravaBatchResult {
  const StravaBatchResult({
    required this.uploaded,
    required this.skipped,
    required this.failed,
    this.firstError,
  });

  final int uploaded;

  /// Schon hochgeladen oder bei Strava schon ähnlich vorhanden.
  final int skipped;
  final int failed;
  final String? firstError;

  String get summary => [
        '$uploaded hochgeladen',
        if (skipped > 0) '$skipped übersprungen',
        if (failed > 0) '$failed fehlgeschlagen',
      ].join(', ');
}

class StravaActivity {
  StravaActivity(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String? ?? '',
        type = (json['sport_type'] ?? json['type']) as String?,
        trainer = json['trainer'] == true,
        start = DateTime.parse(json['start_date'] as String).toLocal(),
        elapsedS = (json['elapsed_time'] as num?)?.toInt() ?? 0,
        ascentM = (json['total_elevation_gain'] as num?)?.round(),
        externalId = json['external_id'] as String?;

  final int id;
  final String name;
  final String? type;
  final bool trainer;
  final DateTime start;
  final int elapsedS;
  final int? ascentM;

  /// Die Kennung, die das hochladende Programm vergeben hat.
  final String? externalId;

  DateTime get end => start.add(Duration(seconds: elapsedS));
}

/// Verbindet die Trainings der App mit Strava.
class StravaService {
  StravaService(this.db, this.api, {this.pollDelay = const Duration(seconds: 2)});

  /// So kennzeichnet die App ihre Uploads, um sie beim Import zu erkennen.
  static const externalIdPrefix = 'fitapp-';
  static const autoUploadKey = 'strava.autoUpload';
  static const _lastImportKey = 'strava.lastImport';

  /// Ohne früheren Import reicht der erste so weit zurück.
  static const _firstImportSpan = Duration(days: 30);
  static const _maxPolls = 15;

  /// So weit vor und nach einem Training wird bei Strava nach ähnlichen
  /// Aktivitäten gesucht.
  static const _similarWindow = Duration(hours: 2);

  final AppDatabase db;
  final StravaApi api;
  final Duration pollDelay;

  /// Eine Aktivität bei Strava, die sich zeitlich mit dem Training
  /// überschneidet, oder `null` (Lastenheft A-067).
  Future<StravaActivity?> similarActivity(Workout w) async {
    final start = w.startedAt;
    final end = start.add(Duration(seconds: w.durationS));
    final nearby = await api.activities(
      after: start.subtract(_similarWindow),
      before: end.add(_similarWindow),
    );
    for (final json in nearby) {
      final a = StravaActivity(json);
      if (a.start.isBefore(end) && a.end.isAfter(start)) return a;
    }
    return null;
  }

  /// Lädt ein Training hoch, wartet auf die Verarbeitung und merkt sich die
  /// Nummer der Aktivität. Gibt sie zurück.
  Future<int> upload(Workout w) async {
    final sport = stravaSport(w.sport);
    final uploadId = await api.upload(
      fit: buildFit(w, db.samples(w.id), db.laps(w.id)),
      name: w.title ?? w.sport.label,
      sportType: sport.type,
      trainer: sport.trainer,
      externalId: '$externalIdPrefix${w.uuid}',
      description: w.notes,
    );
    for (var i = 0; i < _maxPolls; i++) {
      await Future<void>.delayed(pollDelay);
      final status = await api.uploadStatus(uploadId);
      if (status.error != null) {
        throw StravaException('Strava lehnt die Datei ab: ${status.error}');
      }
      final activityId = status.activityId;
      if (activityId != null) {
        db.setStravaId(w.id, activityId);
        return activityId;
      }
    }
    throw const StravaException(
        'Strava verarbeitet den Upload noch. Die Aktivität erscheint dort '
        'voraussichtlich in Kürze.');
  }

  /// Lädt mehrere Trainings nacheinander hoch. Übersprungen werden, die
  /// schon bei Strava liegen oder dort eine ähnliche Aktivität haben; so
  /// entstehen keine Doppelten. Ein Fehler hält die übrigen nicht auf.
  Future<StravaBatchResult> uploadMany(
    List<Workout> workouts, {
    void Function(int done, int total)? onProgress,
  }) async {
    var uploaded = 0;
    var skipped = 0;
    var failed = 0;
    String? firstError;
    for (var i = 0; i < workouts.length; i++) {
      onProgress?.call(i, workouts.length);
      final w = workouts[i];
      try {
        if (w.stravaId != null || await similarActivity(w) != null) {
          skipped++;
          continue;
        }
        await upload(w);
        uploaded++;
      } on StravaException catch (e) {
        failed++;
        firstError ??= e.message;
      }
    }
    onProgress?.call(workouts.length, workouts.length);
    return StravaBatchResult(
      uploaded: uploaded,
      skipped: skipped,
      failed: failed,
      firstError: firstError,
    );
  }

  /// Holt Aktivitäten, die die App noch nicht kennt, mit Strecke und Puls.
  /// Eigene Uploads werden übersprungen. Gibt die Anzahl der neuen zurück.
  Future<int> importNew() async {
    final now = DateTime.now();
    final last = int.tryParse(db.setting(_lastImportKey) ?? '');
    final after = last == null
        ? now.subtract(_firstImportSpan)
        // Ein Tag Überlappung, falls eine Aktivität verspätet bei Strava
        // angekommen ist.
        : DateTime.fromMillisecondsSinceEpoch(last)
            .subtract(const Duration(days: 1));
    final known = db.stravaIds();
    var imported = 0;
    for (final json in await api.activities(after: after)) {
      final a = StravaActivity(json);
      if (known.contains(a.id) ||
          (a.externalId ?? '').startsWith(externalIdPrefix)) {
        continue;
      }
      db.importWorkout(
        sport: sportFromStrava(a.type, trainer: a.trainer),
        startedAt: a.start,
        title: a.name,
        ascentM: a.ascentM,
        stravaId: a.id,
        samples: samplesFromStreams(await api.streams(a.id), a.elapsedS),
      );
      imported++;
    }
    db.setSetting(_lastImportKey, '${now.millisecondsSinceEpoch}');
    return imported;
  }
}

/// Baut aus den Messreihen von Strava die Messpunkte der App. Fehlen die
/// Messreihen (etwa bei von Hand eingetragenen Aktivitäten), entsteht ein
/// einzelner Punkt am Ende, damit die Dauer erhalten bleibt.
List<Sample> samplesFromStreams(Map<String, List<dynamic>> streams, int elapsedS) {
  final time = streams['time'] ?? const [];
  if (time.isEmpty) {
    return [if (elapsedS > 0) Sample(t: elapsedS)];
  }
  T? at<T>(String key, int i, T Function(num) convert) {
    final list = streams[key];
    final value = list != null && i < list.length ? list[i] : null;
    return value is num ? convert(value) : null;
  }

  return [
    for (var i = 0; i < time.length; i++)
      Sample(
        // Strava zählt ab 0, die App ab 1.
        t: (time[i] as num).toInt() + 1,
        heartRate: at('heartrate', i, (v) => v.round()),
        speedKmh: at('velocity_smooth', i, (v) => v * 3.6),
        cadence: at('cadence', i, (v) => v.toDouble()),
        power: at('watts', i, (v) => v.round()),
        distanceM: at('distance', i, (v) => v.toDouble()),
        altitudeM: at('altitude', i, (v) => v.toDouble()),
        latitude: _coordinate(streams['latlng'], i, 0),
        longitude: _coordinate(streams['latlng'], i, 1),
      ),
  ];
}

double? _coordinate(List<dynamic>? latlng, int i, int part) {
  if (latlng == null || i >= latlng.length) return null;
  final pair = latlng[i];
  return pair is List && pair.length == 2 ? (pair[part] as num).toDouble() : null;
}
