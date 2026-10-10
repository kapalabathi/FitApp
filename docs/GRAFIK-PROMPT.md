# Prompt für die Übungsgrafiken (zu I-020)

Erzeugt aus der [Grafikliste](GRAFIKLISTE.md). Bei Änderungen an der Liste muss dieser Prompt neu erzeugt werden.

## Anwendung

1. Neuen Chat im Bildgenerator öffnen, das Beispielbild anhängen und den **Startprompt** senden.
2. Die **Pakete 1 bis 8** nacheinander senden, jeweils erst nach Abschluss des vorigen.
3. Jedes Bild gegen die Beschreibung prüfen. Fehlerhafte Bilder mit dem **Korrekturprompt** neu anfordern.
4. Am Ende den **Abschlussprompt** senden, um die ZIP-Datei zu erhalten.

Alle Pakete gehören in denselben Chat, damit Figur und Stil gleich bleiben.

## Startprompt

```text
Du erstellst eine Serie von 80 Übungsgrafiken für eine Fitness-App. Das angehängte Bild ist die Stilvorlage. Übernimm daraus nur den Zeichenstil und die Figur, nicht das Layout: keine Überschrift, keine Beschriftungen, kein Wasserzeichen, kein Logo.

STIL (für alle Bilder identisch)
- Flache Comic-Illustration im Vektor-Look wie in der Vorlage: gleichmäßige, mittelstarke dunkelbraune Konturlinie, einfarbige Flächen, keine Verläufe, keine Schattierung, keine Texturen, kein Schlagschatten.
- Gedämpfte, warme Farbpalette wie in der Vorlage.
- Schlichtes Gesicht: Punktaugen, kleine Nase, kurzer Strich als Mund, ruhiger Ausdruck.

FIGUR (in allen 80 Bildern exakt dieselbe Person)
- Schlanke, sportliche Frau, dunkelbraunes Haar als Dutt am Hinterkopf, helle pfirsichfarbene Haut.
- Lachsfarbenes, ärmelloses Sporttop; dunkelgraubraune, knöchellange Leggings.
- Barfuß bei Yoga, Calisthenics und Dehnen. Bei Crossfit flache dunkelgraue Sportschuhe.
- Proportionen, Frisur, Kleidung und Farben ändern sich nie.

ANATOMIE (wichtigste Regel)
- Jede Haltung muss anatomisch korrekt und real ausführbar sein, so wie eine geübte Person sie sauber ausführt.
- Genau zwei Arme und zwei Beine, an jeder Hand fünf Finger, an jedem Fuß fünf Zehen.
- Gelenke beugen nur in die natürliche Richtung: Knie nach vorn, Ellbogen nach hinten. Keine verdrehten, verlängerten, verkürzten oder falsch angesetzten Gliedmaßen.
- Linke und rechte Körperseite sind schlüssig; verdeckte Gliedmaßen sind logisch verdeckt und fehlen nicht.
- Kontaktpunkte stimmen: Was laut Beschreibung den Boden, die Wand oder ein Gerät berührt, berührt es sichtbar; was schweben soll, schwebt sichtbar.
- Halte dich genau an die Beschreibung jedes Bildes (Winkel, Hand- und Fußstellung, Blickrichtung). Sie hat Vorrang vor deiner eigenen Vorstellung der Übung.
- Prüfe jedes Bild vor der Ausgabe gegen Beschreibung und Anatomie-Regeln. Stimmt etwas nicht, erzeuge es neu.

BILDAUFBAU
- Quadratisch, 1024 x 1024 Pixel, PNG mit transparentem Hintergrund.
- Pro Bild genau eine Übung. Figur mittig und vollständig im Bild, rundum etwa 8 % Rand, nichts angeschnitten.
- Unter der Figur eine beigefarbene Matte in leichter Perspektive wie in der Vorlage, sofern die Übung am Boden oder im Stand stattfindet. Sonst kein Hintergrund, kein Raum, keine Landschaft.
- Kein Text, keine Zahlen, keine Buchstaben im Bild.
- Ansicht "Seite": Figur von der Seite, Kopf bzw. Blick nach rechts, sofern nichts anderes angegeben ist. "Front": Figur schaut zum Betrachter. "Schräg": Dreiviertelansicht von vorn.
- Posen "1": eine einzelne Figur.
- Posen "2": dieselbe Figur zweimal nebeneinander im selben Bild, links die Startposition (blasser, etwa halbe Deckkraft), rechts die Endposition (volle Farbe), dazwischen ein einzelner geschwungener Pfeil in Dunkelorange für die Bewegungsrichtung.
- Geräte (Kettlebell, Langhantel, Kurzhantel, Sprungbox, Medizinball, Springseil, Klimmzugstange, Barren, Bank, Wand) schlicht im selben Stil und in jedem Bild gleich gezeichnet, in Grau- und Beigetönen.

ABLAUF
- Ich schicke dir die Bilder in 8 Paketen zu je 10. Erzeuge jedes Bild einzeln, nicht mehrere Übungen in einem Bild.
- Benenne jede Datei exakt mit dem angegebenen Dateinamen.
- Gib nach jedem Paket eine Liste der erzeugten Dateinamen aus und warte auf mein nächstes Paket.

Bestätige kurz, dass du Stil, Figur und Regeln verstanden hast, und erzeuge noch kein Bild.
```

