# Lastenheft FitApp

| | |
|---|---|
| Version | 1.1 (1.0 freigegeben am 2026-10-11; 1.1: Spazieren und Wandern zusammengelegt) |
| Stand | 2026-10-11 |
| Auftraggeber | Kapalabathi |
| Arbeitstitel | FitApp |
| Grundlage | [Anforderungssammlung](ANFORDERUNGEN-SAMMLUNG.md), [Ideenspeicher](IDEENSPEICHER.md), [Grafikliste](GRAFIKLISTE.md) |

Dieses Dokument beschreibt, **was** die App leisten soll. Wie es technisch umgesetzt wird, steht nur dort, wo es bereits entschieden ist.

## 1. Ziel

Eine Fitness-App, die alle vorhandenen Trainingsgeräte und Sensoren in einer Anwendung zusammenführt, ihre Daten gemeinsam aufzeichnet und auswertet, Bewegung im Freien per GPS erfasst, geführte Trainingsprogramme anbietet und über einen Intervall-Timer Laufband und Indoor-Bike aktiv steuert.

Leitgedanken:

- Möglichst viele Geräte abdecken, nicht nur die eigenen: Standardprofile statt Einzelmodelle.
- Daten aus mehreren Quellen in einem Training koppeln.
- Stabil und schnell.

## 2. Ausgangslage

### 2.1 Vorhandene Geräte

| Gerät | Typ | Anbindung | Stand |
|-------|-----|-----------|-------|
| Domyos Compact Run 100 | Laufband | Bluetooth, FTMS | bestätigt, steuerbar (QZ) |
| Domyos Challenge Bike | Indoor-Bike | Bluetooth, FTMS | bestätigt, steuerbar (Kinomap) |
| Concept2 SkiErg | Ski-Ergometer | Bluetooth, PM5 | bestätigt |
| BikePilot Brustgurt | Pulsgurt | Bluetooth, Herzfrequenzprofil | Standard |
| Amazfit Bip 6 | Smartwatch | Live-Puls über Mini-App „Heart Rate Push"; GPS-Aufzeichnungen über Zepp → Strava | Mini-App vorhanden, Kopplung noch zu testen |

### 2.2 Nutzung

- Indoor-Training auf Laufband, Bike und SkiErg, mit Phone oder Tablet als Anzeige.
- Joggen in der Regel ohne Phone, nur mit Uhr.
- Spaziergänge und Wanderungen mit Phone.
- Yoga, Crossfit, Calisthenics und Dehnen nach Programm.

## 3. Rahmenbedingungen

| Thema | Festlegung |
|-------|------------|
| Nutzerkreis | Vorerst ein Nutzer (Eigengebrauch). Eine spätere Veröffentlichung im Play Store darf nicht verbaut werden. |
| Plattformen | Android-Smartphone und Android-Tablet ab Android 14 (Pflicht), Windows-Laptop (optional). |
| Technik | Flutter (Dart), eine Codebasis für alle Plattformen. Lokale SQLite-Datenbank. |
| Datenhaltung | Lokal auf dem Gerät; Synchronisation über das Google Drive des Nutzers. Kein eigener Server. |
| Externe Dienste | Strava (Upload und Import), Google Drive (Synchronisation). |
| Sprache | Oberfläche Deutsch; Texte so abgelegt, dass weitere Sprachen ergänzt werden können. |
| Entwicklungsprozess | Git-Repository, gepflegter Changelog, Ideenspeicher mit fester Nummerierung und Aufwandsschätzung. Jede umgesetzte Anforderung verweist auf ihre Nummer. |

## 4. Funktionale Anforderungen

Priorität: **Muss** = Bestandteil der ersten vollständigen Version, **Soll** = wichtig, darf nachgeliefert werden, **Kann** = optional.
Spalte „Idee" verweist auf den Ideenspeicher.

