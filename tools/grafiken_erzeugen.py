"""Erzeugt die Übungsgrafiken aus docs/GRAFIKLISTE.md über die OpenRouter-Bild-API.

Pro Grafik ein eigener API-Aufruf; vorhandene Dateien werden übersprungen,
ein abgebrochener Lauf lässt sich also einfach erneut starten.

Der API-Schlüssel wird aus der Umgebungsvariable OPENROUTER_API_KEY gelesen.

Beispiele:
    python tools/grafiken_erzeugen.py --trocken
    python tools/grafiken_erzeugen.py --nur G-001,G-024,G-045
    python tools/grafiken_erzeugen.py --nur G-021-G-040 --modell sourceful/riverflow-v2.5-pro
    python tools/grafiken_erzeugen.py --nur G-031 --neu
    python tools/grafiken_erzeugen.py
"""

import argparse
import base64
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
LISTE = WURZEL / "docs" / "GRAFIKLISTE.md"
API = "https://openrouter.ai/api/v1/images"
ZIP_NAME = "fitapp_uebungsgrafiken.zip"

STIL = """\
Erstelle eine einzelne Übungsgrafik für eine Fitness-App. Das angehängte Bild ist die Stilvorlage. \
Übernimm daraus nur den Zeichenstil und die Figur, nicht das Layout: keine Überschrift, keine \
Beschriftung, kein Wasserzeichen, kein Logo.

STIL
- Flache Comic-Illustration im Vektor-Look wie in der Vorlage: gleichmäßige, mittelstarke \
dunkelbraune Konturlinie, einfarbige Flächen, keine Verläufe, keine Schattierung, keine Texturen, \
kein Schlagschatten.
- Gedämpfte, warme Farbpalette wie in der Vorlage.
- Schlichtes Gesicht: Punktaugen, kleine Nase, kurzer Strich als Mund, ruhiger Ausdruck.

FIGUR (exakt dieselbe Person wie in der Vorlage)
- Schlanke, sportliche Frau, dunkelbraunes Haar als Dutt am Hinterkopf, helle pfirsichfarbene Haut.
- Lachsfarbenes, ärmelloses Sporttop; dunkelgraubraune, knöchellange Leggings.
- {schuhe}

ANATOMIE (wichtigste Regel)
- Die Haltung muss anatomisch korrekt und real ausführbar sein, so wie eine geübte Person sie \
sauber ausführt.
- Genau zwei Arme und zwei Beine, an jeder Hand fünf Finger, an jedem Fuß fünf Zehen.
- Gelenke beugen nur in die natürliche Richtung: Knie nach vorn, Ellbogen nach hinten. Keine \
verdrehten, verlängerten, verkürzten oder falsch angesetzten Gliedmaßen.
- Linke und rechte Körperseite sind schlüssig; verdeckte Gliedmaßen sind logisch verdeckt und \
fehlen nicht.
- Was laut Beschreibung den Boden, die Wand oder ein Gerät berührt, berührt es sichtbar; was \
schweben soll, schwebt sichtbar.
- Die Beschreibung unten hat Vorrang vor deiner eigenen Vorstellung der Übung.

BILDAUFBAU
- Quadratisches Bild. {hintergrund}
- Genau eine Übung. Figur mittig und vollständig im Bild (außer die Ansicht verlangt nur den Oberkörper), rundum etwa 8 % Rand.
- Unter der Figur eine beigefarbene Matte in leichter Perspektive wie in der Vorlage, sofern die \
Übung am Boden oder im Stand stattfindet. Sonst kein Raum, keine Landschaft.
- Kein Text, keine Zahlen, keine Buchstaben im Bild.
- Geräte schlicht im selben Stil, in Grau- und Beigetönen.
- {ansicht}
- {posen}

ÜBUNG: {uebung}
{beschreibung}
"""

