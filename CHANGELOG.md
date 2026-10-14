# Changelog

Alle nennenswerten Änderungen am Projekt werden hier festgehalten.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [Semantic Versioning](https://semver.org/lang/de/).
Einträge verweisen, wo möglich, auf die Nummer im [Ideenspeicher](docs/IDEENSPEICHER.md).

## [0.12.0] – 2026-10-14

### Hinzugefügt
- Vier Umkehrhaltungen (I-053), übernommen aus der Übungsliste (V-014, V-015, V-027, V-028): **Pflug** (Halasana), **Schulterstand** (Salamba Sarvangasana), **Unterarmstand an der Wand** (Pincha Mayurasana) und **Kopfstand** (Salamba Sirsasana). Alle mit Anleitung, Sicherheitshinweis und Gruppe „Umkehrhaltung"; der Delfin führt als leichtere Variante zum Kopfstand. Damit 164 Übungen.
- **Yoga-Grundkurs:** Ab Stufe 2 enden alle Einheiten mit Schulterstand und Pflug vor der Entspannung. Der Schulterstand wächst von 30 Sekunden auf 3 Minuten, der Pflug von 20 Sekunden auf 1 Minute; die Einheiten werden dadurch 1 bis 4 Minuten länger. Kopf- und Unterarmstand gehören bewusst nicht zum Kurs.
- Grafikliste um G-161 bis G-164 ergänzt. **Die Grafiken fehlen noch**; bis dahin zeigt die App den Platzhalter.
- Zwei automatische Tests dazu (insgesamt 230).

### Geändert
- Die Datenbank hat eine neue Fassung (11), die bestehenden Installationen die neuen Übungen nachträglich anlegt.

## [0.11.0] – 2026-10-14

Yoga-Struktur nach der Auswertung von „Light on Yoga" ([YOGA-STRUKTUR.md](docs/YOGA-STRUKTUR.md)), vom Nutzer ausgewählt: I-046 bis I-049, I-051, I-052. Alles ist durch automatische Tests gedeckt, aber **noch nicht am Gerät erprobt**.

### Hinzugefügt
- **Yoga-Grundkurs** (I-049): zwölf Wochen in sechs Stufen, drei Einheiten je Woche (Stehhaltungen; Vorbeugen und Hüfte; Rücken und Balance). Die Haltezeiten wachsen von 20 auf 60 Sekunden, ab Stufe 3 beginnt jede Einheit mit Sonnengrüßen. Eine Einheit dauert 8 bis 31 Minuten, dazu die Atemübung. Die App merkt sich den Fortschritt, schlägt die nächste Einheit vor und nach sechs Einheiten die nächste Stufe; die Stufe lässt sich auch wiederholen oder frei wählen. Der Fortschritt wandert bei der Synchronisation mit. Zu finden unter Programme → „Kurse & Atem". Der Kurs ist ein eigener Aufbau nach den Ordnungsregeln des Buches, keine Abschrift.
- **Geführte Atemübungen** (I-048): zwölf Übungen von der Bauchatmung über den siegreichen Atem (Ujjayi) und die Wechselatmung (Nadi Shodhana) bis zum Feueratem (Kapalabhati). Ein Kreis weitet sich mit dem Einatmen und zieht sich beim Ausatmen zusammen; Ansage und Nasenseite je Schritt, Dauer wählbar. Wird als Yoga-Training gespeichert, mit Puls, wenn ein Sensor verbunden ist.
- **Beide Seiten** (I-047): Einseitige Übungen laufen erst rechts, dann nach einem angesagten Seitenwechsel von 5 Sekunden links. Im Programm-Editor je Übung abschaltbar; neue Übungen übernehmen die Vorgabe der Übung.
- **Angaben je Übung** (I-046): Sanskrit-Name (Yoga), Art der Haltung (Stehhaltung, Vorbeuge, Drehung, Rückbeuge, Umkehrhaltung, Stütz und Armbalance, Sitzen und Hüfte, Liegen und Entspannung) und Schwierigkeit für alle 160 Übungen. Die Übungsliste lässt sich nach der Art der Haltung filtern.
- **Varianten** (I-051): 19 Ketten von leicht nach schwer, z. B. Liegestütz auf Knien → Liegestütz → Bogenschützen-Liegestütz oder Sphinx → Kobra → heraufschauender Hund. Die Übungsseite verlinkt die Varianten; eigene lassen sich im Editor festlegen.
- **Hinweise** (I-052): 23 Übungen haben einen Hinweis zur sicheren Ausführung, etwa Kamel, Delfin oder Handstand. Er erscheint auf der Übungsseite, beim Abspielen und gesammelt auf der Programmseite. Längeres Atemanhalten ist gesperrt, bis es nach einem Warnhinweis freigeschaltet wird; bis dahin lässt die App es weg.
- 25 automatische Tests dazu (insgesamt 228).

### Geändert
- Mitgelieferte Yoga- und Dehnprogramme, die einseitige Übungen über eine zweite Runde abgedeckt haben, laufen jetzt in einer Runde mit beiden Seiten. Nicht einseitige Übungen in diesen Programmen kommen dadurch nur noch einmal vor. Vom Nutzer veränderte Programme bleiben unberührt.
- Die Datenbank hat eine neue Fassung (10) mit den neuen Angaben je Übung. Sicherungen älterer Versionen lassen sich weiter einspielen.
- Lastenheft 1.2: Kurse und Atemübungen aufgenommen (A-047 bis A-049, A-080).

### Behoben
- Im Übungs-Editor ragte das Auswahlfeld für die Art der Haltung bei schmalem Bildschirm über den Rand.

## [0.10.0] – 2026-10-12

Sieben Vorschläge aus dem Ideenspeicher, vom Nutzer ausgewählt. Alles ist durch automatische Tests gedeckt, aber **noch nicht am Gerät erprobt**.

### Hinzugefügt
- Automatische Pause (I-036): Steht das Band oder bleibst du draußen stehen, hält die Zeit von selbst an und läuft bei Bewegung weiter. Am Gerät nach 3 s Stillstand, draußen nach 10 s. Ein Verbindungsabbruch gilt nicht als Stillstand. Wer von Hand auf „Weiter" tippt, wird erst nach erneuter Bewegung wieder automatisch pausiert. Abschaltbar auf der Startseite.
- Kraft-Protokoll (I-039): Bei Übungen mit Wiederholungen lassen sich im Programm die tatsächlich geschafften Wiederholungen und ein Gewicht eintragen; das zuletzt verwendete Gewicht ist vorbelegt. Jede Übung eines Programms wird als Satz gespeichert. Die Detailansicht eines Trainings zeigt die Sätze, die Seite einer Übung ihren Verlauf. Sätze wandern bei Sicherung und Synchronisation mit.
- Live-Kurve in der Trainingsansicht (I-034): Puls und Geschwindigkeit der letzten Minuten als Kurve unter den Kacheln.
- Kacheln der Trainingsansicht wählbar (I-035): Je Sportart lassen sich Kacheln ausblenden und in der Reihenfolge verschieben, ebenso die Live-Kurve. Erreichbar über „Anzeige" auf der Startseite und über das Regler-Symbol im Training.
- Schnellstart (I-038): Die Startseite zeigt die zuletzt gestarteten Trainings und Programme samt Geräten und Intervall; ein Tipp startet sie erneut. Der Stern macht einen Eintrag zum Favoriten, langes Drücken entfernt ihn.
- Energieverbrauch geschätzt (I-044): Liefert kein Gerät einen Wert, schätzt die App ihn aus Puls, Gewicht, Alter und Geschlecht (Formel nach Keytel). Gewicht und Geschlecht stehen im Profil bei den Pulszonen. Geschätzte Werte sind mit „≈" und „geschätzt" gekennzeichnet; ein Wert vom Gerät hat immer Vorrang.
- Automatische Sicherung (I-045): Unter „Synchronisation" lässt sich ein Ordner wählen, in den die App einmal am Tag eine Sicherungsdatei legt, je Wochentag eine. So liegen die Stände der letzten sieben Tage vor.
- Liste weiterer möglicher Übungen in [docs/UEBUNGEN-VORSCHLAEGE.md](docs/UEBUNGEN-VORSCHLAEGE.md). Sie ist nur eine Sammlung zur Auswahl; in der App ist davon nichts enthalten.
- 26 automatische Tests dazu (insgesamt 203).

### Geändert
- Die Datenbank hat eine neue Fassung (9) mit der Tabelle der Sätze. Bestehende Daten bleiben erhalten.
- Der Dialog „Maximalpuls" heißt jetzt „Profil".

## [0.9.7] – 2026-10-12

### Hinzugefügt
- Die letzten 36 Übungsgrafiken (G-125 bis G-160) sind eingebunden. Damit hat jede der 160 mitgelieferten Übungen ihr Bild (I-021 abgeschlossen); die Bilder belegen zusammen 1,6 MB.
- Ein automatischer Test prüft, dass zu jeder mitgelieferten Übung die Grafik beiliegt (insgesamt 177).

## [0.9.6] – 2026-10-12

### Hinzugefügt
- Export „FIT mit Trainingsort" (Wunsch des Nutzers): Ein Training ohne eigene Strecke, etwa vom Laufband, bekommt in jedem Messpunkt den gemerkten Trainingsort als Standort. Beim ersten Export merkt sich die App dafür den aktuellen Standort des Geräts; über „Trainingsort neu festlegen" im Menü der Detailansicht lässt er sich ändern. Gedacht als Versuch, solche Dateien in die Zepp-App einzuspielen; ob Zepp sie annimmt, ist offen.
- Der gewöhnliche FIT-Export bleibt unverändert ohne Standort.
- Zwei automatische Tests dazu (insgesamt 176).

## [0.9.5] – 2026-10-12

Anlass: Der Nutzer hat eine aus der Zepp-App exportierte FIT-Datei eines Laufs bereitgestellt. Der Datei-Import liest sie vollständig: Sportart, 1609 Messpunkte, Strecke, Puls, Standort, Geschwindigkeit, Schrittfrequenz.

### Behoben
- Schrittfrequenz aus FIT-Dateien: FIT zählt beim Laufen und Gehen die Schritte eines Beins. Die App zeigt jetzt die Schritte beider Beine (160 statt 80 je Minute) und schreibt beim Export wieder den FIT-Wert.
- Uhren ohne Leistungsmessung schreiben durchgehend 0 W in die Datei. Das erschien nach dem Import als Leistung von 0 W samt Bestwerten von 0 W; solche Dateien werden jetzt ohne Leistung übernommen.

### Hinzugefügt
- Zwei automatische Tests dazu (insgesamt 174).

## [0.9.4] – 2026-10-12

### Hinzugefügt
- Hintergrund-Dienst für Trainings mit Bluetooth-Geräten (I-022): Die Aufzeichnung läuft bei gesperrtem Display und in einer anderen App weiter; Android zeigt währenddessen die Benachrichtigung „FitApp zeichnet auf". **Noch nicht am Gerät erprobt.**

### Geändert
- Ideenspeicher auf den aktuellen Stand gebracht: neuer Status „Umgesetzt, ungetestet", neue Ideen I-022 bis I-030.

## [0.9.3] – 2026-10-11

### Hinzugefügt
- Schieber unter jeder Verlaufskurve in der Detailansicht eines Trainings (Wunsch des Nutzers): Er wählt eine Stelle, über der Kurve stehen dann Zeit und Wert, etwa „bei 12:34: 152,0 /min". In der Kurve markieren eine senkrechte Linie und ein Punkt die Stelle.
- Ein Tipp oder Wischen direkt in der Kurve wählt die Stelle ebenfalls.
- Alle Kurven eines Trainings teilen sich die Stelle: Wer den Puls bei Minute 12 ansieht, sieht Pace, Leistung und die übrigen Werte am selben Zeitpunkt.
- Ein weiterer automatischer Test (insgesamt 172).

## [0.9.2] – 2026-10-11

Anlass: erster Lauf des Nutzers auf dem Laufband mit Steuerung; ausgewertet anhand der exportierten FIT-Datei (24,5 Minuten, 20 Verbindungsabbrüche).

### Behoben
- Verbindungsabbrüche zum Laufband: Die Datei zeigt Abbrüche in sehr gleichmäßigem Abstand von rund 73 Sekunden. Vermutete Ursache: Das Band trennt, wenn es etwa eine Minute nichts von der App empfängt. Die App sendet einem steuerbaren Fitnessgerät jetzt alle 20 Sekunden ein Lebenszeichen. **Ob das die Abbrüche beendet, muss der nächste Lauf zeigen.**
- Nach einem Abbruch verbindet die App einmal sofort neu, statt erst 3 Sekunden zu warten und 4 Sekunden zu suchen. Eine Lücke dauert damit voraussichtlich 1 bis 2 statt 9 Sekunden und bleibt in den Daten unsichtbar.
- Sprünge in Strecke und Pace: Das Laufband zählt die Strecke nur in 10-m-Schritten. Zwischen zwei Zählerschritten schreibt die App die Strecke jetzt aus der Geschwindigkeit fort und richtet sich bei jedem Schritt wieder am Zähler aus.

### Geändert
- Kachel „Tempo /km" heißt „min/km" (Wunsch des Nutzers); beim SkiErg „min/500 m". Wo es eine Pace gibt (Laufband, Laufen, Spazieren/Wandern, SkiErg), entfällt die Kachel mit km/h.
- Detailansicht: Bei diesen Sportarten zeigt die Kurve die Pace statt der Geschwindigkeit; die schnellere Pace liegt oben.
- Verlaufskurven beschriften den oberen und unteren Wert mit „max" und „min" samt Einheit.
- Umfang: Über dem Diagramm stehen Größe, Einheit und größter Wert, über jedem Balken sein Wert.
- Drei weitere automatische Tests (insgesamt 171).

## [0.9.1] – 2026-10-11

### Behoben
- Im Raster der Übungen wurden Namen, die zwei Zeilen brauchen, unten abgeschnitten (gemeldet vom Nutzer). Jede Kachel reserviert jetzt Platz für zwei Zeilen in der eingestellten Schriftgröße, auch bei vergrößerter Systemschrift.

### Hinzugefügt
- 44 weitere Übungsgrafiken eingebunden; damit sind 124 von 160 vorhanden.
- Zwei automatische Tests für das Raster bei normaler und großer Schrift (insgesamt 168).

## [0.9.0] – 2026-10-11 (M7: Synchronisation, M8: weitere Geräteprofile)

### Hinzugefügt – Synchronisation (M7)
- Abgleich der Daten zwischen Geräten (A-061): Trainings mit Messpunkten und Runden, Intervall-Vorlagen, Übungen, Programme, Geburtsjahr und Maximalpuls. Bei Unterschieden gilt die jüngere Änderung; Gelöschtes wird überall gelöscht.
- Sicherungsdatei: alle Daten in einer Datei erstellen und auf einem anderen Gerät einspielen; dabei wird zusammengeführt, nicht überschrieben. Funktioniert ohne Einrichtung.
- Google Drive als Ablageort mit automatischem Abgleich beim App-Start und nach jedem Training. Braucht eine einmalige Einrichtung in der Google-Cloud-Konsole, siehe `docs/GOOGLE-DRIVE-EINRICHTUNG.md`. **Noch nicht gegen ein echtes Google-Konto erprobt.**
- Zugang über das Synchronisations-Symbol im Verlauf.

### Hinzugefügt – weitere Geräteprofile (M8, A-006)
- Leistungsmesser am Rad (mit Trittfrequenz aus den Kurbeldaten), Tritt- und Geschwindigkeitssensoren, Laufsensoren am Schuh, Rudergeräte und Crosstrainer über FTMS. Nach dem jeweiligen Bluetooth-Standard umgesetzt, **an keinem solchen Gerät erprobt**.

### Geändert
- Mitgelieferte Übungen, Programme und Vorlagen tragen jetzt auf allen Geräten dieselbe Kennung, solange sie unverändert sind; so verdoppeln sie sich beim Abgleich nicht.
- 24 weitere automatische Tests (insgesamt 166), darunter der Abgleich zwischen zwei simulierten Geräten.

### Offen aus M8
- Windows-Version (A-071): braucht die Visual Studio Build Tools; noch nicht begonnen.
- Mini-App auf der Uhr (A-072): nicht umgesetzt, siehe Ideenspeicher I-018.

## [0.8.1] – 2026-10-11

### Hinzugefügt
- Steuerung von Hand in der Trainingsansicht (Wunsch des Nutzers, A-008, A-009): am Laufband Geschwindigkeit in Schritten von 0,5 km/h mit Schnellwahl-Tasten, am Indoor-Bike die Widerstandsstufe in ganzen Schritten. Die Tasten erscheinen, sobald ein steuerbares Gerät verbunden ist, auch ohne Intervall-Vorlage. **Noch an keinem Gerät erprobt.**
- Grenzen und Schrittweite kommen vom Gerät, sofern es sie nennt; sonst gelten 1 bis 16 km/h und Stufe 1 bis 32.
- Ein weiterer automatischer Test (insgesamt 142).

## [0.8.0] – 2026-10-11

### Hinzugefügt
- 80 weitere Übungen ohne Geräte, je 20 für Yoga, Crossfit, Calisthenics und Dehnen (Wunsch des Nutzers); die Bibliothek umfasst jetzt 160 Übungen. Ihre Grafiken (G-081 bis G-160) stehen noch aus; bis dahin erscheint der Platzhalter.
- Körperbereiche je Übung (Nacken, Schultern, Arme, Brust, Rücken, Bauch und Rumpf, Hüfte, Gesäß, Beine, Waden und Füße, Ganzkörper), für alle 160 Übungen eingetragen und bei eigenen Übungen wählbar. Anzeige in der Übung, beim Abspielen und zusammengefasst je Programm; die Bibliothek lässt sich nach Körperbereich filtern.
- 19 weitere Programme ohne Geräte, viele in zwei Varianten: Sonnengruß mit 3 oder 6 Runden, Tabata mit 4 oder 8 Minuten, Crossfit leicht oder fordernd, Calisthenics für Einsteiger oder Fortgeschrittene, Rumpf kurz oder lang, Dehnen kurz oder lang, dazu Hüftöffner, Rücken, Balance, Abendruhe, Hüfte und Beine, Nacken und Schultern.
- Zwei weitere automatische Tests (insgesamt 141).

### Geändert
- Bestehende Installationen bekommen die neuen Übungen und Programme beim ersten Start; eigene und geänderte Übungen bleiben unberührt.
- Die Texte und Körperbereiche der Übungen liegen jetzt in `tools/uebungen.json`.

## [0.7.0] – 2026-10-11

### Hinzugefügt
- Import von FIT-, GPX- und TCX-Dateien (A-063) über das Datei-Symbol im Verlauf, auch mehrere auf einmal. Übernommen werden Strecke, Zeit, Höhe, Puls, Frequenz, Leistung und Geschwindigkeit, soweit die Datei sie enthält; fehlende Strecke und Geschwindigkeit werden aus den Standorten berechnet. Dieser Weg ersetzt den Strava-Import für Nutzer ohne Strava-Abo.
- Die Sportart kommt aus der Datei; nennt sie keine, entscheidet das Durchschnittstempo. Sie lässt sich danach ändern.
- Eine Datei, deren Training schon vorhanden ist (gleicher Beginn), wird nicht doppelt importiert; unlesbare Dateien werden mit Grund genannt.
- Zehn weitere automatische Tests (insgesamt 139), darunter das Wiedereinlesen der eigenen FIT- und TCX-Exporte.

### Geändert
- Hinweis in der App: Strava erlaubt die direkte Verbindung nur Mitgliedern mit Abo (Stand der Strava-Dokumentation vom 2026-10-11). Ohne Abo: FIT exportieren und bei Strava von Hand hochladen.

## [0.6.1] – 2026-10-11

### Hinzugefügt
- Mehrfachauswahl im Verlauf (Wunsch des Nutzers): Langes Drücken auf ein Training beginnt die Auswahl, weiteres Tippen wählt hinzu oder ab. Die Kopfzeile bietet dann „Alle auswählen", Export als FIT, GPX oder TCX und Löschen. Beim GPX-Export werden Trainings ohne Strecke ausgelassen und gezählt.
- Alle 80 Übungsgrafiken sind eingebunden (I-020 abgeschlossen); der Platzhalter erscheint nur noch bei eigenen Übungen ohne Bild.
- Vier weitere automatische Tests (insgesamt 129).

### Geändert
- Exportdateien tragen zusätzlich die Nummer des Trainings im Namen, damit sich mehrere Dateien derselben Minute nicht überschreiben.
- `tools/uebungen_erzeugen.py` nimmt den Ordner der Rohbilder als Angabe entgegen.

## [0.6.0] – 2026-10-11 (M6: Export und Strava)

### Hinzugefügt
- Export eines Trainings als FIT-Datei (A-062), dazu GPX und TCX (A-063), über das Menü der Detailansicht. Die Datei geht an das Teilen-Menü von Android.
- Strava-Verbindung mit eigener Strava-Anwendung des Nutzers; Einrichtung im Verlauf über das Wolken-Symbol. Zugangsdaten liegen im verschlüsselten Speicher des Geräts, nicht in der Datenbank.
- Upload eines Trainings zu Strava mit Titel, Notiz, Sportart und Indoor-Kennzeichen (A-064). **Noch nicht gegen das echte Strava erprobt.**
- Vor jedem Upload prüft die App, ob bei Strava im selben Zeitraum schon eine Aktivität liegt, und fragt dann nach (A-067).
- Automatischer Upload nach Trainingsende, einschaltbar; bei einer ähnlichen Aktivität unterbleibt er mit Hinweis (A-065).
- Import neuer Strava-Aktivitäten mit Strecke, Puls, Höhe und Tempo, etwa Läufe von der Uhr (A-066). Eigene Uploads und bereits Bekanntes werden übersprungen; ein gelöschter Import kommt nicht zurück.
- Im Verlauf zeigt ein Wolken-Symbol, ob ein Training hochgeladen oder importiert ist.
- 25 weitere automatische Tests (insgesamt 125). Der FIT-Export wird darin von einer unabhängigen Bibliothek gelesen und geprüft; Strava wird durch eine Attrappe ersetzt.

### Geändert
- „Training löschen" liegt jetzt im Menü der Detailansicht.
- Bestzeiten rechnen bei lückenhaften Messpunkten (importierte Trainings) mit der tatsächlichen Zeit.

### Offen
- Import von FIT-, GPX- und TCX-Dateien (Teil von A-063, Soll) ist noch nicht umgesetzt.

## [0.5.0] – 2026-10-11 (M5: Auswertung)

### Hinzugefügt
- Der Verlauf hat vier Reiter: Trainings, Umfang, Pulszonen, Bestwerte.
- Umfang (A-051): Balken der letzten zwölf Wochen oder Monate nach Zeit, Distanz oder Anzahl; ein Tipp auf einen Balken zeigt die Summen je Sportart.
- Pulszonen (A-052): Zeit je Zone für 7, 30, 365 Tage oder gesamt, außerdem in der Detailansicht jedes Trainings. Der Maximalpuls ergibt sich aus dem Geburtsjahr nach der Faustformel 220 minus Lebensalter und lässt sich durch einen eigenen Wert ersetzen.
- Bestwerte (A-053) je Sportart: schnellste 1, 5 und 10 km beim Laufen und auf dem Laufband; schnellste 500 m, 1 km, 5 km und beste Leistung über 1, 5 und 20 Minuten am SkiErg; beste Leistung über 1, 5 und 20 Minuten am Bike; dazu längstes Training, weiteste Strecke, größter Anstieg und höchste Durchschnittsleistung. Ein Tipp öffnet das zugehörige Training.
- Trainings nachträglich bearbeiten (A-054): Titel, Sportart und Notiz.
- 15 weitere automatische Tests (insgesamt 100).

### Geändert
- Bestwerte werden beim Beenden eines Trainings berechnet und gemerkt; für ältere Trainings holt die App das beim ersten Öffnen der Bestwerte nach.

## [0.4.2] – 2026-10-11

### Geändert
- Spazieren und Wandern sind zu einer Sportart „Spazieren/Wandern" zusammengelegt (Wunsch des Nutzers, Lastenheft 1.1, A-020). Bereits aufgezeichnete Spaziergänge erscheinen im Verlauf unter der gemeinsamen Sportart; ihre Daten bleiben unverändert.

## [0.4.1] – 2026-10-11

### Behoben
- Geschwindigkeitssprünge bei schwachem GPS-Signal (gemeldet vom Nutzer). Die Geschwindigkeit ist jetzt der Median der letzten sieben Messungen; Werte, die für die Sportart unmöglich sind oder die das GPS selbst als unsicher meldet, werden nicht gewertet.
- Positionssprünge zählen nicht mehr als Strecke: Ein Standort, der nur mit dem 1,5-Fachen der für die Sportart plausiblen Geschwindigkeit erreichbar wäre, wird verworfen (Grenze beim Laufen 36 km/h, beim Spazieren und Wandern 18 km/h).
- Bei ungenauem Standort zählt eine Bewegung erst ab der halben gemeldeten Ungenauigkeit als Strecke; Standorte ungenauer als 25 m (bisher 30 m) werden verworfen.
- Verlaufskurven zeigen den größten und kleinsten Wert jetzt mit Einheit an der Achse (gemeldet vom Nutzer); auch der Durchschnitt trägt die Einheit.

### Hinzugefügt
- Vier automatische Tests für die GPS-Filter (insgesamt 84).

## [0.4.0] – 2026-10-11 (M3: Trainingsprogramme, M4: Outdoor)

### Hinzugefügt – Trainingsprogramme (M3)
- Neuer Bereich „Programme" mit Übungsbibliothek: 80 mitgelieferte Übungen, je 20 für Yoga, Crossfit, Calisthenics und Dehnen, jeweils mit Anleitung (A-040).
- 57 Übungsgrafiken eingebunden, verkleinert auf 512 px; die 23 fehlenden zeigen einen Platzhalter (A-046, I-020).
- Eigene Übungen anlegen, ändern, löschen; eigenes Bild aus der Galerie (A-041).
- Programme zusammenstellen: Reihenfolge per Ziehen, je Übung Zeit oder Wiederholungen, Pause danach, Rundenzahl (A-042).
- Geführtes Abspielen: Grafik, Anleitung, Countdown oder Wiederholungszahl mit „Fertig", Pausen mit Vorschau, Töne, Vibration und Ansage (A-043).
- Sieben mitgelieferte Programme (A-044).
- Ein absolviertes Programm wird als Training gespeichert, mit Puls von den gewählten Pulssensoren (A-045).
- Skript `tools/uebungen_erzeugen.py`: erzeugt Übungsdaten und verkleinerte Bilder aus der Grafikliste; nach neuen Bildern erneut ausführen.

### Hinzugefügt – Outdoor (M4)
- Sportarten Laufen, Spazieren und Wandern mit Aufzeichnung über das GPS des Phones: Strecke, Distanz, Tempo, Anstieg (A-022).
- Aufzeichnung läuft bei ausgeschaltetem Display und im Hintergrund weiter, über einen Dienst mit dauerhafter Benachrichtigung. **Noch nicht im Freien erprobt.**
- Runden: automatisch nach jedem Kilometer mit Ansage der Rundenzeit (auch auf dem Laufband), zusätzlich von Hand über das Fähnchen (A-023).
- Streckenkarte (OpenStreetMap), Rundentabelle und Höhenprofil in der Detailansicht (A-025).
- Filter gegen ungenaue Standorte, Zittern im Stand und Höhenrauschen; der Weg während einer Pause zählt nicht.

### Geändert
- Die Aufzeichnung richtet sich nach der Uhr statt nach dem Zeitgeber: Sekunden, die Android im Hintergrund verschluckt, werden nachgeholt.
- 17 weitere automatische Tests (insgesamt 80).

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