## Paket 1: Yoga 1/2 (G-001 bis G-010)

```text
Paket 1 von 8, Kategorie Yoga. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-001 | Dateiname: yoga_01_berghaltung.png | Übung: Berghaltung (Tadasana) | Ansicht: Front | Posen: 1
Aufrechter Stand, Füße geschlossen, Arme locker neben dem Körper, Handflächen nach vorn, Schultern entspannt, Blick geradeaus.

G-002 | Dateiname: yoga_02_herabschauender_hund.png | Übung: Herabschauender Hund | Ansicht: Seite | Posen: 1
Umgekehrtes V: Hände und Füße am Boden, Gesäß ist der höchste Punkt, Arme und Rücken bilden eine Linie, Beine gestreckt, Fersen Richtung Boden, Kopf zwischen den Oberarmen.

G-003 | Dateiname: yoga_03_heraufschauender_hund.png | Übung: Heraufschauender Hund | Ansicht: Seite | Posen: 1
Arme gestreckt, Hände unter den Schultern, Brust weit nach vorn oben. Wichtig: Hüfte und Oberschenkel schweben über dem Boden, nur Hände und Fußrücken berühren ihn. Blick schräg nach oben.

G-004 | Dateiname: yoga_04_kobra.png | Übung: Kobra | Ansicht: Seite | Posen: 1
Bauchlage, Becken und Beine liegen am Boden, Oberkörper angehoben, Ellbogen gebeugt und nah am Körper, Hände neben der Brust. Deutlich flacher als G-003.

G-005 | Dateiname: yoga_05_kindhaltung.png | Übung: Kindhaltung | Ansicht: Seite | Posen: 1
Kniend, Gesäß auf den Fersen, Oberkörper auf den Oberschenkeln abgelegt, Stirn am Boden, Arme lang nach vorn gestreckt.

G-006 | Dateiname: yoga_06_katze_kuh.png | Übung: Katze-Kuh | Ansicht: Seite | Posen: 2
Vierfüßlerstand. Links „Kuh": Rücken im Hohlkreuz, Kopf und Steißbein gehoben. Rechts „Katze": Rücken rund nach oben, Kopf gesenkt.

G-007 | Dateiname: yoga_07_krieger_1.png | Übung: Krieger I | Ansicht: Seite | Posen: 1
Großer Ausfallschritt, vorderes Knie 90° über dem Fußgelenk, hinteres Bein gestreckt, Becken und Brust zeigen nach vorn (in Laufrichtung), beide Arme senkrecht nach oben gestreckt.

G-008 | Dateiname: yoga_08_krieger_2.png | Übung: Krieger II | Ansicht: Front | Posen: 1
Breiter Stand, das vom Betrachter aus rechte Knie 90° gebeugt, anderes Bein gestreckt, Oberkörper aufrecht und frontal, Arme waagerecht zur Seite gestreckt, Kopf zur gebeugten Seite gedreht.

G-009 | Dateiname: yoga_09_krieger_3.png | Übung: Krieger III | Ansicht: Seite | Posen: 1
Standwaage: auf einem gestreckten Bein, Oberkörper und anderes Bein bilden eine waagerechte Linie, Arme nach vorn gestreckt, Körper wie ein „T".

G-010 | Dateiname: yoga_10_dreieck.png | Übung: Dreieck (Trikonasana) | Ansicht: Front | Posen: 1
Breiter Stand, beide Beine gestreckt, Oberkörper seitlich zum einen Bein geneigt, untere Hand am Schienbein, oberer Arm senkrecht nach oben, Blick zur oberen Hand.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 2: Yoga 2/2 (G-011 bis G-020)

```text
Paket 2 von 8, Kategorie Yoga. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-011 | Dateiname: yoga_11_baum.png | Übung: Baum | Ansicht: Front | Posen: 1
Stand auf einem Bein, Fußsohle des anderen Beins an der Innenseite des Standbein-Oberschenkels, Knie nach außen, Handflächen über dem Kopf zusammen.

