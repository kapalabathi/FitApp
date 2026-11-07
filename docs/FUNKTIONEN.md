# Funktionsbeschreibung FitApp

Stand: Version 0.23.0 (2026-11-07). Nummern in Klammern verweisen auf das [Lastenheft](LASTENHEFT.md) (A-…) und den [Ideenspeicher](IDEENSPEICHER.md) (I-…).

Die App hat fünf Bereiche, unten in der Navigationsleiste:

| Bereich | Wofür |
|---|---|
| **Training** | Training starten, Geräte wählen, Schnellstart, Zielpuls |
| **Programme** | Übungsbibliothek, Programme, Kurse, Atemübungen, WODs |
| **Intervalle** | Intervall-Vorlagen bauen und starten |
| **Verlauf** | Trainings, Auswertungen, Vergleich, Import, Synchronisation |
| **Geräte** | Bluetooth-Geräte suchen, merken, prüfen, Verbindung einstellen |

---

## 1. Geräte und Bluetooth

### 1.1 Unterstützte Gerätearten (A-002 – A-006)

| Art | Bluetooth-Profil | Werte |
|---|---|---|
| Laufband | FTMS (Fitness Machine Service) | Geschwindigkeit, Steigung, Strecke, Zeit, Energie |
| Indoor-Bike | FTMS | Leistung, Trittfrequenz, Geschwindigkeit, Widerstand, Strecke |
| Rudergerät, Crosstrainer | FTMS | Leistung, Schlag- oder Schrittfrequenz, Strecke, Tempo |
| Concept2 mit PM5 | Concept2-Protokoll | Leistung, Schlagfrequenz, Tempo je 500 m, Strecke |
| Pulsgurt, Uhr | Heart Rate Service | Puls |
| Leistungsmesser am Rad | Cycling Power | Leistung, Trittfrequenz aus Kurbeldaten |
| Tritt- und Geschwindigkeitssensor | Cycling Speed and Cadence | Trittfrequenz, Geschwindigkeit |
| Laufsensor am Schuh | Running Speed and Cadence | Tempo, Schrittfrequenz |

Die Amazfit-Uhr liefert ihren Puls über die Mini-App „Heart Rate Push" wie ein gewöhnlicher Pulsgurt.

### 1.2 Suchen und Merken (A-001, I-013, I-063)

- Die Suche zeigt alle Geräte in der Nähe und erkennt Fitnessgeräte an ihren Diensten, an den Dienstdaten der Werbepakete und am Namen (z. B. Domyos, Kettler, Technogym, Life Fitness). Wahrscheinliche Fitnessgeräte stehen oben.
- Ein Gerät wird mit eigenem Namen gemerkt. Unbekannte Geräte prüft die App beim Hinzufügen: Sie verbindet sich kurz und liest, welche Dienste es tatsächlich anbietet.
- Das Suchergebnis lässt sich als Text teilen, um ein Gerät im Studio zu bestimmen.
- Je Sportart lassen sich Geräte vorwählen; sie verbinden sich beim Trainingsstart von selbst.

### 1.3 Mehrere Geräte gleichzeitig (A-007)

Laufband, Pulsgurt und Laufsensor laufen in einem Training zusammen, alle Werte auf einer Zeitachse. Liefern zwei Geräte denselben Wert, etwa den Puls, ist die bevorzugte Quelle einstellbar.

### 1.4 Prüfen und Gerätebericht

Unter Geräte → ⋮ → „Prüfen und Gerätebericht" verbindet sich die App mit einem gemerkten Gerät und zeigt:

- Live-Werte
- was das Gerät über FTMS misst und was sich steuern lässt
- Einstellbereiche (kleinste und größte Geschwindigkeit, Widerstand, Leistung)
- alle Bluetooth-Dienste und -Merkmale mit Kennung und Eigenschaften
- die zuletzt empfangenen Rohdaten

Der Bericht lässt sich kopieren, etwa um ein Gerät zu untersuchen, das nicht wie erwartet funktioniert.

### 1.5 Verbindungsstabilität (A-011, I-055, I-056, I-064, I-065)

