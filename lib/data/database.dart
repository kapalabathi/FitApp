import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../ble/device_kind.dart';
import '../interval/interval_models.dart';
import '../programs/builtin_exercises.dart';
import '../programs/builtin_programs.dart';
import '../programs/program_models.dart';
import '../stats/stats.dart';
import 'models.dart';

/// Lokale Datenbank der App: Trainings, Messwerte, gemerkte Geräte,
/// Intervall-Vorlagen, Übungen, Programme und Einstellungen.
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
    if (version < 3) {
      _db.execute('ALTER TABLE samples ADD COLUMN lat REAL');
      _db.execute('ALTER TABLE samples ADD COLUMN lon REAL');
      _db.execute('ALTER TABLE samples ADD COLUMN altitude REAL');
      _db.execute('ALTER TABLE workouts ADD COLUMN ascent_m INTEGER');
      _db.execute('''
        CREATE TABLE laps (
          workout_id INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
          t INTEGER NOT NULL,
          distance REAL NOT NULL,
          auto INTEGER NOT NULL,
          PRIMARY KEY (workout_id, t)
        ) WITHOUT ROWID''');
      _db.execute('''
        CREATE TABLE exercises (
          id INTEGER PRIMARY KEY,
          uuid TEXT NOT NULL UNIQUE,
          category TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          builtin_key TEXT,
          image_path TEXT,
          timed INTEGER NOT NULL DEFAULT 1,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0
        )''');
      _db.execute('''
        CREATE TABLE programs (
          id INTEGER PRIMARY KEY,
          uuid TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          rounds INTEGER NOT NULL DEFAULT 1,
          items TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0
        )''');
      builtinExercises.where((e) => e.batch == 1).forEach(_insertBuiltin);
      builtinPrograms.forEach(saveProgram);
      _db.execute('PRAGMA user_version = 3');
    }
    if (version < 4) {
      // Spazieren und Wandern sind zu einer Sportart zusammengelegt.
      _db.execute(
        "UPDATE workouts SET sport = 'hiking', updated_at = ? "
        "WHERE sport = 'walking'",
        [_now()],
      );
      _db.execute(
        "INSERT OR IGNORE INTO sport_devices (sport, device_id) "
        "SELECT 'hiking', device_id FROM sport_devices WHERE sport = 'walking'",
      );
      _db.execute("DELETE FROM sport_devices WHERE sport = 'walking'");
      _db.execute('PRAGMA user_version = 4');
    }
    if (version < 5) {
      _db.execute('ALTER TABLE workouts ADD COLUMN notes TEXT');
      // Bestwerte je Training, einmal berechnet. Die Zeile mit der Art
      // 'done' markiert, dass ein Training ausgewertet ist.
      _db.execute('''
        CREATE TABLE best_efforts (
          workout_id INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
          kind TEXT NOT NULL,
          value REAL NOT NULL,
          PRIMARY KEY (workout_id, kind)
        ) WITHOUT ROWID''');
      _db.execute('PRAGMA user_version = 5');
    }
    if (version < 6) {
      _db.execute('ALTER TABLE workouts ADD COLUMN strava_id INTEGER');
      _db.execute(
        'ALTER TABLE workouts ADD COLUMN imported INTEGER NOT NULL DEFAULT 0',
      );
      _db.execute('PRAGMA user_version = 6');
    }
    if (version < 7) {
      // Körperbereiche je Übung; dazu die Erweiterung um 80 Übungen ohne
      // Geräte und weitere Programme.
      _db.execute(
        "ALTER TABLE exercises ADD COLUMN areas TEXT NOT NULL DEFAULT ''",
      );
      for (final e in builtinExercises) {
        // Schon vorhandene Übungen bleiben, wie sie sind, auch gelöschte.
        _insertBuiltin(e);
        // Eigene Angaben des Nutzers gibt es hier noch nicht; die Bereiche
        // werden für alle mitgelieferten Übungen gesetzt.
        _db.execute('UPDATE exercises SET areas = ? WHERE uuid = ?', [
          BodyArea.store(e.areas),
          e.uuid,
        ]);
      }
      builtinProgramsBatch2.forEach(saveProgram);
      _db.execute('PRAGMA user_version = 7');
    }
    if (version < 8) {
      _prepareBuiltinsForSync();
      _db.execute('PRAGMA user_version = 8');
    }
    if (version < 9) {
      _db.execute(
        'ALTER TABLE workouts ADD COLUMN energy_estimated INTEGER NOT NULL DEFAULT 0',
      );
      _db.execute('''
        CREATE TABLE set_logs (
          id INTEGER PRIMARY KEY,
          workout_id INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
          exercise_uuid TEXT NOT NULL,
          t INTEGER NOT NULL,
          reps INTEGER,
          weight_kg REAL,
          seconds INTEGER
        )''');
      _db.execute(
        'CREATE INDEX set_logs_by_exercise ON set_logs (exercise_uuid)',
      );
      _db.execute('PRAGMA user_version = 9');
    }
    if (version < 10) {
      // Angaben für Yoga und Programme: Sanskrit-Name, Gruppe, Stufe,
      // beide Seiten, Hinweis und Varianten (I-046, I-047, I-051, I-052).
      _db.execute(
        "ALTER TABLE exercises ADD COLUMN sanskrit TEXT NOT NULL DEFAULT ''",
      );
      _db.execute('ALTER TABLE exercises ADD COLUMN pose_group TEXT');
      _db.execute(
        'ALTER TABLE exercises ADD COLUMN level INTEGER NOT NULL DEFAULT 0',
      );
      _db.execute(
        'ALTER TABLE exercises '
        'ADD COLUMN both_sides INTEGER NOT NULL DEFAULT 0',
      );
      _db.execute(
        "ALTER TABLE exercises ADD COLUMN caution TEXT NOT NULL DEFAULT ''",
      );
      _db.execute('ALTER TABLE exercises ADD COLUMN easier_uuid TEXT');
      _db.execute('ALTER TABLE exercises ADD COLUMN harder_uuid TEXT');
      // Die neuen Angaben gab es bisher nicht; sie gelten auch für
      // mitgelieferte Übungen, die der Nutzer verändert hat.
      for (final e in builtinExercises) {
        _db.execute(
          'UPDATE exercises SET sanskrit = ?, pose_group = ?, level = ?, '
          'both_sides = ?, caution = ?, easier_uuid = ?, harder_uuid = ? '
          'WHERE uuid = ?',
          [
            e.sanskrit,
            e.poseGroup?.id,
            e.level,
            e.bothSides ? 1 : 0,
            e.caution,
            BuiltinExercise.uuidOf(e.easierKey),
            BuiltinExercise.uuidOf(e.harderKey),
            e.uuid,
          ],
        );
      }
      // Unveränderte mitgelieferte Programme üben einseitige Haltungen
      // jetzt auf beiden Seiten statt in einer zweiten Runde.
      for (final p in [...builtinPrograms, ...builtinProgramsBatch2]) {
        _db.execute(
          'UPDATE programs SET rounds = ?, items = ? '
          'WHERE uuid = ? AND updated_at = ?',
          [p.rounds, p.itemsJson(), 'builtin-program:${p.name}', _pristine],
        );
      }
      _db.execute('PRAGMA user_version = 10');
    }
    if (version < 11) {
      // Dritte Lieferung: die Umkehrhaltungen Pflug, Schulterstand,
      // Unterarmstand und Kopfstand, dazu die neue schwerere Variante des
      // Delfins. Bei neuen Installationen sind sie schon angelegt.
      for (final e in builtinExercises.where((e) => e.batch == 3)) {
        _insertBuiltin(e);
        _db.execute(
          'UPDATE exercises SET areas = ?, sanskrit = ?, pose_group = ?, '
          'level = ?, both_sides = ?, caution = ?, easier_uuid = ?, '
          'harder_uuid = ? WHERE uuid = ? AND updated_at = ?',
          [
            BodyArea.store(e.areas),
            e.sanskrit,
            e.poseGroup?.id,
            e.level,
            e.bothSides ? 1 : 0,
            e.caution,
            BuiltinExercise.uuidOf(e.easierKey),
            BuiltinExercise.uuidOf(e.harderKey),
            e.uuid,
            _pristine,
          ],
        );
      }
      _db.execute(
        'UPDATE exercises SET harder_uuid = ? '
        'WHERE uuid = ? AND harder_uuid IS NULL',
        ['builtin-yoga_44_kopfstand', 'builtin-yoga_35_delfin'],
      );
      _db.execute('PRAGMA user_version = 11');
    }
    if (version < 12) {
      // Vierte Lieferung: 48 Übungen (G-165 bis G-212) und sechs Programme.
      _addNewBuiltinExercises();
      _addBuiltinPrograms(builtinProgramsBatch3);
      _db.execute('PRAGMA user_version = 12');
    }
    if (version < 13) {
      // Protokoll der Verbindungsabbrüche je Training.
      _db.execute('''
        CREATE TABLE IF NOT EXISTS link_losses (
          id INTEGER PRIMARY KEY,
          workout_id INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
          t INTEGER NOT NULL,
          device TEXT NOT NULL,
          reason TEXT,
          down_s INTEGER
        )''');
      _db.execute('PRAGMA user_version = 13');
    }
    if (version < 14) {
      // Glühwürmchen (G-213) als schwerere Variante der Krähe.
      _addNewBuiltinExercises();
      _db.execute('PRAGMA user_version = 14');
    }
    if (version < 15) {
      // Fertige Dehn-Routinen (I-057).
      _addBuiltinPrograms(builtinProgramsBatch4);
      _db.execute('PRAGMA user_version = 15');
    }
    if (version < 16) {
      // Gezielte Auswahl: 24 Übungen (G-214 bis G-237, I-061).
      _addNewBuiltinExercises();
      _db.execute('PRAGMA user_version = 16');
    }
  }

  /// Legt mitgelieferte Programme an, die es noch nicht gibt, gleich mit
  /// ihrer festen Kennung.
  void _addBuiltinPrograms(List<Program> programs) {
    for (final p in programs) {
      final uuid = 'builtin-program:${p.name}';
      if (_db.select('SELECT 1 FROM programs WHERE uuid = ?', [uuid])
          .isNotEmpty) {
        continue;
      }
      _db.execute(
        'INSERT INTO programs (uuid, name, category, rounds, items, '
        'updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [uuid, p.name, p.category.id, p.rounds, p.itemsJson(), _pristine],
      );
    }
  }

  /// Legt mitgelieferte Übungen an, die es hier noch nicht gibt, mit allen
  /// Angaben. Vorhandene Übungen bekommen ihre neuen Varianten, sofern der
  /// Nutzer sie nicht selbst festgelegt hat.
  void _addNewBuiltinExercises() {
    for (final e in builtinExercises) {
      _insertBuiltin(e);
      _db.execute(
        'UPDATE exercises SET areas = ?, sanskrit = ?, pose_group = ?, '
        'level = ?, both_sides = ?, caution = ? '
        "WHERE uuid = ? AND updated_at = ? AND areas = ''",
        [
          BodyArea.store(e.areas),
          e.sanskrit,
          e.poseGroup?.id,
          e.level,
          e.bothSides ? 1 : 0,
          e.caution,
          e.uuid,
          _pristine,
        ],
      );
      for (final (column, key) in [
        ('easier_uuid', e.easierKey),
        ('harder_uuid', e.harderKey),
      ]) {
        if (key == null) continue;
        _db.execute(
          'UPDATE exercises SET $column = ? '
          'WHERE uuid = ? AND (updated_at = ? OR $column IS NULL)',
          [BuiltinExercise.uuidOf(key), e.uuid, _pristine],
        );
      }
    }
  }

  /// Zeitstempel unveränderter mitgelieferter Inhalte. Jede Änderung des
  /// Nutzers ist jünger und setzt sich bei der Synchronisation durch.
  static const _pristine = 0;

  /// Macht mitgelieferte Inhalte auf allen Geräten gleich erkennbar: Solange
  /// der Nutzer sie nicht verändert hat, bekommen sie eine feste Kennung und
  /// den Zeitstempel [_pristine]. Ohne das hätte jedes Gerät eigene Kopien
  /// der mitgelieferten Programme, und sie würden sich bei der
  /// Synchronisation verdoppeln.
  void _prepareBuiltinsForSync() {
    for (final e in builtinExercises) {
      _db.execute(
        'UPDATE exercises SET updated_at = ? WHERE uuid = ? AND deleted = 0 '
        'AND name = ? AND description = ? AND category = ? AND timed = ? '
        'AND areas = ? AND image_path IS NULL',
        [
          _pristine,
          e.uuid,
          e.name,
          e.description,
          e.category.id,
          e.timed ? 1 : 0,
          BodyArea.store(e.areas),
        ],
      );
    }
    for (final p in [...builtinPrograms, ...builtinProgramsBatch2]) {
      _adoptBuiltin(
        'programs',
        'builtin-program:${p.name}',
        'name = ? AND category = ? AND rounds = ? AND items = ?',
        [p.name, p.category.id, p.rounds, p.itemsJson()],
      );
    }
    for (final t in _exampleTemplates) {
      _adoptBuiltin(
        'interval_templates',
        'builtin-interval:${t.name}',
        'name = ? AND target_kind = ? AND blocks = ?',
        [t.name, t.targetKind.id, t.blocksJson()],
      );
    }
  }

  void _adoptBuiltin(
    String table,
    String uuid,
    String unchanged,
    List<Object?> values,
  ) {
    final taken = _db.select('SELECT 1 FROM $table WHERE uuid = ?', [
      uuid,
    ]).isNotEmpty;
    if (taken) return;
    final rows = _db.select(
      'SELECT id FROM $table WHERE deleted = 0 AND $unchanged LIMIT 1',
      values,
    );
    if (rows.isEmpty) return;
    _db.execute('UPDATE $table SET uuid = ?, updated_at = ? WHERE id = ?', [
      uuid,
      _pristine,
      rows.first['id'],
    ]);
  }

  /// Legt eine mitgelieferte Übung an, falls es sie noch nicht gibt. Schreibt
  /// nur die Spalten, die es seit der ersten Fassung der Tabelle gibt, damit
  /// der Aufruf in jeder Stufe des Datenbank-Aufbaus funktioniert.
  void _insertBuiltin(BuiltinExercise e) {
    _db.execute(
      'INSERT OR IGNORE INTO exercises '
      '(uuid, category, name, description, builtin_key, timed, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        e.uuid,
        e.category.id,
        e.name,
        e.description,
        e.key,
        e.timed ? 1 : 0,
        _pristine,
      ],
    );
  }

  /// Zum Ausprobieren und als Muster für eigene Vorlagen.
  static const _exampleTemplates = [
    IntervalTemplate(
      name: 'Lauf-Intervalle 5 × 2 min',
      targetKind: TargetKind.speed,
      blocks: [
        IntervalBlock(
          steps: [IntervalStep(label: 'Einlaufen', durationS: 300, target: 7)],
        ),
        IntervalBlock(
          repeat: 5,
          steps: [
            IntervalStep(label: 'Schnell', durationS: 120, target: 11),
            IntervalStep(label: 'Locker', durationS: 60, target: 7),
          ],
        ),
        IntervalBlock(
          steps: [IntervalStep(label: 'Auslaufen', durationS: 300, target: 6)],
        ),
      ],
    ),
    IntervalTemplate(
      name: 'Tabata 8 × 20/10',
      blocks: [
        IntervalBlock(
          repeat: 8,
          steps: [
            IntervalStep(label: 'Belastung', durationS: 20),
            IntervalStep(label: 'Pause', durationS: 10),
          ],
        ),
      ],
    ),
  ];

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static String _newUuid() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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
      '(workout_id, t, hr, speed, cadence, power, distance, incline, '
      'resistance, lat, lon, altitude) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
        s.latitude,
        s.longitude,
        s.altitudeM,
      ],
    );
  }

  void addLap(int workoutId, Lap lap) {
    _db.execute(
      'INSERT OR REPLACE INTO laps (workout_id, t, distance, auto) '
      'VALUES (?, ?, ?, ?)',
      [workoutId, lap.t, lap.distanceM, lap.auto ? 1 : 0],
    );
  }

  List<Lap> laps(int workoutId) => _db
      .select('SELECT * FROM laps WHERE workout_id = ? ORDER BY t', [workoutId])
      .map(
        (r) => Lap(
          t: r['t'] as int,
          distanceM: (r['distance'] as num).toDouble(),
          auto: r['auto'] == 1,
        ),
      )
      .toList();

  /// Schließt ein Training ab; die Kennzahlen werden aus den Messwerten
  /// berechnet. Ein Training ohne Messwerte wird verworfen.
  ///
  /// Gibt zurück, ob das Training erhalten blieb.
  bool finishWorkout(
    int workoutId, {
    int? energyKcal,
    int? ascentM,
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
    // Liefert das Gerät keinen Energieverbrauch, wird er aus dem Puls
    // geschätzt, sofern Gewicht und Geburtsjahr hinterlegt sind.
    final estimated = energyKcal == null
        ? HeartProfile.load(this)
              .estimateEnergyKcal(samples(workoutId), DateTime.now())
        : null;
    _db.execute(
      'UPDATE workouts SET duration_s = ?, distance_m = ?, avg_hr = ?, '
      'max_hr = ?, avg_power = ?, max_power = ?, avg_cadence = ?, '
      'energy_kcal = ?, energy_estimated = ?, ascent_m = ?, status = ?, '
      'updated_at = ? WHERE id = ?',
      [
        row['duration'],
        (row['distance'] as num?)?.toDouble() ?? 0,
        round(row['avg_hr']),
        round(row['max_hr']),
        round(row['avg_power']),
        round(row['max_power']),
        round(row['avg_cadence']),
        energyKcal ?? estimated,
        estimated == null ? 0 : 1,
        ascentM,
        status.id,
        _now(),
        workoutId,
      ],
    );
    computeBestEfforts(workoutId);
    return true;
  }

  /// Schließt Trainings ab, die beim letzten Lauf der App nicht beendet wurden.
  /// Gibt deren Anzahl zurück.
  int recoverUnfinished() {
    final rows = _db.select('SELECT id FROM workouts WHERE status = ?', [
      WorkoutStatus.recording.id,
    ]);
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
      .select('SELECT * FROM samples WHERE workout_id = ? ORDER BY t', [
        workoutId,
      ])
      .map(
        (r) => Sample(
          t: r['t'] as int,
          heartRate: r['hr'] as int?,
          speedKmh: (r['speed'] as num?)?.toDouble(),
          cadence: (r['cadence'] as num?)?.toDouble(),
          power: r['power'] as int?,
          distanceM: (r['distance'] as num?)?.toDouble(),
          incline: (r['incline'] as num?)?.toDouble(),
          resistance: (r['resistance'] as num?)?.toDouble(),
          latitude: (r['lat'] as num?)?.toDouble(),
          longitude: (r['lon'] as num?)?.toDouble(),
          altitudeM: (r['altitude'] as num?)?.toDouble(),
        ),
      )
      .toList();

  /// Markiert ein Training als gelöscht. Die Zeile bleibt für die spätere
  /// Synchronisation erhalten, die Messwerte werden entfernt.
  void deleteWorkout(int id) {
    _db.execute('DELETE FROM samples WHERE workout_id = ?', [id]);
    _db.execute('DELETE FROM laps WHERE workout_id = ?', [id]);
    _db.execute('DELETE FROM best_efforts WHERE workout_id = ?', [id]);
    _db.execute('DELETE FROM set_logs WHERE workout_id = ?', [id]);
    _db.execute('DELETE FROM link_losses WHERE workout_id = ?', [id]);
    _db.execute(
      'UPDATE workouts SET deleted = 1, updated_at = ? WHERE id = ?',
      [_now(), id],
    );
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
    ascentM: r['ascent_m'] as int?,
    notes: r['notes'] as String?,
    stravaId: r['strava_id'] as int?,
    imported: r['imported'] == 1,
    energyEstimated: r['energy_estimated'] == 1,
  );

  // --- Intervall-Vorlagen ---

  List<IntervalTemplate> intervalTemplates() => _db
      .select(
        'SELECT * FROM interval_templates WHERE deleted = 0 '
        'ORDER BY name COLLATE NOCASE',
      )
      .map(
        (r) => IntervalTemplate(
          id: r['id'] as int,
          name: r['name'] as String,
          targetKind: TargetKind.fromId(r['target_kind'] as String),
          blocks: IntervalTemplate.blocksFromJson(r['blocks'] as String),
        ),
      )
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
      [_now(), id],
    );
  }

  // --- Übungen und Programme ---

  /// Alle Übungen, nach Name sortiert; mit [category] nur die eines Bereichs.
  List<Exercise> exercises({ExerciseCategory? category}) => _db
      .select(
        'SELECT * FROM exercises WHERE deleted = 0 '
        '${category == null ? '' : 'AND category = ? '}'
        'ORDER BY name COLLATE NOCASE',
        [if (category != null) category.id],
      )
      .map(
        (r) => Exercise(
          id: r['id'] as int,
          uuid: r['uuid'] as String,
          category: ExerciseCategory.fromId(r['category'] as String),
          name: r['name'] as String,
          description: r['description'] as String,
          builtinKey: r['builtin_key'] as String?,
          imagePath: r['image_path'] as String?,
          timed: r['timed'] == 1,
          areas: BodyArea.parse(r['areas'] as String?),
          sanskrit: r['sanskrit'] as String,
          poseGroup: PoseGroup.fromId(r['pose_group'] as String?),
          level: r['level'] as int,
          bothSides: r['both_sides'] == 1,
          caution: r['caution'] as String,
          easierUuid: r['easier_uuid'] as String?,
          harderUuid: r['harder_uuid'] as String?,
        ),
      )
      .toList();

  static const _exerciseColumns = [
    'category',
    'name',
    'description',
    'builtin_key',
    'image_path',
    'timed',
    'areas',
    'sanskrit',
    'pose_group',
    'level',
    'both_sides',
    'caution',
    'easier_uuid',
    'harder_uuid',
    'updated_at',
  ];

  /// Speichert eine neue oder geänderte Übung und gibt ihre Nummer zurück.
  int saveExercise(Exercise e) {
    final values = [
      e.category.id,
      e.name,
      e.description,
      e.builtinKey,
      e.imagePath,
      e.timed ? 1 : 0,
      BodyArea.store(e.areas),
      e.sanskrit,
      e.poseGroup?.id,
      e.level,
      e.bothSides ? 1 : 0,
      e.caution,
      e.easierUuid,
      e.harderUuid,
      _now(),
    ];
    final id = e.id;
    if (id == null) {
      _db.execute(
        'INSERT INTO exercises (${_exerciseColumns.join(', ')}, uuid) '
        'VALUES (${List.filled(_exerciseColumns.length + 1, '?').join(', ')})',
        [...values, e.uuid],
      );
      return _db.lastInsertRowId;
    }
    _db.execute(
      'UPDATE exercises SET '
      '${_exerciseColumns.map((c) => '$c = ?').join(', ')} WHERE id = ?',
      [...values, id],
    );
    return id;
  }

  /// Eine Kennung für eine selbst angelegte Übung.
  String newExerciseUuid() => _newUuid();

  void deleteExercise(int id) {
    _db.execute(
      'UPDATE exercises SET deleted = 1, updated_at = ? WHERE id = ?',
      [_now(), id],
    );
  }

  List<Program> programs() => _db
      .select(
        'SELECT * FROM programs WHERE deleted = 0 '
        'ORDER BY name COLLATE NOCASE',
      )
      .map(
        (r) => Program(
          id: r['id'] as int,
          name: r['name'] as String,
          category: ExerciseCategory.fromId(r['category'] as String),
          rounds: r['rounds'] as int,
          items: Program.itemsFromJson(r['items'] as String),
        ),
      )
      .toList();

  /// Speichert ein neues oder geändertes Programm und gibt seine Nummer zurück.
  int saveProgram(Program p) {
    final id = p.id;
    if (id == null) {
      _db.execute(
        'INSERT INTO programs (uuid, name, category, rounds, items, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [_newUuid(), p.name, p.category.id, p.rounds, p.itemsJson(), _now()],
      );
      return _db.lastInsertRowId;
    }
    _db.execute(
      'UPDATE programs SET name = ?, category = ?, rounds = ?, items = ?, '
      'updated_at = ? WHERE id = ?',
      [p.name, p.category.id, p.rounds, p.itemsJson(), _now(), id],
    );
    return id;
  }

  void deleteProgram(int id) {
    _db.execute(
      'UPDATE programs SET deleted = 1, updated_at = ? WHERE id = ?',
      [_now(), id],
    );
  }

  // --- Verbindungsabbrüche ---

  /// Hält einen Abbruch fest und gibt seine Nummer zurück, unter der später
  /// die Dauer nachgetragen wird.
  int addLinkLoss(int workoutId, LinkLoss loss) {
    _db.execute(
      'INSERT INTO link_losses (workout_id, t, device, reason, down_s) '
      'VALUES (?, ?, ?, ?, ?)',
      [workoutId, loss.t, loss.device, loss.reason, loss.downS],
    );
    return _db.lastInsertRowId;
  }

  void setLinkLossDuration(int id, int seconds) {
    _db.execute('UPDATE link_losses SET down_s = ? WHERE id = ?', [
      seconds,
      id,
    ]);
  }

  List<LinkLoss> linkLosses(int workoutId) => _db
      .select('SELECT * FROM link_losses WHERE workout_id = ? ORDER BY t, id', [
        workoutId,
      ])
      .map(
        (r) => LinkLoss(
          t: r['t'] as int,
          device: r['device'] as String,
          reason: r['reason'] as String?,
          downS: r['down_s'] as int?,
        ),
      )
      .toList();

  // --- Sätze (Kraft-Protokoll) ---

  void addSetLog(int workoutId, SetLog log) {
    _db.execute(
      'INSERT INTO set_logs (workout_id, exercise_uuid, t, reps, weight_kg, '
      'seconds) VALUES (?, ?, ?, ?, ?, ?)',
      [workoutId, log.exerciseUuid, log.t, log.reps, log.weightKg, log.seconds],
    );
  }

  /// Die Sätze eines Trainings in der Reihenfolge, in der sie absolviert
  /// wurden.
  List<SetLog> setLogs(int workoutId) => _db
      .select('SELECT * FROM set_logs WHERE workout_id = ? ORDER BY id', [
        workoutId,
      ])
      .map(_setLog)
      .toList();

  /// Alle Sätze einer Übung aus nicht gelöschten Trainings, neueste zuerst.
  List<SetLog> exerciseHistory(String exerciseUuid) => _db
      .select(
        'SELECT s.*, w.started_at FROM set_logs s '
        'JOIN workouts w ON w.id = s.workout_id '
        'WHERE s.exercise_uuid = ? AND w.deleted = 0 '
        'ORDER BY w.started_at DESC, s.id',
        [exerciseUuid],
      )
      .map(_setLog)
      .toList();

  /// Das zuletzt bei dieser Übung erfasste Gewicht, als Vorschlag für den
  /// nächsten Satz.
  double? lastWeight(String exerciseUuid) {
    final rows = _db.select(
      'SELECT weight_kg FROM set_logs WHERE exercise_uuid = ? '
      'AND weight_kg IS NOT NULL ORDER BY id DESC LIMIT 1',
      [exerciseUuid],
    );
    return rows.isEmpty ? null : (rows.first['weight_kg'] as num).toDouble();
  }

  SetLog _setLog(Row r) => SetLog(
    exerciseUuid: r['exercise_uuid'] as String,
    t: r['t'] as int,
    reps: r['reps'] as int?,
    weightKg: (r['weight_kg'] as num?)?.toDouble(),
    seconds: r['seconds'] as int?,
    performedAt: r.keys.contains('started_at')
        ? DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int)
        : null,
  );

  // --- Synchronisation ---

  /// Die Tabellen kleiner Inhalte, die als Ganzes abgeglichen werden, mit
  /// den Spalten, die dabei mitgehen. Das eigene Bild einer Übung bleibt
  /// außen vor: Es ist eine Datei auf diesem Gerät.
  static const syncTables = {
    'interval_templates': ['name', 'target_kind', 'blocks'],
    'exercises': [
      'category',
      'name',
      'description',
      'builtin_key',
      'timed',
      'areas',
      'sanskrit',
      'pose_group',
      'level',
      'both_sides',
      'caution',
      'easier_uuid',
      'harder_uuid',
    ],
    'programs': ['name', 'category', 'rounds', 'items'],
  };

  /// Alle Zeilen einer Tabelle für den Abgleich, auch die gelöschten.
  List<Map<String, Object?>> syncRows(String table) {
    final columns = ['uuid', 'updated_at', 'deleted', ...syncTables[table]!];
    return _db
        .select('SELECT ${columns.join(', ')} FROM $table')
        .map((r) => {for (final c in columns) c: r[c]})
        .toList();
  }

  /// Übernimmt eine Zeile von einem anderen Gerät, wenn sie hier fehlt oder
  /// dort jünger ist. Gibt zurück, ob sich etwas geändert hat.
  bool applySyncRow(String table, Map<String, Object?> row) {
    // Eine Sicherung aus einer älteren Fassung der App kennt neuere Spalten
    // noch nicht; für sie gilt dann der Vorgabewert der Tabelle.
    final columns = [
      'updated_at',
      'deleted',
      ...syncTables[table]!.where(row.containsKey),
    ];
    final uuid = row['uuid'] as String;
    final local = _db.select('SELECT updated_at FROM $table WHERE uuid = ?', [
      uuid,
    ]);
    final values = [for (final c in columns) row[c]];
    if (local.isEmpty) {
      _db.execute(
        'INSERT INTO $table (${columns.join(', ')}, uuid) '
        'VALUES (${List.filled(columns.length + 1, '?').join(', ')})',
        [...values, uuid],
      );
      return true;
    }
    if ((row['updated_at'] as int) <= (local.first['updated_at'] as int)) {
      return false;
    }
    _db.execute(
      'UPDATE $table SET ${columns.map((c) => '$c = ?').join(', ')} '
      'WHERE uuid = ?',
      [...values, uuid],
    );
    return true;
  }

  static const _workoutSyncColumns = [
    'sport',
    'title',
    'started_at',
    'duration_s',
    'distance_m',
    'avg_hr',
    'max_hr',
    'avg_power',
    'max_power',
    'avg_cadence',
    'energy_kcal',
    'ascent_m',
    'notes',
    'status',
    'strava_id',
    'imported',
    'energy_estimated',
  ];
  static const _sampleSyncColumns = [
    't',
    'hr',
    'speed',
    'cadence',
    'power',
    'distance',
    'incline',
    'resistance',
    'lat',
    'lon',
    'altitude',
  ];

  /// Kennung, Stand und Löschmarke aller abgeschlossenen Trainings.
  List<Map<String, Object?>> workoutSyncIndex() => _db
      .select(
        'SELECT uuid, updated_at, deleted FROM workouts WHERE status != ?',
        [WorkoutStatus.recording.id],
      )
      .map(
        (r) => {
          'uuid': r['uuid'],
          'updated_at': r['updated_at'],
          'deleted': r['deleted'],
        },
      )
      .toList();

  /// Ein Training mit Messpunkten und Runden, wie es zu einem anderen Gerät
  /// geht.
  Map<String, Object?> workoutSyncData(String uuid) {
    final row = _db.select('SELECT * FROM workouts WHERE uuid = ?', [
      uuid,
    ]).first;
    final id = row['id'] as int;
    return {
      'uuid': uuid,
      'updated_at': row['updated_at'],
      for (final c in _workoutSyncColumns) c: row[c],
      'samples': [
        for (final s in _db.select(
          'SELECT * FROM samples WHERE workout_id = ? ORDER BY t',
          [id],
        ))
          [for (final c in _sampleSyncColumns) s[c]],
      ],
      'laps': [
        for (final l in _db.select(
          'SELECT * FROM laps WHERE workout_id = ? ORDER BY t',
          [id],
        ))
          [l['t'], l['distance'], l['auto']],
      ],
      'sets': [
        for (final s in _db.select(
          'SELECT * FROM set_logs WHERE workout_id = ? ORDER BY id',
          [id],
        ))
          [s['exercise_uuid'], s['t'], s['reps'], s['weight_kg'], s['seconds']],
      ],
      'links': [
        for (final l in _db.select(
          'SELECT * FROM link_losses WHERE workout_id = ? ORDER BY id',
          [id],
        ))
          [l['t'], l['device'], l['reason'], l['down_s']],
      ],
    };
  }

  /// Übernimmt ein Training von einem anderen Gerät samt Messpunkten und
  /// Runden. Der Zeitstempel bleibt der des anderen Geräts, damit das
  /// Training nicht als hier geändert gilt und zurückgeschickt wird.
  void applySyncedWorkout(Map<String, Object?> data) {
    final uuid = data['uuid'] as String;
    _db.execute('BEGIN');
    try {
      var rows = _db.select('SELECT id FROM workouts WHERE uuid = ?', [uuid]);
      if (rows.isEmpty) {
        _db.execute(
          'INSERT INTO workouts (uuid, sport, started_at, status, updated_at) '
          'VALUES (?, ?, 0, ?, 0)',
          [uuid, Sport.other.id, WorkoutStatus.finished.id],
        );
        rows = _db.select('SELECT id FROM workouts WHERE uuid = ?', [uuid]);
      }
      final id = rows.first['id'] as int;
      _db.execute('DELETE FROM samples WHERE workout_id = ?', [id]);
      _db.execute('DELETE FROM laps WHERE workout_id = ?', [id]);
      _db.execute('DELETE FROM best_efforts WHERE workout_id = ?', [id]);
      _db.execute('DELETE FROM set_logs WHERE workout_id = ?', [id]);
      _db.execute('DELETE FROM link_losses WHERE workout_id = ?', [id]);
      _db.execute(
        'UPDATE workouts SET '
        '${_workoutSyncColumns.map((c) => '$c = ?').join(', ')}, '
        'updated_at = ?, deleted = 0 WHERE id = ?',
        [for (final c in _workoutSyncColumns) data[c], data['updated_at'], id],
      );
      final placeholders = List.filled(_sampleSyncColumns.length + 1, '?');
      for (final s in data['samples'] as List) {
        _db.execute(
          'INSERT INTO samples (workout_id, ${_sampleSyncColumns.join(', ')}) '
          'VALUES (${placeholders.join(', ')})',
          [id, ...s as List],
        );
      }
      for (final l in data['laps'] as List) {
        _db.execute(
          'INSERT INTO laps (workout_id, t, distance, auto) VALUES (?, ?, ?, ?)',
          [id, ...l as List],
        );
      }
      // Ältere Fassungen der App schicken noch keine Sätze mit.
      for (final s in data['sets'] as List? ?? const []) {
        _db.execute(
          'INSERT INTO set_logs (workout_id, exercise_uuid, t, reps, '
          'weight_kg, seconds) VALUES (?, ?, ?, ?, ?, ?)',
          [id, ...s as List],
        );
      }
      for (final l in data['links'] as List? ?? const []) {
        _db.execute(
          'INSERT INTO link_losses (workout_id, t, device, reason, down_s) '
          'VALUES (?, ?, ?, ?, ?)',
          [id, ...l as List],
        );
      }
      computeBestEfforts(id);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Übernimmt die Löschung eines Trainings von einem anderen Gerät. Kennt
  /// dieses Gerät das Training gar nicht, merkt es sich trotzdem die
  /// Löschmarke: Sonst würde ein drittes Gerät, das das Training noch hat,
  /// es wieder in Umlauf bringen.
  void applySyncedDeletion(String uuid, int updatedAt) {
    final rows = _db.select('SELECT id FROM workouts WHERE uuid = ?', [uuid]);
    if (rows.isEmpty) {
      _db.execute(
        'INSERT INTO workouts (uuid, sport, started_at, status, updated_at, '
        'deleted) VALUES (?, ?, 0, ?, ?, 1)',
        [uuid, Sport.other.id, WorkoutStatus.finished.id, updatedAt],
      );
      return;
    }
    final id = rows.first['id'] as int;
    _db.execute('DELETE FROM samples WHERE workout_id = ?', [id]);
    _db.execute('DELETE FROM laps WHERE workout_id = ?', [id]);
    _db.execute('DELETE FROM best_efforts WHERE workout_id = ?', [id]);
    _db.execute(
      'UPDATE workouts SET deleted = 1, updated_at = ? WHERE id = ?',
      [updatedAt, id],
    );
  }

  // --- Strava ---

  /// Merkt sich, unter welcher Nummer ein Training bei Strava liegt.
  void setStravaId(int workoutId, int stravaId) {
    _db.execute(
      'UPDATE workouts SET strava_id = ?, updated_at = ? WHERE id = ?',
      [stravaId, _now(), workoutId],
    );
  }

  /// Die Strava-Nummern aller Trainings, die hochgeladen oder importiert
  /// wurden, auch der inzwischen gelöschten: Ein gelöschter Import soll
  /// nicht wiederkommen.
  Set<int> stravaIds() => _db
      .select('SELECT strava_id FROM workouts WHERE strava_id IS NOT NULL')
      .map((r) => r['strava_id'] as int)
      .toSet();

  /// Ob es schon ein Training gibt, das höchstens [tolerance] vor oder nach
  /// [start] begonnen hat. Gelöschte zählen nicht.
  bool hasWorkoutNear(
    DateTime start, {
    Duration tolerance = const Duration(minutes: 1),
  }) {
    final ms = start.millisecondsSinceEpoch;
    return _db.select(
      'SELECT 1 FROM workouts WHERE deleted = 0 AND status != ? '
      'AND started_at BETWEEN ? AND ? LIMIT 1',
      [
        WorkoutStatus.recording.id,
        ms - tolerance.inMilliseconds,
        ms + tolerance.inMilliseconds,
      ],
    ).isNotEmpty;
  }

  /// Legt ein von Strava oder aus einer Datei übernommenes Training mit
  /// seinen Messpunkten an und gibt seine Nummer zurück.
  int importWorkout({
    required Sport sport,
    required DateTime startedAt,
    required String title,
    required List<Sample> samples,
    int? stravaId,
    int? ascentM,
  }) {
    _db.execute('BEGIN');
    try {
      final id = startWorkout(sport, startedAt);
      for (final s in samples) {
        addSample(id, s);
      }
      finishWorkout(id, ascentM: ascentM);
      _db.execute(
        'UPDATE workouts SET title = ?, strava_id = ?, imported = 1 '
        'WHERE id = ?',
        [title.trim().isEmpty ? null : title.trim(), stravaId, id],
      );
      _db.execute('COMMIT');
      return id;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // --- Auswertung ---

  /// Ändert Titel, Sportart und Notiz eines Trainings. Leere Texte werden
  /// als „nicht gesetzt" gespeichert.
  void updateWorkout(
    int id, {
    required String title,
    required Sport sport,
    required String notes,
  }) {
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();
    _db.execute(
      'UPDATE workouts SET title = ?, sport = ?, notes = ?, updated_at = ? '
      'WHERE id = ?',
      [orNull(title), sport.id, orNull(notes), _now(), id],
    );
  }

  /// Sekunden mit Pulsmessung in jeder der fünf Zonen, aufsteigend.
  /// [thresholds] sind die vier Grenzen zwischen den Zonen. Mit [workoutId]
  /// nur dieses Training, mit [since] nur Trainings ab diesem Zeitpunkt.
  List<int> zoneSeconds(
    List<int> thresholds, {
    int? workoutId,
    DateTime? since,
  }) {
    final row = _db.select(
      'SELECT '
      'SUM(s.hr < ?1) AS z1, '
      'SUM(s.hr >= ?1 AND s.hr < ?2) AS z2, '
      'SUM(s.hr >= ?2 AND s.hr < ?3) AS z3, '
      'SUM(s.hr >= ?3 AND s.hr < ?4) AS z4, '
      'SUM(s.hr >= ?4) AS z5 '
      'FROM samples s JOIN workouts w ON w.id = s.workout_id '
      'WHERE s.hr IS NOT NULL AND w.deleted = 0 '
      'AND (?5 IS NULL OR w.id = ?5) '
      'AND (?6 IS NULL OR w.started_at >= ?6)',
      [...thresholds, workoutId, since?.millisecondsSinceEpoch],
    ).first;
    return [for (final z in row.values) (z as int?) ?? 0];
  }

  /// Die Belastung je Training nach Edwards: Minuten je Pulsbereich mal
  /// Gewicht 1 bis 5, ab 50 % des Maximalpulses. Trainings ohne Puls fehlen.
  List<WorkoutLoad> workoutLoads(
    int maxHr, {
    int? workoutId,
    DateTime? since,
  }) {
    final bounds = [for (final f in loadBandStarts) (maxHr * f).round()];
    return _db.select(
      'SELECT w.id AS id, w.started_at AS started_at, '
      '(SUM(s.hr >= ?1) + SUM(s.hr >= ?2) + SUM(s.hr >= ?3) + '
      'SUM(s.hr >= ?4) + SUM(s.hr >= ?5)) AS weighted '
      'FROM samples s JOIN workouts w ON w.id = s.workout_id '
      'WHERE s.hr IS NOT NULL AND w.deleted = 0 '
      'AND (?6 IS NULL OR w.id = ?6) '
      'AND (?7 IS NULL OR w.started_at >= ?7) '
      'GROUP BY w.id ORDER BY w.started_at',
      [...bounds, workoutId, since?.millisecondsSinceEpoch],
    ).map((r) {
      return WorkoutLoad(
        workoutId: r['id'] as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        // Jede Grenze zählt einmal: Wer über der vierten liegt, hat Gewicht 4.
        load: ((r['weighted'] as int? ?? 0) / 60).round(),
      );
    }).toList();
  }

  /// Berechnet die Bestwerte eines Trainings und merkt sie.
  void computeBestEfforts(int workoutId) {
    final recorded = samples(workoutId);
    final distance = <double>[];
    final power = <int>[];
    var lastDistance = 0.0;
    var lastT = 0;
    for (final s in recorded) {
      final gap = s.t - lastT;
      if (gap <= 0) continue;
      final reached = s.distanceM ?? lastDistance;
      // Importierte Trainings haben nicht für jede Sekunde einen Messpunkt.
      // Die Strecke wird über die Lücke gleichmäßig verteilt; sonst sähe der
      // Sprung an ihrem Ende wie ein Sprint aus.
      for (var k = 1; k <= gap; k++) {
        distance.add(lastDistance + (reached - lastDistance) * k / gap);
        // Sekunden ohne Leistungswert zählen als 0 W, etwa beim Ausrollen.
        power.add(k == gap ? s.power ?? 0 : 0);
      }
      lastDistance = reached;
      lastT = s.t;
    }
    final hasPower = recorded.any((s) => s.power != null);
    _db.execute('DELETE FROM best_efforts WHERE workout_id = ?', [workoutId]);
    void store(String kind, num? value) {
      if (value == null) return;
      _db.execute(
        'INSERT INTO best_efforts (workout_id, kind, value) VALUES (?, ?, ?)',
        [workoutId, kind, value.toDouble()],
      );
    }

    for (final kind in EffortKind.values) {
      final meters = kind.meters;
      final window = kind.windowS;
      if (meters != null) {
        store(kind.id, fastestSeconds(distance, meters));
      } else if (window != null && hasPower) {
        store(kind.id, bestAverage(power, window));
      }
    }
    store(_effortsDone, 1);
  }

  static const _effortsDone = 'done';

  /// Holt die Bestwerte für Trainings nach, die noch nicht ausgewertet sind,
  /// etwa aus der Zeit vor dieser Funktion.
  void ensureBestEfforts() {
    final pending = _db.select(
      'SELECT id FROM workouts w WHERE deleted = 0 AND status != ? '
      'AND NOT EXISTS (SELECT 1 FROM best_efforts e '
      'WHERE e.workout_id = w.id AND e.kind = ?)',
      [WorkoutStatus.recording.id, _effortsDone],
    );
    for (final row in pending) {
      computeBestEfforts(row['id'] as int);
    }
  }

  /// Der beste Wert jeder Art in einer Sportart, mit dem Training dazu.
  Map<EffortKind, ({double value, int workoutId, DateTime date})> bestEfforts(
    Sport sport,
  ) {
    ensureBestEfforts();
    final rows = _db.select(
      'SELECT e.kind, e.value, w.id, w.started_at FROM best_efforts e '
      'JOIN workouts w ON w.id = e.workout_id '
      'WHERE w.deleted = 0 AND w.sport = ? AND e.kind != ? '
      'ORDER BY w.started_at',
      [sport.id, _effortsDone],
    );
    final best = <EffortKind, ({double value, int workoutId, DateTime date})>{};
    for (final r in rows) {
      final kind = EffortKind.fromId(r['kind'] as String);
      if (kind == null) continue;
      final value = (r['value'] as num).toDouble();
      final current = best[kind];
      final better =
          current == null ||
          (kind.isTime ? value < current.value : value > current.value);
      if (better) {
        best[kind] = (
          value: value,
          workoutId: r['id'] as int,
          date: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        );
      }
    }
    return best;
  }

  // --- Einstellungen ---

  String? setting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  /// Speichert eine Einstellung; `null` entfernt sie.
  void setSetting(String key, String? value) {
    if (value == null) {
      _db.execute('DELETE FROM settings WHERE key = ?', [key]);
      return;
    }
    _db.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

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
    _db.execute('UPDATE devices SET name = ? WHERE device_id = ?', [
      name,
      deviceId,
    ]);
  }

  void forgetDevice(String deviceId) {
    _db.execute('DELETE FROM devices WHERE device_id = ?', [deviceId]);
  }

  List<SavedDevice> devices() => _db
      .select('SELECT * FROM devices ORDER BY added_at')
      .map(
        (r) => SavedDevice(
          deviceId: r['device_id'] as String,
          name: r['name'] as String,
          kind: DeviceKind.values.firstWhere(
            (k) => k.name == r['kind'],
            orElse: () => DeviceKind.unknown,
          ),
        ),
      )
      .toList();

  /// Die Geräte, die zuletzt für diese Sportart gewählt waren.
  Set<String> devicesForSport(Sport sport) => _db
      .select('SELECT device_id FROM sport_devices WHERE sport = ?', [sport.id])
      .map((r) => r['device_id'] as String)
      .toSet();

  void setDevicesForSport(Sport sport, Iterable<String> deviceIds) {
    _db.execute('DELETE FROM sport_devices WHERE sport = ?', [sport.id]);
    for (final id in deviceIds) {
      _db.execute(
        'INSERT INTO sport_devices (sport, device_id) VALUES (?, ?)',
        [sport.id, id],
      );
    }
  }
}
