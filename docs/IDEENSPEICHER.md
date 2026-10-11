# Ideenspeicher

Jede Idee bekommt eine feste, fortlaufende Nummer (`I-001`, `I-002`, …). Nummern werden nie neu vergeben, auch nicht nach Verwerfen einer Idee.

**Aufwand** (grobe Schätzung, wird im Lastenheft verfeinert)

| Größe | Bedeutung |
|-------|-----------|
| S | bis ca. 1 Tag |
| M | ca. 2–5 Tage |
| L | ca. 1–3 Wochen |
| XL | mehr als 3 Wochen, muss zerlegt werden |
| ? | erst nach technischer Klärung schätzbar |

**Status:** `Neu` → `Geklärt` → `Geplant` → `In Arbeit` → `Umgesetzt` / `Verworfen`

**Quelle:** `Nutzer` = ausdrücklich gewünscht, `Vorschlag` = von Claude ergänzt, noch nicht bestätigt

## Übersicht

| Nr. | Titel | Bereich | Aufwand | Status | Quelle |
|-------|-------|---------|---------|--------|--------|
| I-001 | Brustgurt (BikePilot) per Bluetooth koppeln, Puls live anzeigen | Geräte | S | Umgesetzt | Nutzer |
| I-002 | Concept2 SkiErg (PM5) koppeln | Geräte | M | In Arbeit | Nutzer |
| I-003 | Domyos Challenge Bike koppeln (FTMS) | Geräte | M | In Arbeit | Nutzer |
| I-004 | Domyos Compact Run 100 (Laufband) koppeln (FTMS) | Geräte | M | In Arbeit | Nutzer |
| I-005 | Amazfit-Uhr einbinden (Live-Puls per Mini-App, GPS über Strava) | Geräte | S | In Arbeit | Nutzer |
| I-006 | Aufzeichnung draußen per Phone-GPS: Laufen, Spazieren, Wandern | Aufzeichnung | L | Geklärt | Nutzer |
| I-007 | Trainingsprogramme: Yoga, Crossfit, Calisthenics, Dehnen, mit kleiner Vorauswahl | Programme | L | Geklärt | Nutzer |
| I-008 | Intervall-Timer mit editierbaren Zeiten und Geschwindigkeiten | Timer | M | Umgesetzt | Nutzer |
| I-009 | Trainingshistorie mit Auswertung (Wochenumfang, Pulszonen, Bestzeiten) | Auswertung | L | Geklärt | Nutzer |
| I-010 | Export / Import von Dateien (FIT, GPX, TCX) | Daten | M | Neu | Vorschlag |
| I-011 | Intervall-Timer steuert Laufband-Geschwindigkeit automatisch | Timer / Geräte | M | In Arbeit | Nutzer |
| I-012 | Daten mehrerer Geräte in einer Einheit koppeln (z. B. Laufband + Brustgurt) | Geräte | M | Umgesetzt | Nutzer |
| I-013 | Geräteunabhängige Anbindung über Standardprofile, um möglichst viele Geräte abzudecken | Geräte | L | Neu | Nutzer |
| I-014 | Windows-Version für den Laptop (optional) | Plattform | ? | Neu | Nutzer |
| I-015 | Synchronisation der Trainings zwischen Phone, Tablet und Laptop über Google Drive | Daten | L | Geklärt | Nutzer |
| I-016 | Trainings direkt zum eigenen Strava-Konto hochladen | Strava | M | Geklärt | Nutzer |
| I-017 | Aktivitäten aus Strava importieren (u. a. Uhr-Aufzeichnungen mit GPS) | Strava | M | Geklärt | Nutzer |
| I-018 | Eigene Mini-App auf der Amazfit-Uhr für Live-Daten | Geräte | XL | Neu | Vorschlag |
| I-019 | Widerstand des Indoor-Bikes aus der App steuern (auch im Intervall-Timer) | Timer / Geräte | M | In Arbeit | Nutzer |
| I-020 | Comic-Grafiken zu den 80 Übungen einbinden (Erstellung extern) | Programme | S | Geklärt | Nutzer |

## Details

### I-001 – Brustgurt koppeln
Standard-Bluetooth-Herzfrequenzprofil. Technisch der einfachste Einstieg und Grundlage für alle anderen Aufzeichnungen.