- **Weiterzeichnen:** Bricht eine Verbindung ab, läuft die Aufzeichnung weiter und die App verbindet von selbst neu. Beim ersten Versuch nach 0,6 Sekunden, danach alle 3 Sekunden. Neu gesucht wird erst nach drei Fehlversuchen, damit die übrigen Geräte nicht gestört werden.
- **Überbrücken:** Der letzte Wert eines Fitnessgeräts oder Pulssensors gilt 20 Sekunden lang weiter, Kurven und Pace bekommen bei kurzen Abbrüchen keine Lücke.
- **Verstummte Geräte:** Sendet ein Gerät 30 Sekunden lang nichts und antwortet nicht, baut die App die Verbindung neu auf.
- **Lebenszeichen:** Steuerbare Geräte bekommen alle 20 Sekunden ein Lebenszeichen, damit sie nicht wegen Stille trennen. Wählbar unter Geräte: Steuererlaubnis erbitten, Fähigkeiten lesen oder aus.
- **Schneller Funktakt:** Unter Geräte einschaltbar, für Geräte mit vielen Abbrüchen.
- **Protokoll:** Jeder Abbruch wird mit Zeitpunkt, Gerät, dem Grund laut Android und der Dauer gespeichert. Die Detailansicht eines Trainings zeigt unter „Verbindung" Anzahl, mittlere Dauer und Gründe; das Protokoll lässt sich als Text teilen. In der FIT-Datei steht jeder Abbruch als Ereignis.

---

## 2. Training aufzeichnen

### 2.1 Sportarten (A-020)

Laufband, Indoor-Bike, SkiErg, Laufen, Spazieren/Wandern, Radfahren, Yoga, Crossfit, Calisthenics, Dehnen und Sonstiges.

### 2.2 Trainingsansicht (A-021, I-034, I-035)

- Große Kacheln mit allen verfügbaren Werten, auf dem Tablet großflächig. Laufband, Laufen und Wandern zeigen min/km, der SkiErg min/500 m.
- Live-Kurve mit Puls und Geschwindigkeit der letzten Minuten.
- Kacheln je Sportart ein- und ausblendbar und verschiebbar, über „Anzeige" auf der Startseite oder das Regler-Symbol im Training.
- Pause, Weiter und Stopp mit einem Tipp; das Display bleibt an.

### 2.3 Aufzeichnung

- **Fortlaufend gesichert** (A-024): Nach Absturz oder leerem Akku bleibt das Training bis zu diesem Zeitpunkt erhalten.
- **Im Hintergrund** (I-022): Bei gesperrtem Display oder in einer anderen App läuft die Aufzeichnung weiter, Android zeigt „FitApp zeichnet auf".
- **Automatische Pause** (I-036): am Gerät nach 3 Sekunden Stillstand, draußen nach 10 Sekunden, beim Radfahren unter 3 km/h. Ein Verbindungsabbruch zählt nicht als Stillstand. Abschaltbar.
- **Laufband-Strecke:** Das Band zählt nur in 10-m-Schritten; dazwischen schreibt die App die Strecke aus der Geschwindigkeit fort.
- **Energieverbrauch** (I-044): Liefert kein Gerät einen Wert, schätzt die App ihn aus Puls, Gewicht, Alter und Geschlecht (Formel nach Keytel), gekennzeichnet mit „≈".

### 2.4 Draußen mit GPS (A-022, A-023, A-025, I-006, I-029)

- Strecke, Distanz, Tempo und Höhenmeter über das GPS des Phones.
- Runden automatisch je Kilometer (Radfahren je 5 km) und von Hand, mit Ansage.
- Nach dem Training die Strecke auf einer Karte.

### 2.5 Schnellstart (I-038)

Die Startseite zeigt die zuletzt gestarteten Trainings und Programme samt Geräten und Intervall. Ein Tipp startet sie erneut, der Stern macht einen Eintrag zum Favoriten.

---

## 3. Geräte steuern

### 3.1 Von Hand (A-008, A-009)

Sobald ein steuerbares Gerät verbunden ist, erscheinen in der Trainingsansicht Tasten: am Laufband Geschwindigkeit in Schritten von 0,5 km/h mit Schnellwahl, am Bike die Widerstandsstufe. Grenzen und Schrittweite meldet das Gerät selbst.