G-012 | Dateiname: yoga_12_stuhl.png | Übung: Stuhl (Utkatasana) | Ansicht: Seite | Posen: 1
Füße geschlossen, Knie gebeugt als säße die Figur auf einem unsichtbaren Stuhl, Oberkörper leicht nach vorn geneigt, Arme schräg nach vorn oben in Verlängerung des Rückens.

G-013 | Dateiname: yoga_13_stehende_vorbeuge.png | Übung: Stehende Vorbeuge | Ansicht: Seite | Posen: 1
Beine gestreckt, Oberkörper aus der Hüfte nach unten geklappt, Hände am Boden neben den Füßen, Kopf hängt locker.

G-014 | Dateiname: yoga_14_sitzende_vorbeuge.png | Übung: Sitzende Vorbeuge | Ansicht: Seite | Posen: 1
Sitz mit gestreckten Beinen, Oberkörper über die Beine nach vorn gebeugt, Hände greifen die Füße, Rücken möglichst lang.

G-015 | Dateiname: yoga_15_bruecke.png | Übung: Schulterbrücke | Ansicht: Seite | Posen: 1
Rückenlage, Füße hüftbreit aufgestellt, Becken hoch gehoben, Körper von Knien bis Schultern eine schräge Linie, Schultern und Kopf am Boden, Arme lang neben dem Körper.

G-016 | Dateiname: yoga_16_boot.png | Übung: Boot (Navasana) | Ansicht: Seite | Posen: 1
Balance auf dem Gesäß, Oberkörper und gestreckte Beine bilden ein „V", Arme parallel zum Boden nach vorn gestreckt, Rücken gerade.

G-017 | Dateiname: yoga_17_taube.png | Übung: Taube | Ansicht: Schräg | Posen: 1
Vorderes Bein angewinkelt vor dem Körper am Boden (Unterschenkel quer), hinteres Bein lang nach hinten gestreckt, Oberkörper aufrecht, Hände stützen neben der Hüfte.

G-018 | Dateiname: yoga_18_drehsitz.png | Übung: Drehsitz | Ansicht: Schräg | Posen: 1
Sitz, ein Bein gestreckt, das andere aufgestellt und über das gestreckte Bein gekreuzt, Oberkörper zum aufgestellten Knie gedreht, gegenüberliegender Ellbogen außen am Knie, andere Hand hinter dem Gesäß abgestützt.

G-019 | Dateiname: yoga_19_tiefer_ausfallschritt.png | Übung: Tiefer Ausfallschritt | Ansicht: Seite | Posen: 1
Vorderes Knie 90°, hinteres Knie und Fußrücken am Boden abgelegt, Hüfte tief nach vorn, Oberkörper aufrecht, Arme nach oben gestreckt.

G-020 | Dateiname: yoga_20_totenstellung.png | Übung: Totenstellung (Savasana) | Ansicht: Seite, leicht von oben | Posen: 1
Flache Rückenlage auf einer Matte, Beine leicht geöffnet, Arme etwas vom Körper weg, Handflächen nach oben, Augen geschlossen.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 3: Crossfit 1/2 (G-021 bis G-030)

