"""Erzeugt die mitgelieferten Übungen der App aus docs/GRAFIKLISTE.md.

- schreibt lib/programs/builtin_exercises.dart (Name, Kategorie, Anleitung,
  Standardvorgabe je Übung)
- verkleinert die Rohbilder aus grafiken/ nach assets/exercises/ (WebP, 512 px)

Nach neuen oder geänderten Bildern einfach erneut ausführen:
    python tools/uebungen_erzeugen.py
"""

import sys
from pathlib import Path

from PIL import Image

WURZEL = Path(__file__).resolve().parent.parent
LISTE = WURZEL / "docs" / "GRAFIKLISTE.md"
ROH = WURZEL / "grafiken"
ZIEL_BILDER = WURZEL / "assets" / "exercises"
ZIEL_DART = WURZEL / "lib" / "programs" / "builtin_exercises.dart"
KANTE = 512

KATEGORIE = {"yoga": "yoga", "crossfit": "crossfit", "cali": "calisthenics", "dehnen": "stretching"}

# Übungen, die gehalten oder auf Zeit ausgeführt werden, obwohl ihre Kategorie
# sonst Wiederholungen zählt.
AUF_ZEIT = {
    "G-027", "G-032", "G-036", "G-039", "G-040",
    "G-050", "G-051", "G-052", "G-054", "G-058", "G-059", "G-060",
}