### 3.2 Sicherheit (A-010)

- Jederzeit mit einem Tipp stoppbar.
- Jede Erhöhung der Laufband-Geschwindigkeit wird vorher angesagt.
- Nach einem Verbindungsabbruch sendet die App keine Steuerbefehle, bis du bestätigst.

### 3.3 Intervall-Timer (A-030 – A-035, I-008)

- Vorlagen aus Abschnitten mit Bezeichnung, Dauer und Zielwert (Geschwindigkeit, Widerstand oder Leistung). Gruppen von Abschnitten lassen sich wiederholen.
- Vorlagen speichern, bearbeiten, duplizieren, löschen. Mitgeliefert sind z. B. „Lauf-Intervalle 5 × 2 min" und „Tabata 8 × 20/10".
- Ton und Vibration beim Wechsel, Vorwarnung kurz davor, Sprachansage des nächsten Abschnitts.
- Mit steuerbarem Gerät setzt der Timer den Zielwert selbst, ohne Gerät sagt er ihn an. Auch ganz ohne Zielwerte nutzbar, etwa für Crossfit-Runden.

### 3.4 Zielpuls halten (A-081, I-032)

Bei Laufband oder Bike mit Pulssensor lassen sich ein Zielpuls und eine Obergrenze wählen. Die App stellt das Gerät dann selbst nach:

- immer nur um einen Schritt, mit Ansage 3 Sekunden vorher
- frühestens alle 45 Sekunden, gesteigert wird erst nach 2 Minuten
- liegt der Puls 10 Schläge über dem Ziel, nimmt sie schneller zurück
- ohne frischen Puls ruht die Regelung, ein stehendes Band startet sie nie
- im Training mit einem Tipp abschaltbar

---

## 4. Übungen und Programme

### 4.1 Übungsbibliothek (A-040, A-041, A-046, A-047)

237 mitgelieferte Übungen: 70 Yoga, 59 Crossfit, 60 Calisthenics, 48 Dehnen. Jede hat:

- Name, bei Yoga auch den Sanskrit-Namen
- Beschreibung und Grafik
- trainierte Körperbereiche (Nacken, Schultern, Arme, Brust, Rücken, Bauch und Rumpf, Hüfte, Gesäß, Beine, Waden und Füße, Ganzkörper)
- Art der Haltung (Stehhaltung, Vorbeuge, Drehung, Rückbeuge, Umkehrhaltung, Stütz und Armbalance, Sitzen und Hüfte, Liegen und Entspannung)
- Schwierigkeit
- bei vielen einen Hinweis zur sicheren Ausführung
- eine leichtere und eine schwerere Variante, wo es sie gibt; z. B. aktives Hängen → Schulterblatt-Klimmzug → Jumping Pullup → Klimmzug mit Fußhilfe → negativer Klimmzug

Die Liste lässt sich nach Kategorie, Körperbereich und Art der Haltung filtern. Eigene Übungen mit eigenem Bild lassen sich anlegen, ändern und löschen. Fehlt eine Grafik, erscheint ein einheitlicher Platzhalter.

### 4.2 Programme (A-042 – A-045, A-048)

