# Manuelle Tests

Stand: Version 0.23.0 (2026-11-07). Alles hier ist durch automatische Tests gedeckt, lief aber noch nicht oder nur teilweise am echten Gerät. Die Nummern in Klammern verweisen auf den [Ideenspeicher](IDEENSPEICHER.md).

## 1 Zuerst: Update ohne Datenverlust

- [ ] Vor dem Update unter Synchronisation „Sicherung erstellen" tippen und die Datei außerhalb des Phones ablegen.
- [ ] Automatische Sicherung einschalten: Ordner wählen, prüfen, ob die Datei dort liegt (I-045).
- [ ] Neue APK **über die alte** installieren, nicht vorher deinstallieren. Meldung von Android notieren.
- [ ] Sind alle Trainings noch da? Falls nicht: Wie genau wurde installiert?
- [ ] Bei leerer App erscheint oben der Hinweis auf eine Sicherung (I-066).
- [ ] Sicherung testweise einspielen: Nichts darf doppelt erscheinen.

## 2 Kamera und Workouts

- [ ] Kniebeugen: 10 saubere Wiederholungen, von der Seite. Wie viele zählt die App?
- [ ] Dasselbe für Liegestütze, Klimmzüge, Burpees, Sit-ups, Pike-Liegestütze und Bank-Dips, je 10 (I-062).
- [ ] Gerüst: Liegt es auf dem Körper? Zittert oder flackert es noch?
- [ ] Kamera im Training wechseln: Läuft der Zähler weiter, stimmt das Gerüst bei der Frontkamera?
- [ ] Am Querformat-Stand: Wird weiter erkannt?
- [ ] +, − und „Weiter" funktionieren.
- [ ] Murph, halbe Menge mit Lauf: Endet der Lauf mit dem ersten Klimmzug? Stehen die Laufzeiten in der Notiz?
- [ ] Letzter Lauf endet mit „Lauf beendet", das Workout wird gespeichert.
- [ ] Cindy, kurz (I-058): Endet es nach 10 Minuten von selbst? Stimmt das Ergebnis in der Notiz?
- [ ] Chelsea, kurz: Pause bis zur nächsten Minute sichtbar? Endet es, wenn eine Minute nicht geschafft wird?
- [ ] Nicole, kurz: Beendet „Weiter" die Klimmzug-Serie und startet wieder den Lauf?
- [ ] Lynne, skaliert: Zählen alle Serien zusammen?
- [ ] Barbara: Läuft die 3-Minuten-Pause von selbst ab?
- [ ] Bestwert erscheint in der Liste, ein abgebrochenes Workout zählt nicht.
- [ ] Akku und Wärme bei 20 Minuten Kamera notieren.

## 3 Laufband und Verbindung

- [ ] Nach dem Lauf im Training den Abschnitt „Verbindung" ansehen: Welche Geräte, welcher Grund (I-055)?
- [ ] Mit Brustgurt: Bricht der Gurt zugleich mit dem Band ab? Steht er in der Trainingsansicht als verbunden?
- [ ] Mit Uhr: Läuft der Puls bei Abbrüchen des Bands weiter?
- [ ] Kurve, Pace und FIT haben keine Lücken mehr (I-056).
- [ ] FIT exportieren: Enthält sie die Abbrüche? Datei schicken.
- [ ] Automatische Pause: Band anhalten, weiterlaufen (I-036).
- [ ] Display sperren: Läuft die Aufzeichnung weiter (I-022)?

- [ ] Bei Abbrüchen eine Einheit mit „Schneller Funktakt" unter Geräte laufen und die Zahl der Abbrüche vergleichen (I-064). Wird es schlechter, wieder ausschalten.
- [ ] Erscheint im Abschnitt „Verbindung" der Grund „keine Daten mehr"?
- [ ] Nach jedem Lauf „Protokoll teilen" und schicken.
- [ ] Lebenszeichen unter Geräte nacheinander auf „Lesen" und „Aus" stellen, je ein Lauf von mindestens 10 Minuten (I-065). Ändert sich der Abstand der Abbrüche von etwa 70 s?

## 4 Zielpuls (I-032)

Hand am Not-Stopp, Obergrenze vorsichtig wählen.