```text
Paket 3 von 8, Kategorie Crossfit. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-021 | Dateiname: crossfit_01_air_squat.png | Übung: Kniebeuge (Air Squat) | Ansicht: Seite | Posen: 2
Links: aufrechter Stand. Rechts: tiefe Hocke, Hüfte unterhalb der Knie, Fersen am Boden, Rücken gerade, Arme waagerecht nach vorn.

G-022 | Dateiname: crossfit_02_burpee.png | Übung: Burpee | Ansicht: Seite | Posen: 2
Links: Liegestützposition unten, Brust am Boden. Rechts: Strecksprung, Füße in der Luft, Hände über dem Kopf.

G-023 | Dateiname: crossfit_03_box_jump.png | Übung: Box Jump | Ansicht: Seite | Posen: 2
Links: Figur vor der Box in leichter Hocke, Arme nach hinten geschwungen. Rechts: Figur steht aufrecht oben auf der Box. Die Box ist etwa kniehoch.

G-024 | Dateiname: crossfit_04_kettlebell_swing.png | Übung: Kettlebell Swing | Ansicht: Seite | Posen: 2
Links: Hüfte nach hinten geschoben, Rücken gerade, Kettlebell mit beiden Händen zwischen den Beinen. Rechts: aufrecht, Hüfte gestreckt, Arme gestreckt, Kettlebell auf Brusthöhe.

G-025 | Dateiname: crossfit_05_thruster.png | Übung: Thruster | Ansicht: Seite | Posen: 2
Links: tiefe Kniebeuge, Langhantel liegt vorn auf den Schultern, Ellbogen hoch. Rechts: aufrechter Stand, Langhantel mit gestreckten Armen über dem Kopf.

G-026 | Dateiname: crossfit_06_wall_ball.png | Übung: Wall Ball | Ansicht: Seite | Posen: 2
Figur steht vor einer angedeuteten Wand. Links: tiefe Kniebeuge, Medizinball vor der Brust. Rechts: gestreckt auf den Zehenspitzen, Ball fliegt oberhalb der Hände zur Wand.

G-027 | Dateiname: crossfit_07_seilspringen.png | Übung: Seilspringen | Ansicht: Front | Posen: 1
Leichter Sprung, Füße knapp über dem Boden, Ellbogen nah am Körper, Seil läuft als Bogen unter den Füßen durch.

G-028 | Dateiname: crossfit_08_kreuzheben.png | Übung: Kreuzheben | Ansicht: Seite | Posen: 2
Links: Langhantel am Boden, Figur greift sie, Hüfte hinten, Rücken gerade, Schultern über der Stange. Rechts: aufrechter Stand, Hantel an gestreckten Armen vor den Oberschenkeln.

G-029 | Dateiname: crossfit_09_goblet_squat.png | Übung: Goblet Squat | Ansicht: Schräg | Posen: 1
Tiefe Kniebeuge, Kettlebell mit beiden Händen dicht vor der Brust gehalten, Ellbogen zwischen den Knien, Oberkörper aufrecht.

G-030 | Dateiname: crossfit_10_push_press.png | Übung: Push Press | Ansicht: Seite | Posen: 2
Links: leicht gebeugte Knie, Langhantel vorn auf den Schultern. Rechts: Beine gestreckt, Hantel mit gestreckten Armen über dem Kopf. Keine tiefe Kniebeuge (Unterschied zu G-025).

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 4: Crossfit 2/2 (G-031 bis G-040)

```text
Paket 4 von 8, Kategorie Crossfit. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-031 | Dateiname: crossfit_11_toes_to_bar.png | Übung: Toes-to-Bar | Ansicht: Seite | Posen: 2
Figur hängt an einer Klimmzugstange. Links: gestreckt hängend. Rechts: Beine gestreckt nach oben geführt, Zehen berühren die Stange.

G-032 | Dateiname: crossfit_12_mountain_climbers.png | Übung: Mountain Climbers | Ansicht: Seite | Posen: 1
Hohe Liegestützposition, Arme gestreckt, ein Knie weit zur Brust gezogen, das andere Bein gestreckt nach hinten.