ANSICHT = {
    "Seite": "Ansicht: Figur genau von der Seite, Kopf bzw. Blick nach rechts.",
    "Front": "Ansicht: Figur von vorn, sie schaut zum Betrachter.",
    "Schräg": "Ansicht: Dreiviertelansicht von vorn.",
}
POSEN = {
    "1": "Genau eine Figur im Bild.",
    "2": "Dieselbe Figur zweimal nebeneinander: links die Startposition (blasser, etwa halbe "
         "Deckkraft), rechts die Endposition (volle Farbe), dazwischen ein einzelner geschwungener "
         "Pfeil in Dunkelorange für die Bewegungsrichtung.",
}
HG_FARBE = "Einfarbiger, cremefarbener Hintergrund wie in der Vorlage, ohne Muster."
HG_TRANSPARENT = "Transparenter Hintergrund (echte Transparenz, kein Schachbrettmuster)."


def liste_lesen():
    grafiken = []
    for zeile in LISTE.read_text(encoding="utf-8").splitlines():
        if not zeile.startswith("| G-"):
            continue
        nr, datei, uebung, ansicht, posen, text = [z.strip() for z in zeile.split("|")[1:-1]]
        grafiken.append({"nr": nr, "datei": datei.strip("`"), "uebung": uebung,
                         "ansicht": ansicht, "posen": posen, "text": text})
    return grafiken


def auswahl(grafiken, nur):
    """'G-001,G-005' oder Bereiche wie 'G-021-G-040'."""
    if not nur:
        return grafiken
    zahl = lambda s: int(s.strip().upper().replace("G-", ""))
    gewollt = set()
    for teil in nur.split(","):
        if "-G-" in teil.upper():
            von, bis = teil.upper().split("-G-")
            gewollt.update(range(zahl(von), zahl(bis) + 1))
        else:
            gewollt.add(zahl(teil))
    return [g for g in grafiken if zahl(g["nr"]) in gewollt]


def prompt_bauen(g, transparent):
    ansicht = ANSICHT.get(g["ansicht"], f"Ansicht: {g['ansicht']}.")
    schuhe = ("Flache dunkelgraue Sportschuhe." if g["datei"].startswith("crossfit_")
              else "Barfuß.")
    return STIL.format(schuhe=schuhe, ansicht=ansicht, posen=POSEN[g["posen"]],
                       hintergrund=HG_TRANSPARENT if transparent else HG_FARBE,
                       uebung=g["uebung"], beschreibung=g["text"])


def als_data_url(pfad):
    typ = mimetypes.guess_type(pfad.name)[0] or "image/webp"
    return f"data:{typ};base64,{base64.b64encode(pfad.read_bytes()).decode()}"


