"""Erzeugt die mitgelieferten Übungen der App.

Quellen:
- docs/GRAFIKLISTE.md: Nummer, Dateiname und Name jeder Übung
- tools/uebungen.json: Anleitung, trainierte Körperbereiche und ob die Übung
  auf Zeit ausgeführt wird, je Nummer

Ergebnis:
- lib/programs/builtin_exercises.dart
- assets/exercises/*.webp: die Rohbilder, verkleinert auf 512 px

Nach neuen oder geänderten Bildern oder Texten einfach erneut ausführen:
    python tools/uebungen_erzeugen.py

Liegen die Rohbilder in einem anderen Ordner, diesen angeben:
    python tools/uebungen_erzeugen.py grafiken/medium
"""

import json
import sys
from pathlib import Path

from PIL import Image

WURZEL = Path(__file__).resolve().parent.parent
LISTE = WURZEL / "docs" / "GRAFIKLISTE.md"
DATEN = WURZEL / "tools" / "uebungen.json"
ROH = WURZEL / "grafiken"
ZIEL_BILDER = WURZEL / "assets" / "exercises"
ZIEL_DART = WURZEL / "lib" / "programs" / "builtin_exercises.dart"
KANTE = 512

KATEGORIE = {"yoga": "yoga", "crossfit": "crossfit", "cali": "calisthenics", "dehnen": "stretching"}

# Bezeichner der Körperbereiche in der App (enum BodyArea)
BEREICH = {
    "nacken": "neck", "schultern": "shoulders", "arme": "arms", "brust": "chest",
    "ruecken": "back", "rumpf": "core", "huefte": "hips", "gesaess": "glutes",
    "beine": "legs", "waden": "calves", "ganzkoerper": "fullBody",
}

# Bis zu dieser Nummer reicht die erste Lieferung; die App legt spätere
# Übungen bei bestehenden Installationen nachträglich an.
ERSTE_LIEFERUNG_BIS = 80


def dart_string(text):
    return "'" + text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def main():
    roh = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROH
    daten = json.loads(DATEN.read_text(encoding="utf-8"))
    zeilen = [z for z in LISTE.read_text(encoding="utf-8").splitlines() if z.startswith("| G-")]
    eintraege = []
    for zeile in zeilen:
        nr, datei, name = [z.strip() for z in zeile.split("|")[1:4]]
        datei = datei.strip("`")
        kategorie = KATEGORIE[datei.split("_")[0]]
        if nr not in daten:
            sys.exit(f"Für {nr} fehlt der Eintrag in {DATEN.name}.")
        d = daten[nr]
        auf_zeit = d["auf_zeit"]
        if auf_zeit is None:
            auf_zeit = kategorie in ("yoga", "stretching")
        eintraege.append({
            "datei": datei,
            "kategorie": kategorie,
            "name": name,
            "anleitung": d["anleitung"],
            "bereiche": [BEREICH[b] for b in d["bereiche"]],
            "auf_zeit": auf_zeit,
            "lieferung": 1 if int(nr[2:]) <= ERSTE_LIEFERUNG_BIS else 2,
        })

    ZIEL_BILDER.mkdir(parents=True, exist_ok=True)
    vorhanden = 0
    for e in eintraege:
        quellen = sorted(p for p in roh.glob(e["datei"] + ".*") if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
        if not quellen:
            continue
        bild = Image.open(quellen[0]).convert("RGBA")
        bild.thumbnail((KANTE, KANTE), Image.LANCZOS)
        bild.save(ZIEL_BILDER / (e["datei"] + ".webp"), "WEBP", quality=82, method=6)
        vorhanden += 1

    ZIEL_DART.parent.mkdir(parents=True, exist_ok=True)
    teile = [
        "// Erzeugt von tools/uebungen_erzeugen.py aus docs/GRAFIKLISTE.md und",
        "// tools/uebungen.json. Nicht von Hand ändern, sondern die Quellen anpassen",
        "// und das Skript neu ausführen.",
        "",
        "import 'program_models.dart';",
        "",
        "const List<BuiltinExercise> builtinExercises = [",
    ]
    for e in eintraege:
        bereiche = ", ".join(f"BodyArea.{b}" for b in e["bereiche"])
        teile += [
            "  BuiltinExercise(",
            f"    key: {dart_string(e['datei'])},",
            f"    category: ExerciseCategory.{e['kategorie']},",
            f"    name: {dart_string(e['name'])},",
            f"    description:\n        {dart_string(e['anleitung'])},",
            f"    areas: [{bereiche}],",
            f"    timed: {'true' if e['auf_zeit'] else 'false'},",
            f"    batch: {e['lieferung']},",
            "  ),",
        ]
    teile += ["];", ""]
    ZIEL_DART.write_text("\n".join(teile), encoding="utf-8", newline="\n")
    print(f"{len(eintraege)} Uebungen geschrieben, {vorhanden} Bilder vorhanden.")


if __name__ == "__main__":
    main()