G-033 | Dateiname: crossfit_13_ausfallschritt.png | Übung: Ausfallschritt gehend | Ansicht: Seite | Posen: 1
Großer Schritt nach vorn, vorderes Knie 90°, hinteres Knie knapp über dem Boden, Oberkörper aufrecht, Hände an der Hüfte.

G-034 | Dateiname: crossfit_14_situp.png | Übung: Sit-up | Ansicht: Seite | Posen: 2
Links: Rückenlage, Füße aufgestellt, Arme über dem Kopf am Boden. Rechts: aufgerichtet im Sitz, Hände berühren die Füße.

G-035 | Dateiname: crossfit_15_kurzhantel_snatch.png | Übung: Kurzhantel-Snatch | Ansicht: Schräg | Posen: 2
Links: Hocke, eine Hand greift die Kurzhantel am Boden zwischen den Füßen, Rücken gerade. Rechts: aufrechter Stand, Hantel mit einem gestreckten Arm über dem Kopf.

G-036 | Dateiname: crossfit_16_farmers_carry.png | Übung: Farmers Carry | Ansicht: Front | Posen: 1
Figur geht aufrecht, in jeder Hand eine Kettlebell an gestreckten Armen neben dem Körper, Schultern zurück.

G-037 | Dateiname: crossfit_17_box_step_up.png | Übung: Box Step-up | Ansicht: Seite | Posen: 1
Ein Fuß steht ganz auf der Box, Figur drückt sich gerade hoch, der hintere Fuß hat den Boden eben verlassen.

G-038 | Dateiname: crossfit_18_russian_twist.png | Übung: Russian Twist | Ansicht: Schräg | Posen: 1
Sitz, Oberkörper leicht zurückgelehnt, Füße vom Boden abgehoben, Knie gebeugt, Medizinball mit beiden Händen seitlich neben der Hüfte, Oberkörper dorthin gedreht.

G-039 | Dateiname: crossfit_19_hampelmann.png | Übung: Hampelmann | Ansicht: Front | Posen: 2
Links: Füße geschlossen, Arme am Körper. Rechts: Beine gegrätscht in der Luft, Hände über dem Kopf zusammen.

G-040 | Dateiname: crossfit_20_bear_crawl.png | Übung: Bear Crawl | Ansicht: Seite | Posen: 1
Auf Händen und Füßen, Knie nur wenige Zentimeter über dem Boden, Rücken flach und waagerecht, gegengleich eine Hand und ein Fuß vorn.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 5: Calisthenics 1/2 (G-041 bis G-050)

