import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../ble/device_kind.dart';
import '../interval/interval_models.dart';
import 'models.dart';

/// Lokale Datenbank der App: Trainings, Messwerte, gemerkte Geräte,
/// Intervall-Vorlagen und Einstellungen.
class AppDatabase {
  AppDatabase(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
    _migrate();
  }

  factory AppDatabase.inMemory() => AppDatabase(sqlite3.openInMemory());

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final db = sqlite3.open(p.join(dir.path, 'fitapp.db'));
    // Übersteht einen Absturz mitten im Schreiben, siehe Lastenheft A-024.
    db.execute('PRAGMA journal_mode = WAL');
    return AppDatabase(db);
  }

  final Database _db;

  void close() => _db.close();

  void _migrate() {
    final version = _db.select('PRAGMA user_version').first.values.first as int;
    if (version < 1) {
      _db.execute('''
        CREATE TABLE workouts (
          id INTEGER PRIMARY KEY,
          uuid TEXT NOT NULL UNIQUE,
          sport TEXT NOT NULL,
          title TEXT,
          started_at INTEGER NOT NULL,
          duration_s INTEGER NOT NULL DEFAULT 0,
          distance_m REAL NOT NULL DEFAULT 0,
          avg_hr INTEGER,
          max_hr INTEGER,
          avg_power INTEGER,
          max_power INTEGER,
          avg_cadence INTEGER,
          energy_kcal INTEGER,
          status TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0
        )''');
      _db.execute('''
        CREATE TABLE samples (
          workout_id INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
          t INTEGER NOT NULL,
          hr INTEGER,
          speed REAL,
          cadence REAL,
          power INTEGER,
          distance REAL,
          incline REAL,
          resistance REAL,
          PRIMARY KEY (workout_id, t)
        ) WITHOUT ROWID''');
      _db.execute('''
        CREATE TABLE devices (
          device_id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          kind TEXT NOT NULL,
          added_at INTEGER NOT NULL
        )''');
      _db.execute('''
        CREATE TABLE sport_devices (
          sport TEXT NOT NULL,
          device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
          PRIMARY KEY (sport, device_id)
        ) WITHOUT ROWID''');
      _db.execute('PRAGMA user_version = 1');
    }
    if (version < 2) {
      _db.execute('''
        CREATE TABLE interval_templates (
          id INTEGER PRIMARY KEY,
          uuid TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          target_kind TEXT NOT NULL,
          blocks TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0
        )''');
      _db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        ) WITHOUT ROWID''');
      _exampleTemplates.forEach(saveIntervalTemplate);
      _db.execute('PRAGMA user_version = 2');
    }
  }

  /// Zum Ausprobieren und als Muster für eigene Vorlagen.
  static const _exampleTemplates = [
    IntervalTemplate(
      name: 'Lauf-Intervalle 5 × 2 min',
      targetKind: TargetKind.speed,
      blocks: [
        IntervalBlock(steps: [
          IntervalStep(label: 'Einlaufen', durationS: 300, target: 7),
        ]),
        IntervalBlock(repeat: 5, steps: [
          IntervalStep(label: 'Schnell', durationS: 120, target: 11),
          IntervalStep(label: 'Locker', durationS: 60, target: 7),
        ]),
        IntervalBlock(steps: [
          IntervalStep(label: 'Auslaufen', durationS: 300, target: 6),
        ]),
      ],
    ),
    IntervalTemplate(
      name: 'Tabata 8 × 20/10',
      blocks: [
        IntervalBlock(repeat: 8, steps: [
          IntervalStep(label: 'Belastung', durationS: 20),
          IntervalStep(label: 'Pause', durationS: 10),
        ]),
      ],
    ),
  ];

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static String _newUuid() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // --- Trainings ---

  /// Legt ein laufendes Training an und gibt dessen Nummer zurück.
  int startWorkout(Sport sport, DateTime startedAt) {
    _db.execute(
      'INSERT INTO workouts (uuid, sport, started_at, status, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        _newUuid(),
        sport.id,
        startedAt.millisecondsSinceEpoch,
        WorkoutStatus.recording.id,
        _now(),
      ],
    );
    return _db.lastInsertRowId;
  }

  void addSample(int workoutId, Sample s) {
    _db.execute(
      'INSERT OR REPLACE INTO samples '
      '(workout_id, t, hr, speed, cadence, power, distance, incline, resistance) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        workoutId,
        s.t,
        s.heartRate,
        s.speedKmh,
        s.cadence,
        s.power,
        s.distanceM,
        s.incline,
        s.resistance,
      ],
    );
  }

  /// Schließt ein Training ab; die Kennzahlen werden aus den Messwerten
  /// berechnet. Ein Training ohne Messwerte wird verworfen.
  ///
  /// Gibt zurück, ob das Training erhalten blieb.
  bool finishWorkout(
    int workoutId, {
    int? energyKcal,
    WorkoutStatus status = WorkoutStatus.finished,
  }) {
    final row = _db.select(
      'SELECT COUNT(*) AS n, MAX(t) AS duration, MAX(distance) AS distance, '
      'AVG(hr) AS avg_hr, MAX(hr) AS max_hr, '
      'AVG(power) AS avg_power, MAX(power) AS max_power, '
      'AVG(NULLIF(cadence, 0)) AS avg_cadence '
      'FROM samples WHERE workout_id = ?',
      [workoutId],
    ).first;
    if (row['n'] == 0) {
      _db.execute('DELETE FROM workouts WHERE id = ?', [workoutId]);
      return false;
    }
    int? round(Object? v) => (v as num?)?.round();
    _db.execute(
      'UPDATE workouts SET duration_s = ?, distance_m = ?, avg_hr = ?, '
      'max_hr = ?, avg_power = ?, max_power = ?, avg_cadence = ?, '
      'energy_kcal = ?, status = ?, updated_at = ? WHERE id = ?',
      [
        row['duration'],
        (row['distance'] as num?)?.toDouble() ?? 0,
        round(row['avg_hr']),
        round(row['max_hr']),
        round(row['avg_power']),
        round(row['max_power']),
        round(row['avg_cadence']),
        energyKcal,
        status.id,
        _now(),
        workoutId,
      ],
    );
    return true;
  }

  /// Schließt Trainings ab, die beim letzten Lauf der App nicht beendet wurden.
  /// Gibt deren Anzahl zurück.
  int recoverUnfinished() {
    final rows = _db.select(
        'SELECT id FROM workouts WHERE status = ?', [WorkoutStatus.recording.id]);
    var kept = 0;
    for (final row in rows) {
      if (finishWorkout(row['id'] as int, status: WorkoutStatus.recovered)) {
        kept++;
      }
    }
    return kept;
  }

  /// Abgeschlossene Trainings, neueste zuerst.
  List<Workout> workouts({Sport? sport, DateTime? since}) {
    final where = ['deleted = 0', 'status != ?'];
    final args = <Object?>[WorkoutStatus.recording.id];
    if (sport != null) {
      where.add('sport = ?');
      args.add(sport.id);
    }
    if (since != null) {
      where.add('started_at >= ?');
      args.add(since.millisecondsSinceEpoch);
    }
    return _db
        .select(
          'SELECT * FROM workouts WHERE ${where.join(' AND ')} '
          'ORDER BY started_at DESC',
          args,
        )
        .map(_workout)
        .toList();
  }

  Workout? workout(int id) {
    final rows = _db.select('SELECT * FROM workouts WHERE id = ?', [id]);
    return rows.isEmpty ? null : _workout(rows.first);
  }

  List<Sample> samples(int workoutId) => _db
      .select('SELECT * FROM samples WHERE workout_id = ? ORDER BY t',
          [workoutId])
      .map((r) => Sample(
            t: r['t'] as int,
            heartRate: r['hr'] as int?,
            speedKmh: (r['speed'] as num?)?.toDouble(),
            cadence: (r['cadence'] as num?)?.toDouble(),
            power: r['power'] as int?,
            distanceM: (r['distance'] as num?)?.toDouble(),
            incline: (r['incline'] as num?)?.toDouble(),
            resistance: (r['resistance'] as num?)?.toDouble(),
          ))
      .toList();

  /// Markiert ein Training als gelöscht. Die Zeile bleibt für die spätere
  /// Synchronisation erhalten, die Messwerte werden entfernt.
  void deleteWorkout(int id) {
    _db.execute('DELETE FROM samples WHERE workout_id = ?', [id]);
    _db.execute('UPDATE workouts SET deleted = 1, updated_at = ? WHERE id = ?',
        [_now(), id]);
  }

  Workout _workout(Row r) => Workout(
        id: r['id'] as int,
        uuid: r['uuid'] as String,
        sport: Sport.fromId(r['sport'] as String),
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        status: WorkoutStatus.fromId(r['status'] as String),
        title: r['title'] as String?,
        durationS: r['duration_s'] as int,
        distanceM: (r['distance_m'] as num).toDouble(),
        avgHeartRate: r['avg_hr'] as int?,
        maxHeartRate: r['max_hr'] as int?,
        avgPower: r['avg_power'] as int?,
        maxPower: r['max_power'] as int?,
        avgCadence: r['avg_cadence'] as int?,
        energyKcal: r['energy_kcal'] as int?,
      );

  // --- Intervall-Vorlagen ---

  List<IntervalTemplate> intervalTemplates() => _db
      .select('SELECT * FROM interval_templates WHERE deleted = 0 '
          'ORDER BY name COLLATE NOCASE')
      .map((r) => IntervalTemplate(
            id: r['id'] as int,
            name: r['name'] as String,
            targetKind: TargetKind.fromId(r['target_kind'] as String),
            blocks: IntervalTemplate.blocksFromJson(r['blocks'] as String),
          ))
      .toList();

  /// Speichert eine neue oder geänderte Vorlage und gibt ihre Nummer zurück.
  int saveIntervalTemplate(IntervalTemplate t) {
    final id = t.id;
    if (id == null) {
      _db.execute(
        'INSERT INTO interval_templates '
        '(uuid, name, target_kind, blocks, updated_at) VALUES (?, ?, ?, ?, ?)',
        [_newUuid(), t.name, t.targetKind.id, t.blocksJson(), _now()],
      );
      return _db.lastInsertRowId;
    }
    _db.execute(
      'UPDATE interval_templates SET name = ?, target_kind = ?, blocks = ?, '
      'updated_at = ? WHERE id = ?',
      [t.name, t.targetKind.id, t.blocksJson(), _now(), id],
    );
    return id;
  }

  /// Markiert eine Vorlage als gelöscht; die Zeile bleibt für die spätere
  /// Synchronisation erhalten.
  void deleteIntervalTemplate(int id) {
    _db.execute(
        'UPDATE interval_templates SET deleted = 1, updated_at = ? WHERE id = ?',
        [_now(), id]);
  }

  // --- Einstellungen ---

  bool flag(String key, {required bool fallback}) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? fallback : rows.first['value'] == '1';
  }

  void setFlag(String key, bool value) {
    _db.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value ? '1' : '0'],
    );
  }

  // --- Geräte ---

  void saveDevice(SavedDevice d) {
    _db.execute(
      'INSERT INTO devices (device_id, name, kind, added_at) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(device_id) DO UPDATE SET name = excluded.name, '
      'kind = excluded.kind',
      [d.deviceId, d.name, d.kind.name, _now()],
    );
  }

  void renameDevice(String deviceId, String name) {
    _db.execute(
        'UPDATE devices SET name = ? WHERE device_id = ?', [name, deviceId]);
  }

  void forgetDevice(String deviceId) {
    _db.execute('DELETE FROM devices WHERE device_id = ?', [deviceId]);
  }

  List<SavedDevice> devices() => _db
      .select('SELECT * FROM devices ORDER BY added_at')
      .map((r) => SavedDevice(
            deviceId: r['device_id'] as String,
            name: r['name'] as String,
            kind: DeviceKind.values.firstWhere((k) => k.name == r['kind'],
                orElse: () => DeviceKind.unknown),
          ))
      .toList();

  /// Die Geräte, die zuletzt für diese Sportart gewählt waren.
  Set<String> devicesForSport(Sport sport) => _db
      .select('SELECT device_id FROM sport_devices WHERE sport = ?', [sport.id])
      .map((r) => r['device_id'] as String)
      .toSet();

  void setDevicesForSport(Sport sport, Iterable<String> deviceIds) {
    _db.execute('DELETE FROM sport_devices WHERE sport = ?', [sport.id]);
    for (final id in deviceIds) {
      _db.execute('INSERT INTO sport_devices (sport, device_id) VALUES (?, ?)',
          [sport.id, id]);
    }
  }
}