ANLEITUNG = {
    # Yoga
    "G-001": "Aufrecht stehen, Füße geschlossen, das Gewicht gleichmäßig verteilen. Schultern locker, Scheitel nach oben, ruhig atmen.",
    "G-002": "Aus dem Vierfüßlerstand das Gesäß nach oben schieben, Arme und Rücken lang machen. Die Fersen sinken Richtung Boden, der Kopf hängt locker zwischen den Armen.",
    "G-003": "Aus der Bauchlage die Arme durchstrecken und die Brust nach vorn oben heben. Hüfte und Oberschenkel schweben, nur Hände und Fußrücken tragen.",
    "G-004": "In Bauchlage die Hände neben die Brust setzen und den Oberkörper aus der Rückenkraft anheben. Das Becken bleibt am Boden, die Ellbogen nah am Körper.",
    "G-005": "Auf die Fersen setzen, den Oberkörper nach vorn ablegen, die Stirn zum Boden. Arme lang nach vorn, in den Rücken atmen.",
    "G-006": "Im Vierfüßlerstand beim Einatmen ins Hohlkreuz gehen und den Blick heben, beim Ausatmen den Rücken rund machen und das Kinn zur Brust ziehen. Fließend wechseln.",
    "G-007": "Großer Ausfallschritt, vorderes Knie über dem Fußgelenk, hinteres Bein gestreckt. Das Becken nach vorn ausrichten und die Arme nach oben strecken. Seite wechseln.",
    "G-008": "Breiter Stand, das vordere Knie beugen, die Arme waagerecht ausbreiten. Der Oberkörper bleibt aufrecht über dem Becken, der Blick geht über die vordere Hand. Seite wechseln.",
    "G-009": "Das Gewicht auf ein Bein verlagern, Oberkörper und anderes Bein in die Waagerechte bringen. Arme nach vorn strecken, die Hüfte parallel zum Boden halten. Seite wechseln.",
    "G-010": "Breiter Stand mit gestreckten Beinen, den Oberkörper seitlich über das vordere Bein neigen. Untere Hand ans Schienbein, oberen Arm zur Decke strecken. Seite wechseln.",
    "G-011": "Auf einem Bein stehen, die Fußsohle des anderen an die Innenseite des Oberschenkels setzen, nicht ans Knie. Hände über dem Kopf zusammenführen und einen Punkt fixieren. Seite wechseln.",
    "G-012": "Füße geschlossen, die Knie beugen und das Gesäß nach hinten schieben wie auf einen Stuhl. Arme schräg nach oben, Rücken lang.",
    "G-013": "Aus der Hüfte nach vorn falten und den Oberkörper hängen lassen. Die Knie dürfen leicht gebeugt sein, der Nacken ist locker.",
    "G-014": "Mit gestreckten Beinen sitzen, mit langem Rücken nach vorn beugen und Richtung Füße greifen. Nicht ziehen, mit jeder Ausatmung etwas tiefer sinken.",
    "G-015": "In Rückenlage die Füße hüftbreit aufstellen und das Becken anheben. Die Knie bleiben parallel, Schultern und Kopf liegen am Boden.",
    "G-016": "Auf dem Gesäß balancieren, Beine und Oberkörper zu einem V anheben. Rücken gerade, Arme parallel zum Boden. Leichter mit gebeugten Knien.",
    "G-017": "Ein Bein angewinkelt vor dem Körper ablegen, das andere lang nach hinten strecken. Das Becken gerade ausrichten, den Oberkörper aufrichten oder nach vorn ablegen. Seite wechseln.",
    "G-018": "Im Sitz ein Bein über das andere stellen und den Oberkörper zum aufgestellten Knie drehen. Mit der Einatmung aufrichten, mit der Ausatmung weiter drehen. Seite wechseln.",
    "G-019": "Das hintere Knie ablegen und die Hüfte nach vorn unten sinken lassen. Den Oberkörper aufrichten und die Arme nach oben strecken. Seite wechseln.",
    "G-020": "Flach auf dem Rücken liegen, Arme und Beine locker ausgebreitet. Augen schließen und den Atem frei fließen lassen.",
    # Crossfit
    "G-021": "Füße schulterbreit, das Gesäß nach hinten unten führen, bis die Hüfte unter Kniehöhe ist. Fersen am Boden, Knie in Richtung der Zehen, Brust aufrecht.",
    "G-022": "In die Hocke gehen, in den Liegestütz springen und die Brust ablegen. Wieder anhocken und mit einem Strecksprung abschließen.",
    "G-023": "Aus leichter Hocke mit Armschwung auf die Box springen und oben ganz aufrichten. Kontrolliert wieder heruntersteigen.",
    "G-024": "Die Hüfte nach hinten schieben, die Kettlebell zwischen den Beinen durchschwingen und mit einer kräftigen Hüftstreckung auf Brusthöhe bringen. Der Rücken bleibt gerade, die Arme führen nur.",
    "G-025": "Mit der Hantel auf den Schultern tief in die Kniebeuge gehen. Beim Aufstehen den Schwung nutzen und die Hantel über den Kopf strecken.",
    "G-026": "Mit dem Ball vor der Brust in die Kniebeuge gehen, explosiv aufstehen und den Ball an ein hohes Ziel an der Wand werfen. Fangen und direkt in die nächste Kniebeuge.",
    "G-027": "Mit kleinen Sprüngen auf den Fußballen springen, das Seil kommt aus den Handgelenken. Die Ellbogen bleiben nah am Körper.",
    "G-028": "Die Stange nah am Schienbein greifen, Rücken gerade, Schultern über der Stange. Mit Beinen und Hüfte aufrichten, die Stange bleibt nah am Körper.",
    "G-029": "Die Kettlebell dicht vor der Brust halten und tief in die Kniebeuge gehen. Ellbogen zwischen die Knie, Oberkörper aufrecht.",
    "G-030": "Hantel auf den Schultern, leicht in die Knie gehen und sie mit dem Schwung der Beine über den Kopf drücken. Oben die Arme ganz strecken.",
    "G-031": "An der Stange hängend die gestreckten Beine anheben, bis die Zehen die Stange berühren. Kontrolliert ablassen.",
    "G-032": "Im hohen Stütz die Knie abwechselnd schnell zur Brust ziehen. Die Hüfte bleibt tief, die Schultern über den Händen.",
    "G-033": "Einen großen Schritt nach vorn machen und beide Knie etwa 90 Grad beugen, das hintere knapp über dem Boden. Aufstehen und mit dem anderen Bein weitergehen.",
    "G-034": "Aus der Rückenlage mit aufgestellten Füßen den Oberkörper ganz aufrichten. Langsam wieder abrollen.",
    "G-035": "Die Hantel aus der Hocke in einer Bewegung vom Boden über den Kopf bringen. Die Kraft kommt aus Beinen und Hüfte. Seite wechseln.",
    "G-036": "In jeder Hand ein Gewicht, aufrecht und zügig gehen. Schultern zurück, Rumpf fest.",
    "G-037": "Einen Fuß ganz auf die Box stellen und über dieses Bein hochdrücken, bis du oben aufrecht stehst. Kontrolliert absteigen, Seite wechseln.",
    "G-038": "Im Sitz leicht zurücklehnen, die Füße anheben und den Oberkörper mit dem Gewicht von Seite zu Seite drehen. Der Rücken bleibt gerade.",
    "G-039": "Beim Sprung die Beine grätschen und die Arme über den Kopf führen, beim nächsten wieder schließen. Locker und gleichmäßig.",
    "G-040": "Auf Händen und Füßen mit flachem Rücken vorwärts krabbeln, die Knie knapp über dem Boden. Hand und Fuß gegengleich setzen.",
    # Calisthenics
    "G-041": "Hände etwas breiter als schulterbreit, der Körper von Kopf bis Ferse eine Linie. Die Brust bis knapp über den Boden senken und wieder hochdrücken.",
    "G-042": "Wie der Liegestütz, aber mit den Knien am Boden. Die Hüfte nicht abknicken, der Körper bleibt von Kopf bis Knie gerade.",
    "G-043": "Die Hände unter der Brust so aufsetzen, dass Daumen und Zeigefinger eine Raute bilden. Die Ellbogen nah am Körper führen.",
    "G-044": "Das Gesäß hoch wie im herabschauenden Hund, die Ellbogen beugen und den Kopf zwischen die Hände senken. Wieder hochdrücken.",
    "G-045": "Im Obergriff etwas breiter als schulterbreit hängen und hochziehen, bis das Kinn über der Stange ist. Kontrolliert ganz ablassen.",
    "G-046": "Im Untergriff schulterbreit hängen und hochziehen, bis das Kinn über der Stange ist. Die Ellbogen vor dem Körper führen.",
    "G-047": "Unter einer hüfthohen Stange hängen, der Körper gestreckt, die Fersen am Boden. Die Brust zur Stange ziehen.",
    "G-048": "Im Stütz am Barren die Ellbogen bis etwa 90 Grad beugen und wieder hochdrücken. Die Schultern bleiben unten.",
    "G-049": "Die Hände hinter dem Körper auf die Bankkante stützen, das Gesäß vor der Bank absenken und wieder hochdrücken. Die Ellbogen zeigen nach hinten.",
    "G-050": "Auf Unterarmen und Zehenspitzen stützen, die Ellbogen unter den Schultern. Bauch und Gesäß anspannen, nicht durchhängen.",
    "G-051": "Seitlich auf einem Unterarm stützen, die Füße übereinander, die Hüfte anheben. Der Körper bildet eine Linie. Seite wechseln.",
    "G-052": "In Rückenlage den unteren Rücken in den Boden drücken, Schultern und gestreckte Beine leicht anheben. Arme lang über den Kopf.",
    "G-053": "An der Stange hängend die gestreckten Beine bis zur Waagerechten heben. Ohne Schwung arbeiten.",
    "G-054": "Im Stütz die gestreckten Beine waagerecht nach vorn halten. Die Schultern nach unten drücken. Leichter mit angezogenen Knien.",
    "G-055": "Auf einem Bein tief in die Hocke gehen, das andere gestreckt nach vorn halten. Die Ferse bleibt am Boden. Zum Üben an etwas festhalten.",
    "G-056": "Den hinteren Fuß auf eine Bank legen und das vordere Knie beugen, bis der Oberschenkel waagerecht ist. Oberkörper aufrecht. Seite wechseln.",
    "G-057": "In Bauchlage Arme, Brust und Beine gleichzeitig vom Boden heben. Kurz halten, der Blick bleibt zum Boden gerichtet.",
    "G-058": "Mit dem Rücken an der Wand in die Sitzposition rutschen, Knie und Hüfte im rechten Winkel. Halten.",
    "G-059": "Mit dem Bauch zur Wand in den Handstand gehen. Arme gestreckt, der Körper lang und fest. Nur ausführen, wenn du den Handstand sicher beherrschst.",
    "G-060": "Die Hände aufsetzen, die Knie auf die Oberarme legen und das Gewicht nach vorn verlagern, bis die Füße abheben. Der Blick geht nach vorn.",
    # Dehnen
    "G-061": "Den Kopf zur Schulter neigen, die Hand liegt nur leicht auf. Die Gegenschulter nach unten ziehen. Seite wechseln.",
    "G-062": "Einen gestreckten Arm vor der Brust zur Gegenseite führen und mit dem anderen Arm heranziehen. Die Schulter bleibt unten. Seite wechseln.",
    "G-063": "Einen Arm über den Kopf beugen, die Hand zwischen die Schulterblätter. Mit der anderen Hand den Ellbogen sanft zur Mitte ziehen. Seite wechseln.",
    "G-064": "Den Unterarm senkrecht an Wand oder Türrahmen legen, der Ellbogen auf Schulterhöhe. Den Oberkörper von der Wand wegdrehen. Seite wechseln.",
    "G-065": "Einen Arm lang über den Kopf zur Gegenseite ziehen und die Flanke öffnen. Nicht nach vorn kippen. Seite wechseln.",
    "G-066": "In Schrittstellung an der Wand abstützen, das hintere Bein gestreckt, die Ferse am Boden. Die Hüfte nach vorn schieben. Seite wechseln.",
    "G-067": "Im Stand eine Ferse zum Gesäß ziehen, die Knie zeigen nach unten. Das Becken leicht nach vorn schieben, ohne ins Hohlkreuz zu gehen. Seite wechseln.",
    "G-068": "Ein Bein gestreckt nach vorn auf die Ferse stellen, die Zehen anziehen. Mit geradem Rücken aus der Hüfte nach vorn neigen. Seite wechseln.",
    "G-069": "Im knienden Ausfallschritt die Hüfte nach vorn schieben, der Oberkörper bleibt aufrecht. Das Gesäß der hinteren Seite anspannen. Seite wechseln.",
    "G-070": "Im Sitz die Fußsohlen aneinanderlegen und die Knie nach außen sinken lassen. Der Rücken bleibt aufrecht.",
    "G-071": "Mit weit geöffneten, gestreckten Beinen sitzen und mit langem Rücken nach vorn wandern.",
    "G-072": "In Rückenlage einen Knöchel auf das andere Knie legen und dieses Bein zur Brust ziehen. Seite wechseln.",
    "G-073": "In Rückenlage beide Knie mit den Händen zur Brust ziehen. Der untere Rücken wird rund und entspannt.",
    "G-074": "In Rückenlage ein Knie über den Körper zur Gegenseite legen, die Arme liegen als T. Beide Schultern bleiben am Boden. Seite wechseln.",
    "G-075": "Tief in die Hocke sinken, die Fersen am Boden. Mit den Ellbogen die Knie sanft nach außen drücken, der Rücken bleibt lang.",
    "G-076": "Im sehr breiten Stand ein Knie beugen und das Gewicht zur Seite verlagern, das andere Bein bleibt gestreckt. Seite wechseln.",
    "G-077": "Einen Arm nach vorn strecken, die Finger zeigen nach unten, und mit der anderen Hand die Finger sanft zum Körper ziehen. Seite wechseln.",
    "G-078": "Im Vierfüßlerstand einen Arm unter dem Körper durchfädeln und Schulter und Schläfe ablegen. Seite wechseln.",
    "G-079": "Mit aufgestellten Zehen auf die Fersen setzen. Die Dehnung ist intensiv, vorsichtig dosieren.",
    "G-080": "Im tiefen Ausfallschritt eine Hand neben den vorderen Fuß setzen und den anderen Arm zur Decke aufdrehen. Der Blick folgt der oberen Hand. Seite wechseln.",
}