```text
Paket 5 von 8, Kategorie Calisthenics. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-041 | Dateiname: cali_01_liegestuetz.png | Übung: Liegestütz | Ansicht: Seite | Posen: 2
Links: Arme gestreckt. Rechts: Brust knapp über dem Boden, Ellbogen ca. 45° vom Körper. In beiden Posen Körper von Kopf bis Ferse eine gerade Linie.

G-042 | Dateiname: cali_02_liegestuetz_knie.png | Übung: Liegestütz auf Knien | Ansicht: Seite | Posen: 1
Wie Liegestütz unten, aber Knie am Boden, Unterschenkel angehoben und gekreuzt, gerade Linie von Kopf bis Knie.

G-043 | Dateiname: cali_03_diamant_liegestuetz.png | Übung: Diamant-Liegestütz | Ansicht: Schräg von vorn | Posen: 1
Untere Liegestützposition. Hände direkt unter der Brust, Daumen und Zeigefinger beider Hände berühren sich und bilden eine Raute; die Handstellung muss klar erkennbar sein.

G-044 | Dateiname: cali_04_pike_pushup.png | Übung: Pike Push-up | Ansicht: Seite | Posen: 1
Körper als umgekehrtes V, Gesäß hoch, Ellbogen gebeugt, Kopf senkt sich zwischen den Händen Richtung Boden.

G-045 | Dateiname: cali_05_klimmzug.png | Übung: Klimmzug (Obergriff) | Ansicht: Front, von hinten gesehen | Posen: 2
Links: gestreckt hängend an der Stange. Rechts: Kinn über der Stange. Griff etwas breiter als schulterbreit, Handrücken zum Gesicht der Figur.

G-046 | Dateiname: cali_06_chinup.png | Übung: Chin-up (Untergriff) | Ansicht: Seite | Posen: 1
Kinn über der Stange, Griff schulterbreit, Handflächen zeigen zum Gesicht, Ellbogen vor dem Körper. Der Untergriff muss erkennbar sein.

G-047 | Dateiname: cali_07_australian_pullup.png | Übung: Australian Pull-up | Ansicht: Seite | Posen: 1
Figur hängt schräg unter einer hüfthohen Stange, Fersen am Boden, Körper gerade, Brust an die Stange gezogen.

G-048 | Dateiname: cali_08_dips.png | Übung: Dips am Barren | Ansicht: Seite | Posen: 2
Links: Stütz auf dem Barren mit gestreckten Armen, Füße in der Luft. Rechts: Ellbogen 90° gebeugt, Oberkörper leicht nach vorn geneigt.

G-049 | Dateiname: cali_09_bank_dips.png | Übung: Bank-Dips | Ansicht: Seite | Posen: 1
Hände hinter dem Körper auf der Bankkante, Gesäß vor der Bank abgesenkt, Ellbogen 90° nach hinten gebeugt, Beine gestreckt, Fersen am Boden.

G-050 | Dateiname: cali_10_unterarmstuetz.png | Übung: Unterarmstütz (Plank) | Ansicht: Seite | Posen: 1
Auf Unterarmen und Zehenspitzen, Ellbogen unter den Schultern, Körper eine gerade Linie, Blick zum Boden.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 6: Calisthenics 2/2 (G-051 bis G-060)

```text
Paket 6 von 8, Kategorie Calisthenics. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-051 | Dateiname: cali_11_seitstuetz.png | Übung: Seitstütz | Ansicht: Front | Posen: 1
Auf einem Unterarm und den Außenkanten der gestapelten Füße, Hüfte gehoben, Körper eine gerade Linie, oberer Arm senkrecht nach oben.

G-052 | Dateiname: cali_12_hollow_body.png | Übung: Hollow Body Hold | Ansicht: Seite | Posen: 1
Rückenlage, nur der untere Rücken berührt den Boden, Schultern und gestreckte Beine leicht angehoben, Arme lang über den Kopf; Körper wie eine flache Schale.

G-053 | Dateiname: cali_13_haengendes_beinheben.png | Übung: Hängendes Beinheben | Ansicht: Seite | Posen: 1
An der Klimmzugstange hängend, Beine gestreckt bis zur Waagerechten gehoben, Oberkörper senkrecht.

G-054 | Dateiname: cali_14_l_sit.png | Übung: L-Sit | Ansicht: Seite | Posen: 1
Stütz auf zwei niedrigen Griffen oder am Barren, Arme gestreckt, Gesäß in der Luft, Beine gestreckt und waagerecht nach vorn; Körper bildet ein „L".

G-055 | Dateiname: cali_15_pistol_squat.png | Übung: Einbeinige Kniebeuge (Pistol) | Ansicht: Seite | Posen: 1
Tiefe Hocke auf einem Bein, Ferse am Boden, anderes Bein gestreckt nach vorn knapp über dem Boden, Arme waagerecht nach vorn.

G-056 | Dateiname: cali_16_bulgarian_split_squat.png | Übung: Bulgarian Split Squat | Ansicht: Seite | Posen: 1
Hinterer Fußrücken liegt auf einer Bank, vorderes Knie 90° gebeugt, Oberkörper aufrecht, Hände an der Hüfte.

G-057 | Dateiname: cali_17_superman.png | Übung: Superman | Ansicht: Seite | Posen: 1
Bauchlage, Arme nach vorn gestreckt, Arme, Brust und Beine gleichzeitig vom Boden abgehoben, Blick zum Boden.

G-058 | Dateiname: cali_18_wandsitz.png | Übung: Wandsitz | Ansicht: Seite | Posen: 1
Rücken flach an einer Wand, Hüfte und Knie je 90°, Oberschenkel waagerecht, Füße flach am Boden, Arme hängen locker.

G-059 | Dateiname: cali_19_handstand_wand.png | Übung: Handstand an der Wand | Ansicht: Seite | Posen: 1
Handstand mit dem Bauch zur Wand, Zehen berühren die Wand, Arme gestreckt, Körper gerade und gestreckt.