- Programme aus Übungen zusammenstellen: Reihenfolge, je Übung Dauer, Wiederholungen oder Atemzüge (ein Atemzug zählt 6 Sekunden), Pausen, Rundenzahl.
- 37 fertige Programme, z. B. Sonnengruß, Tabata, Crossfit leicht und fordernd, Calisthenics für Einsteiger, Weg zum Klimmzug, Kurzhantel-Zirkel, Hüftöffner, Abendruhe, dazu fünf kurze Routinen (Nach dem Lauf, Hüfte, Unterer Rücken, Zur Ruhe kommen, Nacken und Bildschirm).
- **Geführtes Abspielen:** aktuelle Übung mit Grafik, Countdown oder Wiederholungszahl, Vorschau auf die nächste, Signal beim Wechsel, Sicherheitshinweise.
- **Beide Seiten** (I-047): Einseitige Übungen laufen erst rechts, dann nach einem angesagten Seitenwechsel links.
- **Leichter/Schwerer** (I-059): Während des Programms lässt sich eine Übung mit einem Tipp gegen ihre Variante tauschen, auf Wunsch für alle weiteren Runden.
- **Kraft-Protokoll** (I-039): Bei Übungen mit Wiederholungen werden die geschafften Wiederholungen und das Gewicht eingetragen, das letzte Gewicht ist vorbelegt. Die Übungsseite zeigt den Verlauf.
- **Progression** (I-060): Wer im letzten Training 3 Sätze mit je mindestens 12 Wiederholungen geschafft hat, bekommt im Programm und auf der Übungsseite die schwerere Variante vorgeschlagen, bei Übungen mit Gewicht mehr Gewicht.
- Ein absolviertes Programm wird als Training gespeichert, mit Puls, wenn ein Sensor verbunden ist.

### 4.3 Yoga-Grundkurs (A-080, I-049)

Zwölf Wochen in sechs Stufen, drei Einheiten je Woche (Stehhaltungen; Vorbeugen und Hüfte; Rücken und Balance). Die Haltezeiten wachsen von 20 auf 60 Sekunden, ab Stufe 3 beginnt jede Einheit mit Sonnengrüßen, jede endet mit einer Umkehrhaltung. Eine Einheit dauert 11 bis 42 Minuten. Die App merkt sich den Fortschritt, schlägt die nächste Einheit vor und nach sechs Einheiten die nächste Stufe. Der Aufbau folgt den Ordnungsregeln aus [YOGA-STRUKTUR.md](YOGA-STRUKTUR.md).

### 4.4 Atemübungen (A-049, I-048)

Zwölf geführte Übungen, von der Bauchatmung über Ujjayi und Wechselatmung (Nadi Shodhana) bis zum Feueratem (Kapalabhati). Ein Kreis weitet sich beim Einatmen und zieht sich beim Ausatmen zusammen, mit Ansage und Nasenseite je Schritt und wählbarer Dauer. Längeres Atemanhalten bleibt gesperrt, bis es nach einem Warnhinweis freigeschaltet wird.

### 4.5 Crossfit-WODs mit Kamera (I-058, I-062)

- 50 Workouts: 28 Originale (z. B. Murph, Fran, Cindy, Grace, Helen) und 22 skalierte Fassungen für Klimmzugstange, Kurzhanteln und Körpergewicht. Jede skalierte Fassung nennt ihre Abweichungen einzeln.
- Formate: auf Zeit, so viel wie möglich in fester Zeit (AMRAP), jede Minute (EMOM) und Maximalwerte.
- **Kamera zählt mit:** Die Haltungserkennung (Google ML Kit) zählt Wiederholungen, etwa Liegestütz, Kniebeugen, Klimmzüge, Sit-ups, und schaltet selbst weiter. Front- oder Rückkamera wählbar, das erkannte Gerüst liegt über dem Bild, die App meldet, wenn du nicht richtig im Bild bist. Fehlzählungen lassen sich mit + und − korrigieren.
- **Läufe im Workout:** Die Laufzeit läuft, bis die nächste Übung ihre erste Wiederholung meldet.
- Ergebnis und Laufzeiten stehen in der Notiz des Trainings, die Bestzeit in der Liste.
- Die Bilder werden nur auf dem Phone ausgewertet und nicht gespeichert.

---

## 5. Auswertung

Der Verlauf hat fünf Reiter.

### 5.1 Trainings (A-050, A-054)

- Liste aller Trainings, filterbar nach Sportart und Zeitraum.
- Detailansicht mit Kennzahlen, Runden, Sätzen, Verbindungsprotokoll und Verlaufskurven für Puls, Pace oder Geschwindigkeit, Leistung, Frequenz und Höhe.
- Ein Schieber oder Tipp in eine Kurve wählt eine Stelle; alle Kurven zeigen ihren Wert am selben Zeitpunkt.
- Titel, Sportart und Notiz nachträglich ändern, Trainings löschen, mehrere auf einmal auswählen.