def dart_string(text):
    return "'" + text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def main():
    zeilen = [z for z in LISTE.read_text(encoding="utf-8").splitlines() if z.startswith("| G-")]
    eintraege = []
    for zeile in zeilen:
        nr, datei, name = [z.strip() for z in zeile.split("|")[1:4]]
        datei = datei.strip("`")
        kategorie = KATEGORIE[datei.split("_")[0]]
        if nr not in ANLEITUNG:
            sys.exit(f"Für {nr} fehlt die Anleitung in diesem Skript.")
        auf_zeit = kategorie in ("yoga", "stretching") or nr in AUF_ZEIT
        eintraege.append((datei, kategorie, name, ANLEITUNG[nr], auf_zeit))

    ZIEL_BILDER.mkdir(parents=True, exist_ok=True)
    vorhanden = 0
    for datei, *_ in eintraege:
        quellen = sorted(p for p in ROH.glob(datei + ".*") if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
        if not quellen:
            continue
        bild = Image.open(quellen[0]).convert("RGBA")
        bild.thumbnail((KANTE, KANTE), Image.LANCZOS)
        bild.save(ZIEL_BILDER / (datei + ".webp"), "WEBP", quality=82, method=6)
        vorhanden += 1

    ZIEL_DART.parent.mkdir(parents=True, exist_ok=True)
    teile = [
        "// Erzeugt von tools/uebungen_erzeugen.py aus docs/GRAFIKLISTE.md.",
        "// Nicht von Hand ändern, sondern das Skript anpassen und neu ausführen.",
        "",
        "import 'program_models.dart';",
        "",
        "const List<BuiltinExercise> builtinExercises = [",
    ]
    for datei, kategorie, name, anleitung, auf_zeit in eintraege:
        teile += [
            "  BuiltinExercise(",
            f"    key: {dart_string(datei)},",
            f"    category: ExerciseCategory.{kategorie},",
            f"    name: {dart_string(name)},",
            f"    description:\n        {dart_string(anleitung)},",
            f"    timed: {'true' if auf_zeit else 'false'},",
            "  ),",
        ]
    teile += ["];", ""]
    ZIEL_DART.write_text("\n".join(teile), encoding="utf-8", newline="\n")
    print(f"{len(eintraege)} Übungen geschrieben, {vorhanden} Bilder verkleinert.")


if __name__ == "__main__":
    main()