G-060 | Dateiname: cali_20_kraehe.png | Übung: Krähe | Ansicht: Schräg | Posen: 1
Balance nur auf den Händen, Ellbogen leicht gebeugt, Knie liegen auf den Oberarmen, Füße vom Boden abgehoben, Blick schräg nach vorn.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 7: Dehnen 1/2 (G-061 bis G-070)

```text
Paket 7 von 8, Kategorie Dehnen. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-061 | Dateiname: dehnen_01_nacken.png | Übung: Nacken seitlich | Ansicht: Front, nur Oberkörper | Posen: 1
Kopf zur einen Schulter geneigt, die Hand derselben Seite liegt leicht auf dem Kopf, der andere Arm zieht nach unten.

G-062 | Dateiname: dehnen_02_schulter.png | Übung: Schulter | Ansicht: Front, nur Oberkörper | Posen: 1
Ein Arm gestreckt waagerecht vor der Brust zur Gegenseite geführt, der andere Unterarm drückt ihn am Oberarm zum Körper.

G-063 | Dateiname: dehnen_03_trizeps.png | Übung: Trizeps | Ansicht: Front, von hinten gesehen | Posen: 1
Ein Arm über dem Kopf gebeugt, Hand zwischen den Schulterblättern, die andere Hand greift den Ellbogen und zieht ihn zur Mitte.

G-064 | Dateiname: dehnen_04_brust_wand.png | Übung: Brust an der Wand | Ansicht: Von oben schräg | Posen: 1
Figur steht seitlich an einer Wand oder einem Türrahmen, Unterarm senkrecht an der Wand, Ellbogen auf Schulterhöhe, Oberkörper von der Wand weggedreht.

G-065 | Dateiname: dehnen_05_seitbeuge.png | Übung: Seitbeuge im Stand | Ansicht: Front | Posen: 1
Füße hüftbreit, ein Arm lang über den Kopf zur Gegenseite gezogen, Oberkörper seitlich geneigt, andere Hand an der Hüfte.

G-066 | Dateiname: dehnen_06_wade_wand.png | Übung: Wade an der Wand | Ansicht: Seite | Posen: 1
Schrittstellung vor einer Wand, Hände an der Wand, hinteres Bein gestreckt, hintere Ferse fest am Boden, vorderes Knie gebeugt.

G-067 | Dateiname: dehnen_07_oberschenkel_vorn.png | Übung: Oberschenkel-Vorderseite | Ansicht: Seite | Posen: 1
Stand auf einem Bein, die Hand zieht die Ferse des anderen Beins zum Gesäß, Knie zeigen nach unten und bleiben nebeneinander, Oberkörper aufrecht.

G-068 | Dateiname: dehnen_08_oberschenkel_hinten.png | Übung: Oberschenkel-Rückseite | Ansicht: Seite | Posen: 1
Ein Bein gestreckt nach vorn, Ferse aufgesetzt, Zehen angezogen; Standbein leicht gebeugt, Oberkörper mit geradem Rücken nach vorn geneigt, Hände auf dem Oberschenkel des Standbeins.

G-069 | Dateiname: dehnen_09_hueftbeuger.png | Übung: Hüftbeuger | Ansicht: Seite | Posen: 1
Kniender Ausfallschritt, hinteres Knie am Boden, Hüfte nach vorn geschoben, Oberkörper aufrecht, Hände an der Hüfte. Arme nicht nach oben (Unterschied zu G-019).

G-070 | Dateiname: dehnen_10_schmetterling.png | Übung: Schmetterling | Ansicht: Front | Posen: 1
Sitz, Fußsohlen aneinander, Knie fallen nach außen, Hände umfassen die Füße, Rücken aufrecht.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Paket 8: Dehnen 2/2 (G-071 bis G-080)

```text
Paket 8 von 8, Kategorie Dehnen. Erzeuge die folgenden 10 Bilder einzeln nach den vereinbarten Regeln für Stil, Figur und Anatomie.