### 5.2 Umfang (A-051)

Zeit, Distanz und Anzahl der Einheiten je Woche und Monat, nach Sportart getrennt, als Balkendiagramm.

### 5.3 Pulszonen (A-052)

Zeit je Zone pro Training und Zeitraum. Der Maximalpuls kommt aus dem Geburtsjahr und ist von Hand überschreibbar.

### 5.4 Belastung (I-041)

Belastungspunkte aus der Zeit in den Pulsbereichen (nach Edwards), je Training und als Verlauf über zwölf Wochen mit Trend.

### 5.5 Bestwerte (A-053)

Schnellste 1 km, 5 km und 10 km, höchste Durchschnittsleistung auf Bike und SkiErg, Bestzeiten der WODs.

### 5.6 Vergleich (I-042)

Mehrere Trainings auswählen oder in einem Training „Alle Durchgänge vergleichen" wählen. Die Kurven liegen übereinander, wahlweise über Zeit oder Strecke, mit gemeinsamer Stelle zum Ablesen. Bis zu 30 Trainings, acht davon gleichzeitig sichtbar.

---

## 6. Daten und Dienste

### 6.1 Export und Import (A-062, A-063)

- **Export** als FIT, GPX oder TCX über den Teilen-Dialog. „FIT mit Trainingsort" gibt Indoor-Trainings einen festen Standort, um sie in Apps einzuspielen, die einen verlangen.
- **Import** von FIT, GPX und TCX, auch mehrere Dateien auf einmal. Übernommen werden Strecke, Zeit, Höhe, Puls, Frequenz, Leistung und Geschwindigkeit. Bereits vorhandene Trainings werden nicht doppelt importiert.

### 6.2 Strava (A-064 – A-067, I-026)

Upload einzeln oder mehrerer Trainings auf einmal, automatischer Upload nach Trainingsende, Import von Aktivitäten. Vor dem Upload prüft die App, ob bei Strava im selben Zeitraum schon eine ähnliche Aktivität liegt. Die Strava-Schnittstelle verlangt ein Abo; ohne Abo führt der Weg über den FIT-Export.

### 6.3 Synchronisation und Sicherung (A-061, I-015, I-045, I-066)

- **Google Drive:** Abgleich von Trainings, Übungen, Programmen, Vorlagen, Sätzen, Kursfortschritt und Verbindungsprotokoll zwischen Phone und Tablet. Bei Unterschieden gilt die jüngere Änderung, Gelöschtes wird überall gelöscht. Abgleich beim App-Start und nach jedem Training.
- **Sicherungsdatei:** alle Daten in einer Datei, auf einem anderen Gerät einspielbar; dabei wird zusammengeführt, nicht überschrieben.
- **Automatische Sicherung:** einmal am Tag in einen gewählten Ordner, je Wochentag eine Datei.
- Ist die App leer, etwa nach einer Neuinstallation, bietet die Startseite an, eine Sicherung einzuspielen.

---

## 7. Plattformen

- **Android** Phone und Tablet ab Android 14, die Oberfläche passt sich Größe und Ausrichtung an (A-070).
- **Windows und Linux** sind vorbereitet, aber noch nicht gebaut (A-071, I-014). Am PC entfallen Kamera und GPS, Export und Sicherung laufen über Ordner, die Anmeldung bei Google und Strava über den Browser. Siehe [DESKTOP.md](DESKTOP.md).

---

## 8. Stand der Erprobung

Alle Funktionen sind durch automatische Tests gedeckt (326). Am echten Gerät erprobt sind vor allem Laufband, Bike, SkiErg, Pulsgurt, Programme und Kamera. Nicht oder nur teilweise erprobt sind Google Drive gegen ein echtes Konto, Strava (mangels Abo), die weiteren Geräteprofile aus 1.1 und die Zählgenauigkeit der Kamera. Offene Prüfpunkte stehen in [MANUELLE-TESTS.md](MANUELLE-TESTS.md).

Bekanntes Problem: Das Domyos-Laufband trennt die Verbindung etwa alle 70 Sekunden. Die App überbrückt die Lücken; die Ursache wird untersucht.