### I-002 – Concept2 SkiErg
PM5-Monitor vorhanden (vom Nutzer bestätigt). Der PM5 hat Bluetooth und eine offen dokumentierte Schnittstelle.

### I-003 – Domyos Challenge Bike
Läuft über das Standardprofil für Fitnessgeräte (FTMS), vom Nutzer bestätigt (bereits mit QZ, Kinomap und der Domyos-App verbunden).

### I-004 – Domyos Compact Run 100
Läuft über FTMS, vom Nutzer bestätigt (bereits mit QZ, Kinomap und der Domyos-App verbunden).

### I-005 – Amazfit-Uhr
Gewünscht: Daten der Uhr nutzen, vor allem ihr GPS. Amazfit bietet keine offene Schnittstelle, über die eine Fremd-App die Uhr live auslesen kann. Wege (Recherche 2026-10-10):

1. **Puls live:** Zepp-OS-Uhren ab Version 3.0 können den Puls per Bluetooth senden („Heart Rate Push"), teils nur während eines laufenden Workouts. Auf der Uhr des Nutzers ist das die Mini-App „Heart Rate Push" aus dem App-Store der Zepp-App (vorhanden, 2026-10-10). Die Uhr ist damit voraussichtlich wie ein Brustgurt koppelbar (I-001); mit dem ersten Prototyp zu testen.
2. **GPS und komplette Aufzeichnung nachträglich:** Die Zepp-App synchronisiert zu Strava; von dort kann unsere App die Aktivität samt GPS-Strecke holen (I-017). Alternativ Datei-Import (I-010).
3. **GPS live:** nur über eine eigene Mini-App auf der Uhr denkbar (I-018), aufwendig und unsicher.

Health Connect als Weg ist nicht bestätigt.

### I-006 – Lauf-Aufzeichnung draußen
GPS-Strecke, Puls, Tempo, Distanz, Höhenmeter, Rundenzeiten. Erfordert Aufzeichnung im Hintergrund bei ausgeschaltetem Display. Sportarten: Laufen, Spazieren, Wandern. Hauptnutzung sind Spaziergänge und Wanderungen (Phone dabei); beim Joggen bleibt das Phone meist zu Hause, die Option soll es dort trotzdem geben.

### I-007 – Trainingsprogramme
Übungsbibliothek plus daraus zusammengesetzte Programme. Die App bringt eine Vorauswahl von 20 Übungen je Kategorie mit (siehe [Grafikliste](GRAFIKLISTE.md)); eigene Übungen und Programme lassen sich anlegen und ändern. Darstellung: Textbeschreibung plus Comic-Grafik je Übung (I-020), keine Videos.

### I-008 – Intervall-Timer
Der Timer soll Geräte aktiv ansteuern, nicht nur ansagen (Laufband: I-011, Bike: I-019). Ohne gekoppeltes Gerät, z. B. draußen, bleibt es bei Ansage und Signal.

Frei editierbare Abschnitte mit Dauer und Zielgeschwindigkeit, als Vorlage speicherbar. Signal beim Abschnittswechsel (Ton, Vibration, Sprache).

### I-009 – Trainingshistorie
Liste aller Einheiten, dazu ein Mix aus:
- Wochenumfang (Zeit, Distanz, Anzahl Einheiten; auch je Monat)
- Pulszonen (Zeit je Zone pro Einheit und Zeitraum). Der Maximalpuls wird per Faustformel aus dem Alter berechnet und ist von Hand überschreibbar; dafür braucht das Profil ein Geburtsjahr
- Bestzeiten (z. B. schnellste 1 km / 5 km / 10 km, beste Leistung auf Bike und SkiErg)

### I-010 – Export / Import
Daten bleiben nutzbar außerhalb der App; Übergabe an andere Plattformen. Das Erzeugen von FIT- oder TCX-Dateien ist zugleich Voraussetzung für den Strava-Upload (I-016).

### I-011 – Timer steuert Laufband
FTMS sieht Steuerbefehle grundsätzlich vor; das Laufband nimmt sie an (laut Nutzer hat QZ die Geschwindigkeit verstellt, 2026-10-10). Sicherheitsaspekt beachten: Geschwindigkeitsänderungen ankündigen, jederzeit abbrechbar.

### I-012 – Daten mehrerer Geräte koppeln
Mehrere Quellen laufen gleichzeitig in dieselbe Einheit, z. B. Geschwindigkeit vom Laufband und Puls vom Brustgurt, auf einer gemeinsamen Zeitachse. Zu regeln: welche Quelle gilt, wenn zwei Geräte denselben Wert liefern (z. B. Puls von Gurt und Uhr).

### I-013 – Geräteunabhängige Anbindung
Die App spricht Standardprofile statt einzelner Modelle: Fitnessgeräte (FTMS: Laufband, Bike, Crosstrainer, Rudergerät), Herzfrequenz, Trittfrequenz/Geschwindigkeit, Leistungsmesser, Laufsensoren, dazu Concept2 PM5. Damit funktionieren auch Geräte, die der Nutzer nicht besitzt. Geräte mit herstellereigenem Protokoll bleiben Einzelfälle.

### I-014 – Windows-Version
Optional. Gleiche App am Laptop. Bluetooth unter Windows ist das Hauptrisiko und früh zu testen; GPS-Aufzeichnung entfällt dort.

### I-015 – Synchronisation
Trainings, Programme und Timer-Vorlagen sind auf allen Geräten gleich. Jedes Gerät funktioniert weiter ohne Netz und gleicht ab, sobald es online ist. Ablageort: das Google Drive des Nutzers (entschieden 2026-10-10), kein eigener Server nötig. Zu regeln: Verhalten, wenn dasselbe Training auf zwei Geräten geändert wurde.

### I-016 – Strava-Upload
Laut Strava-Dokumentation (Stand 2026-10-10) machbar:
- Upload als FIT-, TCX- oder GPX-Datei, Berechtigung `activity:write`; Verarbeitung asynchron, Ergebnis wird abgefragt.
- Sportart, Titel, Beschreibung und „Indoor" lassen sich mitgeben; Aktivitäten ohne GPS gelten automatisch als Indoor.
- Strava erkennt Duplikate. Eigene eindeutige Kennung je Training mitsenden.
- Anmeldung per OAuth; Zugriffstoken gilt 6 Stunden und wird automatisch erneuert.
- Neue Strava-Apps sind auf einen Sportler (den Ersteller) begrenzt – für den Eigengebrauch ausreichend. Erweiterbar auf 10, darüber nur nach Prüfung durch Strava.
- Limits: 200 Anfragen je 15 Minuten, 2.000 je Tag – unkritisch.

Für eine spätere Play-Store-Version: Der Token-Tausch braucht das geheime App-Kennwort, das nicht in einer veröffentlichten App stecken darf. Dann ist ein kleiner Server-Dienst nötig.

Zu beachten: Nimmt die Uhr denselben Lauf auf und Zepp lädt ihn ebenfalls zu Strava, entsteht dort eine doppelte Aktivität.

### I-017 – Strava-Import
Aktivitäten aus dem eigenen Konto lesen (`activity:read_all`), inklusive GPS-Strecke und Puls. Der praktikabelste Weg, an die GPS-Daten der Uhr zu kommen (siehe I-005). Bei Strava-Daten sind die Nutzungsbedingungen der API zu beachten, sobald andere Nutzer dazukommen.

### I-018 – Mini-App auf der Uhr
Eigene Zepp-OS-App, die Sensordaten live ans Phone schickt. Ob GPS und Puls so in brauchbarer Rate herauskommen, ist ungeklärt. Nur verfolgen, wenn die Wege 1 und 2 aus I-005 nicht reichen.

### I-019 – Bike-Widerstand steuern
FTMS sieht drei Steuerarten vor: Widerstandsstufe setzen, Zielleistung in Watt halten, Steigung simulieren. Das Challenge Bike lässt sich steuern (laut Nutzer hat Kinomap den Widerstand verstellt, 2026-10-10). Welche der drei Arten es annimmt, meldet das Gerät selbst und wird mit dem ersten Prototyp ausgelesen.

### I-020 – Comic-Grafiken zu den Übungen
Je Übung eine kleine, einheitlich gestaltete Comic-Grafik. Umfang: 80 Grafiken, 20 je Kategorie. Der Nutzer lässt sie extern erstellen; Vorgaben und Einzelbeschreibungen stehen in der [Grafikliste](GRAFIKLISTE.md) (G-001 bis G-080). In der App bleibt das Einbinden. Eigene Übungen des Nutzers brauchen eine Möglichkeit, ein eigenes Bild zu hinterlegen.
