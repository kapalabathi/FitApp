# Architektur FitApp

Stand: Version 0.23.0. Dieses Dokument beschreibt den Aufbau des Codes. Was die App leistet, steht in [FUNKTIONEN.md](FUNKTIONEN.md).

## Grundsätze

- **Eine Codebasis** in Flutter (Dart) für Android, später Windows und Linux. Plattformunterschiede laufen über `lib/platform/app_platform.dart`.
- **Alles lokal:** eine SQLite-Datenbank auf dem Gerät, kein eigener Server. Google Drive und Strava sind optionale Ziele.
- **Standards statt Einzelmodelle:** Geräte werden über ihre Bluetooth-Profile angesprochen (FTMS, Heart Rate, Cycling Power …), nicht über Herstellerprotokolle. Ausnahme ist Concept2 PM5.
- **Kein Datenverlust:** Messpunkte werden während des Trainings fortlaufend geschrieben; ein nicht beendetes Training wird beim nächsten Start gerettet (`AppDatabase.recoverUnfinished`).
- **Oberfläche Deutsch**, Code-Kommentare ebenfalls.

## Verzeichnisse unter `lib/`

| Ordner | Inhalt |
|---|---|
| `ble/` | Bluetooth: Gerätesuche und -erkennung (`device_kind.dart`, `device_probe.dart`), Verbindung mit Neuverbindung und Überwachung (`sensor_connection.dart`, `link_monitor.dart`), Dekoder je Profil (`decoders.dart`, `ftms.dart`, `heart_rate.dart`, `sensor_profiles.dart`), FTMS-Steuerung (`ftms_control.dart`), Kennungen (`uuids.dart`) |
| `session/` | Ablauf eines Trainings: `workout_session.dart` verbindet Geräte und Aufzeichnung, `workout_recorder.dart` schreibt Messpunkte, dazu automatische Pause, Zielpuls-Regler, Hintergrund-Dienst, Schnellstart, Kachel-Anordnung |
| `data/` | `models.dart` (Training, Messpunkt, Runde, Gerät, Satz, Verbindungsabbruch …) und `database.dart` (SQLite, Migrationen, Abfragen, Auswertungen) |
| `interval/` | Intervall-Vorlagen, Ablauf des Timers, Signale und Sprachansage |
| `programs/` | Übungen, Programme, Yoga-Kurs, Ablauf eines Programms, Progressionsregel |
| `breath/` | Atemübungen und ihr Ablauf |
| `vision/` | Kamera, Haltungserkennung, Glättung, Wiederholungszähler, WOD-Definitionen |
| `gps/` | Standort des Phones, Distanz- und Höhenberechnung |
| `stats/` | Umfang, Pulszonen, Belastung, Vergleich mehrerer Trainings |
| `export/` | FIT-Schreiber, GPX und TCX |
| `import/` | Einlesen von FIT, GPX und TCX |
| `strava/` | Strava-API: Anmeldung, Upload, Import, Dubletten-Prüfung |
| `sync/` | Synchronisation über Google Drive, Sicherungsdatei, automatische Sicherung, Desktop-Anmeldung |
| `platform/` | Plattformweichen (Kamera, GPS, Desktop) |
| `ui/` | Alle Seiten und Bausteine der Oberfläche |

## Bluetooth

Bluetooth läuft über das Paket `universal_ble`, das Android, Windows und Linux abdeckt.

```
Gerätesuche ──► DeviceKind (Dienste, Dienstdaten, Name)
                     │
                     ▼
SensorConnection ──► Dekoder je Profil ──► Messwerte ──► WorkoutRecorder
     │    ▲
     │    └── Neuverbindung (0,6 s, dann 3 s; Suche nach 3 Fehlversuchen)
     ├── LinkWatch: 30 s Stille + 2 unbeantwortete Anfragen → neu verbinden
     ├── Lebenszeichen alle 20 s (Steuererlaubnis / Lesen / aus)
     └── MachineControl: FTMS-Steuerpunkt (Geschwindigkeit, Steigung, Widerstand, Leistung)
```

