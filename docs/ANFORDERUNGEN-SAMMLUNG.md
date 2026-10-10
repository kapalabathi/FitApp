# Anforderungssammlung (Vorstufe zum Lastenheft)

Rohsammlung. Wird später zum Lastenheft verdichtet. Einzelne Funktionswünsche stehen nummeriert im [Ideenspeicher](IDEENSPEICHER.md).

## Ziel

Eine Fitness-App, die alle vorhandenen Trainingsgeräte und Sensoren in einer Anwendung zusammenführt, Läufe im Freien aufzeichnet, Trainingsprogramme anbietet und einen Intervall-Timer enthält.

## Anforderungen an den Entwicklungsprozess

- Transparent und nachvollziehbar
- Gepflegter [Changelog](../CHANGELOG.md)
- Ideenspeicher mit klarer Nummerierung und Aufwandsschätzung

## Vorhandene Geräte

| Gerät | Typ | Schnittstelle (Stand der Kenntnis) | Zu klären |
|-------|-----|------------------------------------|-----------|
| Domyos Compact Run 100 | Laufband | Bluetooth, FTMS (bestätigt; läuft mit QZ, Kinomap, Domyos-App) | Nimmt es Steuerbefehle an? |
| Domyos Challenge Bike | Heimtrainer | Bluetooth, FTMS (bestätigt; läuft mit QZ, Kinomap, Domyos-App) | – |
| Concept2 SkiErg | Ski-Ergometer | PM5: Bluetooth + ANT+ (bestätigt) | – |
| Amazfit Bip 6 (angegeben als „Bit 6") | Smartwatch | keine offene Schnittstelle | Genaues Modell; kann die Uhr den Puls per Bluetooth übertragen? |
| BikePilot Brustgurt | Pulsgurt | Bluetooth + ANT+ (Standardprofil) | – |

## Zielplattformen

- Android-Smartphone und Android-Tablet (Pflicht)
- Windows-Laptop (optional, I-014)

## Leitziele

- Möglichst viele Geräte und Varianten abdecken, nicht nur die eigenen (I-013)
- Daten aus mehreren Quellen sammeln und koppeln, z. B. Puls vom Brustgurt mit den Werten des Laufbands (I-012)
- Stabil und schnell; Wahl von Programmiersprache und Technik liegt bei Claude

## Technik (entschieden 2026-10-10, Wahl dem Entwickler überlassen)

Flutter (Sprache Dart): eine gemeinsame Codebasis für Android-Phone, Android-Tablet und Windows. Daten lokal in einer SQLite-Datenbank, Synchronisation über das Google Drive des Nutzers. Risiko: Bluetooth unter Windows ist weniger ausgereift als unter Android und wird früh mit einem Prototyp geprüft.

## Nutzungsgewohnheiten

- Joggen: in der Regel ohne Phone, nur mit Uhr. Die Strecke kommt dann nachträglich von der Uhr (I-017).
- Spaziergänge und Wanderungen: mit Phone. Aufzeichnung per Phone-GPS (I-006).
- Die Phone-Aufzeichnung soll trotzdem auch fürs Joggen wählbar sein.

## Funktionsbereiche

1. Geräteanbindung (I-001 bis I-005, I-012, I-013)
2. Lauf-Aufzeichnung im Freien (I-006)
3. Trainingsprogramme (I-007)
4. Intervall-Timer (I-008, I-011)
5. Auswertung und Datenaustausch (I-009, I-010, I-015)
6. Strava (I-016, I-017)

## Offene Fragen

| Nr. | Frage | Antwort |
|-----|-------|---------|
| F-01 | Auf welchen Geräten soll die App laufen (Android, iPhone, Tablet, PC)? | Android-Phone und -Tablet; Windows optional (2026-10-10) |
| F-02 | Nur für den Eigengebrauch oder später für andere Nutzer / App-Store? | Vorerst nur Eigengebrauch; Play Store später möglich, nicht verbauen (2026-10-10) |
| F-03 | Welcher Monitor sitzt am SkiErg? | PM5 (2026-10-10) |
| F-04 | Hat das Laufband Bluetooth, und mit welcher App wurde es bisher verbunden? | Ja, FTMS; QZ, Kinomap, Domyos-App (2026-10-10) |
| F-05 | Welche Rolle soll die Uhr spielen: nur Pulsquelle, oder auch Anzeige/Steuerung am Handgelenk? | Datenquelle, vor allem GPS (2026-10-10) |
| F-06 | Sollen Daten nur lokal auf dem Gerät liegen oder über mehrere Geräte synchronisiert werden? | Synchronisation gewünscht, I-015 (2026-10-10) |
| F-07 | Trainingsprogramme: Inhalte selbst anlegen oder mitgeliefert? Mit Bildern/Videos? | Kleine Vorauswahl mitliefern, mit Comic-Grafiken je Übung, I-020 (2026-10-10) |
| F-08 | Soll der Intervall-Timer das Laufband aktiv steuern oder nur ansagen? | Aktiv steuern; Bike ebenfalls gewünscht, I-019 (2026-10-10) |
| F-09 | Anbindung an Strava, Garmin Connect o. Ä. gewünscht? | Strava-Upload gewünscht, I-016 (2026-10-10) |
| F-10 | Bietet die Uhr „Heart Rate Push" / Herzfrequenz-Übertragung per Bluetooth an? (an der Uhr nachsehen) | Ja, als Mini-App „Heart Rate Push" (2026-10-10) |
| F-11 | Ist die Zepp-App bereits mit Strava verbunden? | Ja (2026-10-10) |
| F-12 | Beim Joggen: Phone dabei (dann Phone-GPS live) oder nur Uhr? | Joggen meist ohne Phone; Spaziergänge/Wanderungen mit Phone; Option trotzdem für alle Sportarten (2026-10-10) |
| F-13 | Wo sollen die synchronisierten Daten liegen: eigener Cloud-Speicher (z. B. Google Drive) oder Server-Dienst? | Google Drive (2026-10-10) |
| F-14 | Ändert das Challenge Bike den Widerstand in Kinomap oder QZ von selbst, oder nur per Handrad? | Kinomap verstellt das Bike, QZ das Laufband (2026-10-10) |
| F-15 | Welche Auswertungen sind wichtig? | Wochenumfang, Pulszonen, Bestzeiten (2026-10-10) |
| F-16 | Pulszonen: Maximalpuls bekannt oder Faustformel? | Faustformel-Rechner (2026-10-10) |
| F-17 | Comic-Grafiken: wie hergestellt, welcher Stil, wie viele Übungen zum Start? | 20 je Kategorie; Nutzer lässt sie nach der [Grafikliste](GRAFIKLISTE.md) erstellen (2026-10-10) |