### 4.1 Geräteanbindung

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-001 | Bluetooth-Geräte suchen, koppeln, benennen und merken. Bekannte Geräte verbinden sich beim Trainingsstart automatisch. | Muss | I-013 |
| A-002 | Herzfrequenzsensoren über das Standardprofil einbinden (Brustgurt; Amazfit-Uhr über „Heart Rate Push"). | Muss | I-001, I-005 |
| A-003 | Laufbänder über FTMS auslesen: Geschwindigkeit, Steigung, Distanz, Zeit. | Muss | I-004 |
| A-004 | Indoor-Bikes über FTMS auslesen: Leistung, Trittfrequenz, Geschwindigkeit, Widerstand, Distanz. | Muss | I-003 |
| A-005 | Concept2-Geräte mit PM5 auslesen: Leistung, Schlagfrequenz, Tempo, Distanz. | Muss | I-002 |
| A-006 | Weitere Standardprofile unterstützen: Tritt-/Geschwindigkeitssensoren, Leistungsmesser, Laufsensoren, FTMS-Crosstrainer und -Rudergeräte. | Soll | I-013 |
| A-007 | Mehrere Geräte gleichzeitig in einem Training nutzen; alle Werte liegen auf einer gemeinsamen Zeitachse. Liefern zwei Geräte denselben Wert (z. B. Puls), ist die bevorzugte Quelle einstellbar. | Muss | I-012 |
| A-008 | Geschwindigkeit des Laufbands aus der App setzen; Steigung ebenfalls, sofern das Gerät es anbietet. | Muss | I-011 |
| A-009 | Widerstand des Indoor-Bikes aus der App setzen, in der Steuerart, die das Gerät anbietet (Stufe, Zielleistung oder Steigung). | Muss | I-019 |
| A-010 | Sicherheit bei aktiver Steuerung: jederzeit mit einem Tipp stoppbar; jede Erhöhung der Laufband-Geschwindigkeit wird vorher angekündigt; nach Verbindungsverlust sendet die App keine Steuerbefehle, bis der Nutzer bestätigt. | Muss | I-011 |
| A-011 | Bricht eine Verbindung ab, läuft die Aufzeichnung weiter und das Gerät wird automatisch neu verbunden. Die Lücke ist in den Daten erkennbar. | Muss | – |

### 4.2 Aufzeichnung

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-020 | Training starten, pausieren, fortsetzen, beenden. Sportarten: Laufband, Indoor-Bike, SkiErg, Laufen, Spazieren/Wandern (seit 2026-10-11 eine gemeinsame Sportart, Wunsch des Auftraggebers), Yoga, Crossfit, Calisthenics, Dehnen, Sonstiges. | Muss | – |
| A-021 | Live-Anzeige aller verfügbaren Werte, gut ablesbar aus Trainingsabstand; auf dem Tablet großflächig. | Muss | – |
| A-022 | Aufzeichnung im Freien per Phone-GPS: Strecke, Distanz, Tempo, Höhenmeter. Läuft bei ausgeschaltetem Display und im Hintergrund weiter. Für alle Outdoor-Sportarten wählbar. | Muss | I-006 |
| A-023 | Runden: automatisch je Kilometer und manuell per Tipp. | Soll | I-006 |
| A-024 | Die laufende Aufzeichnung wird fortlaufend gesichert. Nach Absturz oder leerem Akku ist das Training bis zu diesem Zeitpunkt erhalten. | Muss | – |
| A-025 | Nach dem Training wird die Strecke auf einer Karte gezeigt. | Soll | I-006 |

### 4.3 Intervall-Timer

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-030 | Intervalle aus frei editierbaren Abschnitten: Bezeichnung, Dauer, Zielwert (Geschwindigkeit, Widerstand oder Leistung). Abschnittsgruppen lassen sich wiederholen. | Muss | I-008 |
| A-031 | Intervalle als Vorlagen speichern, bearbeiten, duplizieren, löschen. | Muss | I-008 |
| A-032 | Signal beim Abschnittswechsel: Ton und Vibration, mit Vorwarnung kurz vor dem Wechsel. | Muss | I-008 |
| A-033 | Sprachansage des nächsten Abschnitts. | Soll | I-008 |
| A-034 | Ist ein steuerbares Gerät gekoppelt, setzt der Timer dessen Zielwert selbst (A-008, A-009). Ohne Gerät zeigt und sagt er den Zielwert nur an. | Muss | I-011, I-019 |
| A-035 | Der Timer ist auch ohne Gerät und ohne Zielwerte nutzbar, z. B. für Crossfit-Runden. | Soll | I-008 |

### 4.4 Trainingsprogramme

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-040 | Übungsbibliothek mit 80 mitgelieferten Übungen, je 20 für Yoga, Crossfit, Calisthenics und Dehnen. Jede Übung hat Name, Beschreibung und Grafik. | Muss | I-007, I-020 |
| A-041 | Eigene Übungen anlegen, ändern, löschen; eigenes Bild hinterlegbar. | Muss | I-007 |
| A-042 | Programme aus Übungen zusammenstellen: Reihenfolge, je Übung Dauer oder Wiederholungen, Pausen, Rundenzahl. | Muss | I-007 |
| A-043 | Programm geführt abspielen: aktuelle Übung mit Grafik, Countdown oder Wiederholungszahl, Vorschau der nächsten Übung, Signal beim Wechsel. | Muss | I-007 |
| A-044 | Eine kleine Auswahl fertiger Programme je Kategorie wird mitgeliefert. | Soll | I-007 |
| A-045 | Ein absolviertes Programm wird als Training gespeichert, mit Puls, wenn ein Sensor gekoppelt ist. | Muss | I-007 |
| A-046 | Fehlt zu einer Übung die Grafik, zeigt die App einen einheitlichen Platzhalter. | Muss | I-020 |

### 4.5 Auswertung

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-050 | Liste aller Trainings, filterbar nach Sportart und Zeitraum. Detailansicht mit Kennzahlen und Verlaufskurven. | Muss | I-009 |
| A-051 | Umfang je Woche und Monat: Zeit, Distanz, Anzahl der Einheiten, nach Sportart getrennt. | Muss | I-009 |
| A-052 | Pulszonen: Zeit je Zone pro Training und Zeitraum. Der Maximalpuls wird per Faustformel aus dem Geburtsjahr berechnet und ist von Hand überschreibbar. | Muss | I-009 |
| A-053 | Bestzeiten und Bestleistungen, z. B. schnellste 1 km / 5 km / 10 km, höchste Durchschnittsleistung auf Bike und SkiErg. | Muss | I-009 |
| A-054 | Trainings nachträglich bearbeiten (Titel, Sportart, Notiz) und löschen. | Soll | I-009 |

### 4.6 Daten und Dienste

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-060 | Alle Daten liegen lokal. Die App ist ohne Internet voll nutzbar, ausgenommen Synchronisation und Strava. | Muss | – |
| A-061 | Synchronisation von Trainings, Übungen, Programmen und Timer-Vorlagen zwischen den Geräten über Google Drive. Abgleich automatisch, sobald Internet besteht. Wurde derselbe Eintrag auf zwei Geräten geändert, gilt die jüngere Änderung. | Muss | I-015 |
| A-062 | Trainings als FIT-Datei exportieren. | Muss | I-010 |
| A-063 | Export als GPX und TCX; Import von FIT-, GPX- und TCX-Dateien. | Soll | I-010 |
| A-064 | Training mit einem Tipp zum eigenen Strava-Konto hochladen, mit Titel, Sportart und Indoor-Kennzeichen. | Muss | I-016 |
| A-065 | Automatischer Strava-Upload nach Trainingsende, abschaltbar. | Soll | I-016 |
| A-066 | Aktivitäten aus Strava importieren, mit Strecke und Puls (Aufzeichnungen der Uhr). Selbst hochgeladene Trainings werden nicht doppelt importiert. | Muss | I-017 |
| A-067 | Vor einem Strava-Upload prüft die App, ob dort im selben Zeitraum bereits eine ähnliche Aktivität liegt. Wenn ja, weist sie darauf hin und fragt, ob trotzdem hochgeladen werden soll. | Muss | I-016 |

### 4.7 Plattformen

| Nr. | Anforderung | Prio | Idee |
|-----|-------------|------|------|
| A-070 | Android-Smartphone und -Tablet; die Oberfläche passt sich Bildschirmgröße und Ausrichtung an. | Muss | – |
| A-071 | Windows-Version mit demselben Funktionsumfang, ohne GPS-Aufzeichnung. | Kann | I-014 |
| A-072 | Eigene Mini-App auf der Amazfit-Uhr für Live-Daten. | Kann | I-018 |

## 5. Nichtfunktionale Anforderungen

| Nr. | Anforderung |
|-----|-------------|
| N-01 | **Stabilität:** Kein Datenverlust während einer Aufzeichnung (siehe A-024). Ein Fehler in einem Gerätetreiber beendet nicht das Training. |
| N-02 | **Reaktionszeit:** Live-Werte erscheinen höchstens eine Sekunde nach Eintreffen. Die Bedienung bleibt während der Aufzeichnung flüssig. |
| N-03 | **Akku:** Eine zweistündige GPS-Aufzeichnung mit Pulssensor muss mit einer Akkuladung sicher möglich sein. |
| N-04 | **Datenschutz:** Daten verlassen das Gerät nur zum Google Drive des Nutzers und, auf dessen Veranlassung, zu Strava. Keine Werbung, keine Analyse-Dienste. |
| N-05 | **Bedienbarkeit im Training:** Große Schaltflächen, die wichtigsten Aktionen (Pause, Stopp, nächster Abschnitt) mit einem Tipp erreichbar. Helle und dunkle Darstellung. |
| N-06 | **Erweiterbarkeit:** Neue Gerätetypen und Sportarten lassen sich ergänzen, ohne bestehende Aufzeichnungen zu ändern. |
| N-07 | **Zukunftsfähigkeit:** Zugangsdaten zu Diensten sind so gekapselt, dass für eine Play-Store-Version ein Server-Dienst dazwischengeschaltet werden kann. |

## 6. Abgrenzung

Nicht Bestandteil dieser Version:

- iPhone und iPad.
- Mehrere Nutzerkonten, soziale Funktionen, Bestenlisten.
- Veröffentlichung im Play Store.
- Übungsvideos.
- Trainingspläne über Wochen (Periodisierung), Ernährung, Gewichtsverlauf.
- Virtuelle Strecken und Videos zum Indoor-Training, wie Kinomap sie bietet.
- Live-GPS von der Uhr; Strecken der Uhr kommen nachträglich über Strava (A-066).
- ANT+; alle Geräte werden über Bluetooth angebunden.

## 7. Umsetzungsreihenfolge (Vorschlag)

Jeder Meilenstein endet mit einer lauffähigen, nutzbaren App. Aufwand nach der Skala des Ideenspeichers.

| Nr. | Inhalt | Anforderungen | Aufwand |
|-----|--------|---------------|---------|
| M0 | **Technik-Prototyp:** Grundgerüst, Gerätesuche, Live-Puls vom Brustgurt. Auslesen, welche Werte und Steuerarten Laufband und Bike anbieten. Test der Uhr als Pulsquelle. Bluetooth-Test unter Windows. | A-001, A-002 | M |
| M1 | **Indoor-Aufzeichnung:** Laufband, Bike, SkiErg, mehrere Geräte gleichzeitig, Speichern, Trainingsliste mit Detailansicht. | A-003 – A-007, A-011, A-020, A-021, A-024, A-050, A-060, A-070 | L |
| M2 | **Intervall-Timer mit Gerätesteuerung.** | A-008 – A-010, A-030 – A-035 | L |
| M3 | **Trainingsprogramme:** Bibliothek mit den vorhandenen Grafiken, Programme bauen und abspielen. | A-040 – A-046 | L |
| M4 | **Outdoor:** GPS-Aufzeichnung, Runden, Karte. | A-022, A-023, A-025 | L |
| M5 | **Auswertung:** Umfang, Pulszonen, Bestzeiten. | A-051 – A-054 | L |
| M6 | **Export und Strava:** FIT-Export, Upload, Import. | A-062 – A-067 | L |
| M7 | **Synchronisation** über Google Drive. | A-061 | L |
| M8 | **Optional:** Windows, weitere Geräteprofile, Uhr-Mini-App. | A-006, A-071, A-072 | ? |

Begründung der Reihenfolge: M0 klärt die technischen Risiken, bevor viel gebaut wird. M1 und M2 bringen den größten Nutzen mit den vorhandenen Geräten. Die Synchronisation kommt spät, weil sie auf dem fertigen Datenmodell aufsetzt.

## 8. Risiken

| Nr. | Risiko | Umgang |
|-----|--------|--------|
| R-01 | Bluetooth unter Windows ist weniger ausgereift als unter Android. | Test in M0; Windows bleibt optional. |
| R-02 | Die Uhr lässt sich über „Heart Rate Push" nicht wie ein Standard-Pulssensor koppeln. | Test in M0; Brustgurt bleibt Hauptquelle. |
| R-03 | Laufband oder Bike nehmen nur einen Teil der Steuerbefehle an. | Auslesen in M0; der Timer nutzt, was das Gerät anbietet, sonst Ansage. |
| R-04 | Android beendet die GPS-Aufzeichnung im Hintergrund (Stromsparfunktionen einzelner Hersteller). | Vordergrunddienst mit Benachrichtigung; Test auf dem eigenen Phone in M4. |
| R-05 | Doppelte Aktivitäten bei Strava, wenn Uhr und App dasselbe Training aufzeichnen. | Hinweis und Nachfrage vor dem Upload (A-067). |
| R-06 | Strava ändert Bedingungen oder Grenzen seiner Schnittstelle. | FIT-Export (A-062) bleibt als unabhängiger Weg. **Eingetreten 2026-10-11:** Strava verlangt für die Schnittstelle ein Abo, das der Auftraggeber nicht hat. Upload von Hand per FIT-Datei, Uhr-Läufe über den Datei-Import (A-063). A-064 bis A-067 sind umgesetzt, aber nur mit Abo nutzbar und ungetestet. |
| R-07 | Synchronisationskonflikte führen zu Datenverlust. | Einfache Regel (A-061), gelöschte Einträge werden zunächst nur markiert. |

## 9. Offene Punkte

| Nr. | Punkt |
|-----|-------|
| O-01 | Erledigt 2026-10-11: Alle 80 Übungsgrafiken liegen vor und sind eingebunden. |
| O-02 | Die vorhandenen Grafiken sind noch nicht auf anatomische Richtigkeit geprüft. |
| O-03 | Erledigt 2026-10-11: Mindestversion Android 14; das Smartphone hat Android 17. |
| O-04 | Erledigt 2026-10-11: Die App weist hin und fragt nach (A-067). |
| O-05 | Crossfit- und Calisthenics-Übungen setzen Geräte voraus (Kettlebell, Langhantel, Box, Klimmzugstange, Barren u. a.). Sind sie vorhanden? |
| O-06 | Endgültiger Name der App. |
| O-07 | Erledigt 2026-10-11: Reihenfolge bestätigt. |

## 10. Abnahme

Ein Meilenstein gilt als abgenommen, wenn

1. alle ihm zugeordneten Muss-Anforderungen mit den eigenen Geräten des Auftraggebers funktionieren,
2. der Changelog die Änderungen mit Anforderungsnummern aufführt,
3. der Auftraggeber die Version auf seinem Phone und Tablet getestet und freigegeben hat.