def bild_anfordern(schluessel, modell, prompt, vorlage, transparent):
    rumpf = {"model": modell, "prompt": prompt, "aspect_ratio": "1:1", "resolution": "1K"}
    if vorlage:
        rumpf["input_references"] = [{"type": "image_url", "image_url": {"url": vorlage}}]
    if transparent:
        rumpf["background"] = "transparent"
    anfrage = urllib.request.Request(
        API, data=json.dumps(rumpf).encode(),
        headers={"Authorization": f"Bearer {schluessel}", "Content-Type": "application/json"})
    with urllib.request.urlopen(anfrage, timeout=300) as antwort:
        daten = json.load(antwort)
    bild = daten["data"][0]
    endung = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}.get(
        bild.get("media_type"), ".png")
    kosten = (daten.get("usage") or {}).get("cost") or 0
    return base64.b64decode(bild["b64_json"]), endung, kosten


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Übungsgrafiken über OpenRouter erzeugen")
    p.add_argument("--modell", default="sourceful/riverflow-v2.5-fast")
    p.add_argument("--nur", help="z. B. G-001,G-005 oder G-021-G-040")
    p.add_argument("--vorlage", default=str(WURZEL / "grafiken" / "stilvorlage.webp"),
                   help="Stilvorlage (Bilddatei)")
    p.add_argument("--ziel", default=str(WURZEL / "grafiken"))
    p.add_argument("--neu", action="store_true", help="vorhandene Dateien überschreiben")
    p.add_argument("--transparent", action="store_true",
                   help="transparenten Hintergrund anfordern (nicht jedes Modell kann das)")
    p.add_argument("--trocken", action="store_true",
                   help="nichts senden, nur zeigen, was erzeugt würde")
    p.add_argument("--pause", type=float, default=1.0, help="Sekunden zwischen den Aufrufen")
    a = p.parse_args()

    grafiken = auswahl(liste_lesen(), a.nur)
    if not grafiken:
        sys.exit("Keine passende Grafik in der Liste gefunden.")
    ziel = Path(a.ziel)
    ziel.mkdir(parents=True, exist_ok=True)

    if a.trocken:
        for g in grafiken:
            print(f"{g['nr']}  {g['datei']}.png")
        print(f"\n{len(grafiken)} Grafiken. Beispiel-Prompt für {grafiken[0]['nr']}:\n")
        print(prompt_bauen(grafiken[0], a.transparent))
        return

    schluessel = os.environ.get("OPENROUTER_API_KEY")
    if not schluessel:
        sys.exit("Umgebungsvariable OPENROUTER_API_KEY ist nicht gesetzt.")
    vorlage = Path(a.vorlage)
    if not vorlage.exists():
        sys.exit(f"Stilvorlage nicht gefunden: {vorlage}")
    vorlage_url = als_data_url(vorlage)

    fehler, summe = [], 0.0
    for i, g in enumerate(grafiken, 1):
        vorhanden = list(ziel.glob(g["datei"] + ".*"))
        if vorhanden and not a.neu:
            print(f"[{i}/{len(grafiken)}] {g['nr']} vorhanden, übersprungen")
            continue
        for versuch in range(3):
            try:
                inhalt, endung, kosten = bild_anfordern(
                    schluessel, a.modell, prompt_bauen(g, a.transparent), vorlage_url,
                    a.transparent)
                for alt in vorhanden:
                    alt.unlink()
                (ziel / (g["datei"] + endung)).write_bytes(inhalt)
                summe += kosten
                print(f"[{i}/{len(grafiken)}] {g['nr']} {g['datei']}{endung}")
                break
            except urllib.error.HTTPError as e:
                meldung = e.read().decode(errors="replace")[:500]
                print(f"[{i}/{len(grafiken)}] {g['nr']} HTTP {e.code}: {meldung}")
                if e.code in (400, 401, 402, 403, 404):
                    # Anfrage, Schlüssel, Guthaben oder Modell stimmen nicht: Wiederholen hilft nicht.
                    sys.exit("Abbruch. Bitte Meldung oben prüfen.")
                time.sleep(10 * (versuch + 1))
            except (urllib.error.URLError, TimeoutError, KeyError, IndexError, ValueError) as e:
                print(f"[{i}/{len(grafiken)}] {g['nr']} Fehler: {e!r}")
                time.sleep(10 * (versuch + 1))
        else:
            fehler.append(g["nr"])
        time.sleep(a.pause)

    alle = {g["datei"] for g in liste_lesen()}
    fertig = sorted(d for d in ziel.iterdir() if d.stem in alle)
    with zipfile.ZipFile(ziel / ZIP_NAME, "w", zipfile.ZIP_DEFLATED) as z:
        for d in fertig:
            z.write(d, d.name)

    print(f"\n{len(fertig)} von {len(alle)} Grafiken liegen in {ziel}")
    print(f"ZIP: {ziel / ZIP_NAME}")
    if summe:
        print(f"Kosten dieses Laufs laut OpenRouter: {summe:.2f} USD")
    if fehler:
        print("Fehlgeschlagen: " + ",".join(fehler))


if __name__ == "__main__":
    main()