G-071 | Dateiname: dehnen_11_graetschsitz.png | Übung: Grätschsitz mit Vorbeuge | Ansicht: Front | Posen: 1
Sitz mit weit gegrätschten, gestreckten Beinen, Oberkörper nach vorn zur Mitte gebeugt, Hände vor dem Körper am Boden.

G-072 | Dateiname: dehnen_12_figur_4.png | Übung: Gesäß (liegende Vier) | Ansicht: Seite, leicht von oben | Posen: 1
Rückenlage, ein Knöchel liegt auf dem Knie des anderen Beins, beide Hände ziehen den Oberschenkel dieses anderen Beins zur Brust.

G-073 | Dateiname: dehnen_13_knie_zur_brust.png | Übung: Knie zur Brust | Ansicht: Seite | Posen: 1
Rückenlage, beide Knie mit den Händen zur Brust gezogen, Kopf und Schultern liegen am Boden.

G-074 | Dateiname: dehnen_14_wirbelsaeule_drehung.png | Übung: Liegende Drehung | Ansicht: Von oben | Posen: 1
Rückenlage, Arme zur Seite als „T", ein Knie gebeugt über den Körper zur Gegenseite gelegt, beide Schultern am Boden, Kopf zur anderen Seite gedreht.

G-075 | Dateiname: dehnen_15_tiefe_hocke.png | Übung: Tiefe Hocke | Ansicht: Front | Posen: 1
Füße etwas breiter als hüftbreit, Fersen am Boden, Gesäß tief zwischen den Fersen, Handflächen vor der Brust zusammen, Ellbogen drücken die Knie nach außen.

G-076 | Dateiname: dehnen_16_adduktoren.png | Übung: Adduktoren (seitlicher Ausfallschritt) | Ansicht: Front | Posen: 1
Sehr breiter Stand, ein Knie tief gebeugt, das andere Bein seitlich lang gestreckt, Fußsohle am Boden, Hände vor dem Körper am Boden oder auf dem gebeugten Knie.

G-077 | Dateiname: dehnen_17_unterarm.png | Übung: Unterarm und Handgelenk | Ansicht: Schräg, nur Oberkörper | Posen: 1
Ein Arm gestreckt nach vorn, Handfläche zeigt nach vorn, Finger nach unten; die andere Hand zieht die Finger sanft zum Körper.

G-078 | Dateiname: dehnen_18_nadeloehr.png | Übung: Nadelöhr (Brustwirbelsäule) | Ansicht: Schräg von vorn | Posen: 1
Vierfüßlerstand, ein Arm unter dem Körper zur Gegenseite durchgefädelt, diese Schulter und die Schläfe am Boden abgelegt, der andere Arm stützt.

G-079 | Dateiname: dehnen_19_fusssohle.png | Übung: Fußsohle im Fersensitz | Ansicht: Seite | Posen: 1
Kniend, Zehen aufgestellt, Gesäß sitzt auf den Fersen, Oberkörper aufrecht, Hände auf den Oberschenkeln. Die aufgestellten Zehen müssen erkennbar sein.

G-080 | Dateiname: dehnen_20_weltbeste_dehnung.png | Übung: Ausfallschritt mit Aufdrehen | Ansicht: Schräg | Posen: 1
Tiefer Ausfallschritt, hinteres Bein gestreckt, die Hand auf der Seite des hinteren Beins stützt am Boden neben dem vorderen Fuß, der andere Arm senkrecht nach oben gestreckt, Oberkörper und Blick zur oberen Hand aufgedreht.

Gib danach die Liste der erzeugten Dateinamen aus.
```

## Korrekturprompt

```text
Bild <Nummer> (<Dateiname>) ist fehlerhaft: <was falsch ist>. Erzeuge es neu, mit demselben Dateinamen, derselben Figur und demselben Stil. Halte dich genau an die Beschreibung und die Anatomie-Regeln.
```

## Abschlussprompt

```text
Packe alle 80 erzeugten PNG-Dateien (G-001 bis G-080) mit ihren exakten Dateinamen in eine ZIP-Datei namens fitapp_uebungsgrafiken.zip, ohne Unterordner, und gib sie mir zum Download. Liste vorher auf, welche der 80 Dateinamen fehlen, falls welche fehlen.
```