- **`SensorConnection`** hält eine Verbindung, abonniert die Messwerte und verbindet nach einem Abbruch neu. Jeder Abbruch wird als `LinkLoss` gespeichert.
- **`MachineControl`** liest die FTMS-Fähigkeiten und Einstellbereiche und sendet Steuerbefehle. Nach einem Abbruch sind Befehle gesperrt, bis der Nutzer bestätigt.
- Der letzte Wert eines Fitnessgeräts oder Pulssensors gilt 20 Sekunden weiter, damit kurze Abbrüche keine Lücken erzeugen.

## Datenbank

SQLite über das Paket `sqlite3`. Die Fassung steht in `PRAGMA user_version` (derzeit 16); jede neue Fassung hat eine Migration in `database.dart`, bestehende Daten bleiben erhalten.

| Tabelle | Inhalt |
|---|---|
| `workouts` | Trainings mit Sportart, Zeiten, Kennzahlen, Notiz |
| `samples` | Messpunkte je Sekunde: Puls, Geschwindigkeit, Leistung, Frequenz, Standort, Höhe … |
| `laps` | Runden |
| `link_losses` | Verbindungsabbrüche |
| `set_logs` | Sätze aus Programmen: Übung, Wiederholungen, Gewicht, Dauer |
| `best_efforts` | Bestwerte |
| `devices`, `sport_devices` | Gemerkte Geräte und ihre Zuordnung zu Sportarten |
| `interval_templates` | Intervall-Vorlagen |
| `exercises`, `programs` | Übungen und Programme |
| `settings` | Einstellungen als Schlüssel und Wert |

Mitgelieferte Übungen, Programme und Vorlagen tragen feste Kennungen (`builtin-…`), damit sie sich beim Abgleich zwischen Geräten nicht verdoppeln. Solange der Nutzer sie nicht ändert, gelten sie als unberührt und werden bei Updates nachgezogen.

## Synchronisation

Jeder Eintrag hat eine Kennung und einen Änderungszeitpunkt. Beim Abgleich gewinnt die jüngere Änderung; Gelöschtes wird als gelöscht markiert und so auf alle Geräte übertragen. Dieselbe Logik dient der Sicherungsdatei, die beim Einspielen zusammenführt statt zu überschreiben.

## Übungen und Grafiken

- Texte, Körperbereiche und Varianten der Übungen stehen in `tools/uebungen.json`; `tools/uebungen_erzeugen.py` erzeugt daraus `lib/programs/builtin_exercises.dart`.
- Jede Grafik ist in [GRAFIKLISTE.md](GRAFIKLISTE.md) beschrieben (G-001 …). `tools/grafiken_erzeugen.py` erzeugt sie über einen Bildgenerator nach der Vorlage in [GRAFIK-PROMPT.md](GRAFIK-PROMPT.md). Die verkleinerten Bilder liegen unter `assets/exercises/`, die Rohbilder nicht im Repository.

## Tests

326 automatische Tests unter `test/`:

```bash
flutter test
```

Sie decken Dekoder, Neuverbindung, Aufzeichnung, Datenbank und Migrationen, Export und Import (inklusive Wiedereinlesen der eigenen Dateien), Synchronisation zwischen zwei simulierten Geräten, Zielpuls-Regler, Wiederholungszähler, Auswertungen und die wichtigsten Seiten der Oberfläche ab. Was nur am echten Gerät prüfbar ist, steht in [MANUELLE-TESTS.md](MANUELLE-TESTS.md).

## Entwicklungsprozess

- Jede Idee bekommt eine feste Nummer im [Ideenspeicher](IDEENSPEICHER.md) mit Aufwand S, M, L oder XL.
- Anforderungen stehen mit Nummer im [Lastenheft](LASTENHEFT.md).
- Jede Version hat einen Eintrag im [Changelog](../CHANGELOG.md) mit Verweis auf die Nummern und einen Commit „Version x.y.z: …".
