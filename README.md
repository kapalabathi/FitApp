# FitApp

Fitness-App für Android, die Trainingsgeräte, Sensoren, GPS und geführte Trainingsprogramme in einer Anwendung zusammenführt. Geschrieben in Flutter (Dart), alle Daten liegen lokal auf dem Gerät.

Stand: Version 0.23.0 (2026-11-07), privates Projekt für den Eigengebrauch.

## Auf einen Blick

| Bereich | Was die App kann |
|---|---|
| **Geräte** | Laufband, Indoor-Bike, Rudergerät und Crosstrainer über FTMS; Concept2 PM5 (SkiErg, RowErg, BikeErg); Pulsgurte und Uhren; Leistungsmesser, Tritt-, Geschwindigkeits- und Laufsensoren. Mehrere Geräte gleichzeitig, alle Werte auf einer Zeitachse. |
| **Steuerung** | Geschwindigkeit und Steigung am Laufband, Widerstand oder Zielleistung am Bike: von Hand, über den Intervall-Timer oder automatisch nach Zielpuls. |
| **Draußen** | Laufen, Spazieren/Wandern und Radfahren mit Phone-GPS, Runden, automatischer Pause und Karte. |
| **Programme** | 237 Übungen (Yoga, Crossfit, Calisthenics, Dehnen) mit Grafik, 37 fertige Programme, ein zwölfwöchiger Yoga-Grundkurs, zwölf Atemübungen und 50 Crossfit-WODs, deren Wiederholungen die Kamera zählt. |
| **Auswertung** | Verlauf mit Kurven, Umfang je Woche und Monat, Pulszonen, Trainingsbelastung, Bestwerte, Vergleich mehrerer Trainings übereinander. |
| **Daten** | Export als FIT, GPX und TCX; Import von FIT, GPX und TCX; Strava-Upload und -Import; Synchronisation über Google Drive; tägliche Sicherung in einen Ordner. |

Die ausführliche Beschreibung aller Funktionen steht in **[docs/FUNKTIONEN.md](docs/FUNKTIONEN.md)**, der technische Aufbau in **[docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md)**.

## Erprobte Geräte

| Gerät | Typ | Anbindung |
|---|---|---|
| Domyos Compact Run 100 | Laufband | FTMS, steuerbar |
| Domyos Challenge Bike | Indoor-Bike | FTMS, steuerbar |
| Concept2 SkiErg | Ski-Ergometer | PM5 |
| BikePilot | Brustgurt | Herzfrequenzprofil |
| Amazfit Bip 6 | Uhr | Live-Puls über die Mini-App „Heart Rate Push" |

Weitere Geräte mit denselben Bluetooth-Standards sollten ebenfalls funktionieren, sind aber nicht erprobt.

## Dokumentation

| Dokument | Inhalt |
|---|---|
| [Funktionsbeschreibung](docs/FUNKTIONEN.md) | Alle Funktionen der App, nach Bereichen |
| [Architektur](docs/ARCHITEKTUR.md) | Aufbau des Codes, Datenmodell, Bluetooth, Tests |
| [Lastenheft](docs/LASTENHEFT.md) | Anforderungen mit Nummern (A-001 …) und Meilensteinen |
| [Ideenspeicher](docs/IDEENSPEICHER.md) | Alle Ideen mit Nummer (I-001 …), Aufwand und Status |
| [Changelog](CHANGELOG.md) | Änderungen je Version |
| [Manuelle Tests](docs/MANUELLE-TESTS.md) | Prüfliste für das echte Gerät |
| [Google Drive einrichten](docs/GOOGLE-DRIVE-EINRICHTUNG.md) | Einmalige Einrichtung in der Google-Cloud-Konsole |
| [Windows und Linux](docs/DESKTOP.md) | Stand und Bauanleitung der Desktop-Fassung |
| [Yoga-Struktur](docs/YOGA-STRUKTUR.md) | Ordnung der Haltungen und Aufbau des Grundkurses |
| [Grafikliste](docs/GRAFIKLISTE.md) und [Grafik-Prompt](docs/GRAFIK-PROMPT.md) | Beschreibung jeder Übungsgrafik und Vorlage für den Bildgenerator |

## Bauen

Voraussetzungen: Flutter SDK (Dart ≥ 3.13), JDK 17, Android SDK. Zielgerät: Android 14 oder neuer.

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter build apk --debug --target-platform android-arm64
```

Die APK liegt danach unter `build/app/outputs/flutter-apk/app-debug.apk`.

## Zugangsdaten

Im Repository liegen keine Schlüssel. Strava und Google Drive brauchen eigene Zugänge, die in der App eingegeben und im sicheren Speicher des Geräts abgelegt werden:

- **Strava:** eigene API-Anwendung unter strava.com/settings/api, Client-ID und Secret in der App unter Strava eintragen. Die Strava-Schnittstelle verlangt inzwischen ein Abo.
- **Google Drive:** eigener OAuth-Client, siehe [docs/GOOGLE-DRIVE-EINRICHTUNG.md](docs/GOOGLE-DRIVE-EINRICHTUNG.md).
- **Übungsgrafiken:** `tools/grafiken_erzeugen.py` liest den Schlüssel für den Bildgenerator aus der Umgebungsvariablen `OPENROUTER_API_KEY`.

## Datenschutz

Daten verlassen das Gerät nur zum eigenen Google Drive und, auf Wunsch, zu Strava. Es gibt keine Werbung, keine Analyse-Dienste und keinen eigenen Server. Kamerabilder für die Wiederholungszählung werden nur auf dem Gerät ausgewertet und nicht gespeichert.

## Projektaufbau

```
lib/          App-Code (Details in docs/ARCHITEKTUR.md)
test/         Automatische Tests (326)
assets/       Übungsgrafiken und Signaltöne
tools/        Übungstexte (uebungen.json) und Skripte für die Grafiken
docs/         Dokumentation
android/      Android-Projekt
windows/      Windows-Projekt (vorbereitet, noch nicht gebaut)
linux/        Linux-Projekt (vorbereitet, noch nicht gebaut)
```

## Rechte

Alle Rechte vorbehalten. Der Code ist nicht zur Weiterverwendung freigegeben.