- [ ] Zielpuls ist nur mit Gerät und Pulssensor wählbar.
- [ ] Vor jeder Änderung kommt eine Ansage.
- [ ] Steigerung erst nach 2 Minuten, dann in kleinen Schritten.
- [ ] Die Obergrenze wird nie überschritten.
- [ ] Puls deutlich zu hoch: Geht das Band schneller zurück?
- [ ] Sensor aus: Die Regelung ruht, die Anzeige sagt das.
- [ ] Band von Hand anhalten: Es startet nicht von selbst.
- [ ] „Stoppen" beendet die Regelung.
- [ ] Bleibt der Puls ruhig, oder schwingt er hin und her?

## 4a Vergleich und Belastung

- [ ] Ein Workout mehrmals: Im Training „Alle Durchgänge vergleichen", Kurven und Legende passen (I-042).
- [ ] Im Verlauf zwei Läufe auswählen, vergleichen, zwischen Zeit und Strecke wechseln.
- [ ] Neuer Reiter „Belastung": Werte plausibel? Das Training zeigt dieselbe Zahl (I-041).

## 4b Geräte im Studio (I-063)

- [ ] Suchen, Filter aus, Teilen-Knopf: Liste schicken.
- [ ] Unbekanntes Gerät antippen: Was meldet die Prüfung?

## 5 Bike und SkiErg

- [ ] Indoor-Bike koppeln, Werte kommen an (I-003).
- [ ] Widerstand von Hand und im Intervall-Timer stellen (I-019).
- [ ] SkiErg koppeln, Werte kommen an (I-002).

## 6 Draußen

- [ ] Radfahren: Strecke, Tempo, Ansage alle 5 km, automatische Pause an der Ampel (I-029).
- [ ] Spaziergang mit 0.20: Fallen Stopps über 10 Sekunden aus der Zeit?

## 7 Programme und Yoga

- [ ] Programm mit „beide Seiten": Seitenwechsel, Ansage, Zeit stimmen (I-047).
- [ ] „Leichter/Schwerer" tauschen die Übung, auch in späteren Runden (I-059).
- [ ] Wiederholungen und Gewicht eintragen, Verlauf auf der Übungsseite (I-039).
- [ ] Yoga-Grundkurs: eine Einheit, dann die Atemübung, Fortschritt zählt mit (I-049).
- [ ] Atemübung: Passt der Kreis zu den Ansagen? Wechselatmung sagt die Nasenseite (I-048).
- [ ] Atemanhalten erst nach Freischaltung (I-052).
- [ ] Routine „Nach dem Lauf" einmal durchspielen (I-057).
- [ ] Nach dem Update sind die neuen Übungen da, z. B. Seitheben und Wandengel; Bilder passen (I-061).
- [ ] Nach 3 × 12 Wiederholungen erscheint beim nächsten Mal der Vorschlag zur schwereren Variante, der Knopf ist hervorgehoben (I-060).
- [ ] Im Programm eine Übung auf Atemzüge stellen: Anzeige zählt abwärts, Ansage stimmt (I-050).
- [ ] Gesamtlänge der Kurs-Einheit passt zur Stufe; Schulterstand, Pflug und Fisch stehen vor der Entspannung (I-053).

## 8 Bedienung

- [ ] Kacheln ausblenden und umsortieren, Live-Kurve an und aus (I-034, I-035).
- [ ] Schnellstart und Favorit (I-038).
- [ ] Profil mit Gewicht und Geschlecht: Geschätzter Energieverbrauch erscheint mit „≈" (I-044).
- [ ] Verlauf: Auswahl, dann Zurück-Taste hebt sie auf und verlässt die App nicht (I-028).
- [ ] Filter „Haltung" und Varianten auf der Übungsseite (I-046, I-051).
- [ ] Tablet: Seiten sehen vernünftig aus.

## 8a Windows und Linux (I-014)

- [ ] Programm startet, alte Daten bleiben getrennt vom Phone.
- [ ] Laufband und Brustgurt koppeln, eine Einheit aufzeichnen.
- [ ] Ansagen und Töne sind zu hören.
- [ ] Export und automatische Sicherung landen im gewählten Ordner.
- [ ] Workout zählt von Hand, ohne Kamera.
- [ ] Sicherungsdatei vom Phone einspielen.
- [ ] Google Drive mit dem Desktop-Client abgleichen, nach einem Neustart läuft es ohne neue Anmeldung.

## 9 Dienste, nur wenn eingerichtet

- [ ] Google Drive: Abgleich zwischen Phone und Tablet, auch Kursfortschritt (I-015).
- [ ] Strava: nur mit API-Zugang. Upload, mehrere auf einmal, Import (I-016, I-017, I-026).
