# Changelog

Alle nennenswerten Änderungen am Projekt werden hier festgehalten.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [Semantic Versioning](https://semver.org/lang/de/).
Einträge verweisen, wo möglich, auf die Nummer im [Ideenspeicher](docs/IDEENSPEICHER.md).

## [0.3.1] – 2026-10-11

### Behoben
- Training ließ sich nicht beenden, die App blieb in der Rückfrage hängen (gemeldet vom Nutzer). Das Beenden wartete auf das Trennen aller Geräte, bei einem nicht erreichbaren Gerät bis zu einer Minute je Gerät. Jetzt wird sofort gespeichert und die Seite geschlossen; das Trennen läuft im Hintergrund mit höchstens fünf Sekunden je Gerät.
- Die Zurück-Taste öffnet während des Beendens keine zweite Rückfrage mehr.
- Ein Gerät, dessen Verbindungsaufbau beim Beenden noch lief, bleibt nicht mehr verbunden zurück.

### Hinzugefügt
- Zwei automatische Tests für Pausieren, Beenden und „Weiter trainieren" (insgesamt 63).

## [0.3.0] – 2026-10-11 (M2: Intervall-Timer)

### Hinzugefügt
- Intervall-Vorlagen mit frei editierbaren Abschnitten (Bezeichnung, Dauer, Zielwert für Geschwindigkeit, Widerstand oder Leistung) und wiederholbaren Gruppen (A-030).
- Vorlagen speichern, bearbeiten, duplizieren, löschen; zwei Beispielvorlagen werden mitgeliefert (A-031).
- Signale beim Abschnittswechsel: Töne in den letzten drei Sekunden und beim Wechsel, Vibration, einzeln abschaltbar (A-032).
- Sprachansage des nächsten Abschnitts fünf Sekunden vor dem Wechsel (A-033).
- Anzeige im Training: laufender Abschnitt, Restzeit, Runde, Vorschau, Gesamtrest; Abschnitt überspringen.
- Der Timer läuft auch ohne Gerät und ohne Zielwerte (A-035).
- Gerätesteuerung über FTMS, beim Trainingsstart ausdrücklich einzuschalten (A-008, A-009, A-034). **Noch an keinem Gerät erprobt.**
- Sicherheit bei der Steuerung (A-010): zehn Sekunden Vorlauf vor dem ersten Zielwert, Ankündigung jedes Wechsels, Stoppen der Steuerung mit einem Tipp, nach Verbindungsabbruch erst nach Bestätigung wieder Befehle. Die App startet und stoppt das Gerät nie selbst.
- 19 weitere automatische Tests (insgesamt 61).

### Geändert
- Die Datenbank wächst um Vorlagen und Einstellungen; vorhandene Trainings bleiben erhalten.

## [0.2.0] – 2026-10-11 (M1: Indoor-Aufzeichnung)

### Hinzugefügt
- Training aufzeichnen mit Start, Pause, Fortsetzen und Beenden für Laufband, Indoor-Bike, SkiErg und Sonstiges (A-020).
- Live-Anzeige mit großen Kacheln; Spaltenzahl passt sich Phone und Tablet an (A-021, A-070).
- Geräte merken, umbenennen, entfernen; gemerkte Geräte verbinden sich beim Trainingsstart von selbst. Die Geräteauswahl wird je Sportart gemerkt (A-001).
- Laufband und Indoor-Bike über FTMS sowie Concept2 PM5 als Datenquellen (A-003, A-004, A-005). Der PM5 ist noch nicht am Gerät getestet.
- Mehrere Geräte gleichzeitig auf einer gemeinsamen Zeitachse. Der Pulssensor hat Vorrang vor dem Puls des Fitnessgeräts; die Pulsquelle ist im Training umschaltbar (A-007).
- Automatisches Wiederverbinden nach Verbindungsabbruch; Lücken bleiben in den Daten als Lücken erhalten (A-011).
- Jede Sekunde wird sofort gespeichert. Ein nicht beendetes Training wird beim nächsten App-Start gerettet (A-024).
- Verlauf mit Filter nach Sportart und Zeitraum, Detailansicht mit Kennzahlen und Verlaufskurven, Löschen (A-050).
- Lokale SQLite-Datenbank; die App braucht kein Internet (A-060).
- 28 weitere automatische Tests (insgesamt 42) für Aufzeichnung, Datenbank, Gerätedaten und Oberfläche.

### Geändert
- Die Gerätesuche dient jetzt dem Hinzufügen; der Gerätebericht ist über „Geräte" → Menü → „Prüfen und Gerätebericht" erreichbar.
- Der Bildschirm bleibt während des Trainings an.

## [0.1.0] – 2026-10-11 (Planung und M0: Technik-Prototyp)

### Geändert
- 2026-10-11: Lastenheft als Version 1.0 freigegeben. Mindestversion Android 14, neue Anforderung A-067 (Hinweis auf ähnliche Strava-Aktivität vor dem Upload), Reihenfolge der Meilensteine bestätigt.
- 2026-10-10: Grafik-Skript nutzt standardmäßig `openai/gpt-5.4-image-2` (Wahl des Nutzers); neue Option `--qualitaet`, Auflösungsangabe entfernt.
- 2026-10-10: Grafik-Skript nutzt standardmäßig das Modell `sourceful/riverflow-v2.5-fast` (Wahl des Nutzers), Auflösung 1K.
- 2026-10-10: Steuerbarkeit von Laufband und Bike bestätigt (I-011, I-019). Pulszonen per Faustformel (I-009). Übungen mit Text und Comic-Grafik (I-007). Fragen F-14, F-16 beantwortet, F-17 neu.
- 2026-10-10: Uhr liefert Live-Puls über die Mini-App „Heart Rate Push" (I-005). Strava-Import (I-017), Laufband-Steuerung (I-011) und Auswertung (I-009) vom Nutzer bestätigt. Vorauswahl an Trainingsprogrammen festgelegt (I-007). Fragen F-07, F-08, F-10, F-11 beantwortet, F-14 neu.
- 2026-10-10: Technik entschieden (Flutter), Synchronisation über Google Drive festgelegt (I-015). I-006 um Spazieren und Wandern erweitert. Live-Puls von der Uhr entfällt vorerst (I-005). Fragen F-10, F-12, F-13 beantwortet.
- 2026-10-10: Geräteschnittstellen bestätigt (SkiErg mit PM5, Laufband und Bike über FTMS); I-002 bis I-004 und I-012 auf „Geklärt". Fragen F-01, F-03, F-04 beantwortet. Zielplattformen und Leitziele in der Anforderungssammlung ergänzt, Technikvorschlag (Flutter) eingetragen.
- 2026-10-10: Strava-API und Amazfit-Anbindung recherchiert; Ergebnisse in I-005 und I-016. Fragen F-02, F-05, F-06, F-09 beantwortet, F-10 bis F-13 neu.

### Hinzugefügt
- 2026-10-11: M0 Technik-Prototyp (A-001, A-002, Vorarbeit zu A-003, A-004, A-008, A-009): Flutter-Projekt für Android ab Version 14; Gerätesuche mit Erkennung der Geräteart; Live-Puls über das Herzfrequenzprofil; Live-Werte von FTMS-Laufband und -Bike; Gerätebericht mit Diensten, Mess- und Steuerfähigkeiten, Einstellbereichen und Rohdaten. 14 automatische Tests für die Auswertung der Bluetooth-Pakete.
- 2026-10-11: Entwicklungsumgebung eingerichtet: Flutter 3.47.7 (C:\srclutter), Microsoft OpenJDK 17, Android SDK 36 (C:\Android\Sdk).
- 2026-10-11: Lastenheft, Entwurf 0.1 (`docs/LASTENHEFT.md`): Anforderungen A-001 bis A-072, nichtfunktionale Anforderungen, Abgrenzung, Meilensteine M0 bis M8, Risiken, offene Punkte.
- 2026-10-11: 57 von 80 Übungsgrafiken erzeugt (Yoga und Crossfit vollständig, Calisthenics 17 von 20, Dehnen offen). Rohbilder liegen in `grafiken/` und sind nicht Teil des Repositorys.
- 2026-10-10: Skript `tools/grafiken_erzeugen.py`: erzeugt die 80 Übungsgrafiken einzeln über die OpenRouter-Bild-API, benennt sie nach der Grafikliste und packt sie als ZIP.
- 2026-10-10: Prompt für die Erstellung der 80 Übungsgrafiken per Bildgenerator (Startprompt, 8 Pakete, Korrektur- und Abschlussprompt), Stil nach Beispielbild des Nutzers.
- 2026-10-10: Grafikliste mit 80 Übungen und Vorgaben für die Comic-Grafiken (G-001 bis G-080, zu I-020 und I-007).
- 2026-10-10: Idee I-020 (Comic-Grafiken zu den Übungen).
- 2026-10-10: Idee I-019 (Bike-Widerstand aus der App steuern).
- 2026-10-10: Git-Repository angelegt.
- 2026-10-10: Ideen I-015 (Synchronisation), I-016 (Strava-Upload), I-017 (Strava-Import), I-018 (Mini-App auf der Uhr).
- 2026-10-10: Ideen I-013 (geräteunabhängige Anbindung über Standardprofile) und I-014 (Windows-Version, optional).
- 2026-10-10: Projektdokumentation angelegt: Changelog, Ideenspeicher (I-001 bis I-012), Anforderungssammlung mit Geräteliste und offenen Fragen (F-01 bis F-09).
