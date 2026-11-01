# Google Drive für die Synchronisation einrichten

Die App gleicht ihre Daten über den App-Datenordner deines Google Drive ab. Google lässt das nur zu, wenn die App bei Google angemeldet ist. Das geschieht einmalig in der Google-Cloud-Konsole und kostet nichts.

Diese Anleitung ist nach der Dokumentation der verwendeten Bibliotheken geschrieben und noch nicht an einem echten Konto durchgespielt. Menünamen in der Konsole können leicht abweichen.

Ohne diese Einrichtung funktioniert der Abgleich über die Sicherungsdatei (in der App: Verlauf → Synchronisation → „Sicherung erstellen" und „Sicherung einspielen").

## Was du brauchst

| Angabe | Wert |
|--------|------|
| Paketname der App | `de.kapalabathi.fitapp` |
| SHA-1-Fingerabdruck (Entwicklungsversion, gebaut auf diesem Rechner) | `51:7F:0E:F8:67:82:2A:9D:5F:DF:25:1E:D4:D3:CD:60:B8:BF:44:BE` |

Der Fingerabdruck gehört zum Schlüssel, mit dem dieser Rechner die App signiert. Wird die App auf einem anderen Rechner oder später als Verkaufsversion gebaut, braucht sie einen weiteren Eintrag mit dem dortigen Fingerabdruck.

## Schritte

1. **Projekt anlegen:** Auf https://console.cloud.google.com mit deinem Google-Konto anmelden und ein neues Projekt anlegen, zum Beispiel „FitApp".
2. **Drive-Schnittstelle einschalten:** Unter „APIs & Dienste" → „Bibliothek" nach „Google Drive API" suchen und aktivieren.
3. **Zustimmungsbildschirm:** Unter „APIs & Dienste" → „OAuth-Zustimmungsbildschirm" den Nutzertyp „Extern" wählen, einen App-Namen und deine E-Mail-Adresse eintragen. Die App bleibt im Status „Test". Unter „Testnutzer" dein eigenes Google-Konto hinzufügen.
4. **Android-Client:** Unter „APIs & Dienste" → „Anmeldedaten" → „Anmeldedaten erstellen" → „OAuth-Client-ID" den Typ „Android" wählen und Paketname und SHA-1-Fingerabdruck aus der Tabelle oben eintragen.
5. **Web-Client:** Am selben Ort eine zweite OAuth-Client-ID vom Typ „Webanwendung" anlegen. Weitere Angaben sind nicht nötig. Die angezeigte Client-ID endet auf `.apps.googleusercontent.com`.
6. **In der App:** Verlauf → Synchronisation, die Web-Client-ID eintragen und „Jetzt abgleichen" tippen. Beim ersten Mal fragt Google nach der Anmeldung und nach dem Zugriff auf die App-Daten in Drive.
7. **Am PC (Windows oder Linux):** Eine weitere OAuth-Client-ID vom Typ „Desktop-App" anlegen. In der App Client-ID und Client-Secret dieses Clients eintragen; Google öffnet zur Anmeldung den Browser. Solange die App im Status „Test" ist, läuft die Anmeldung nach etwa sieben Tagen ab und muss wiederholt werden.
8. **Auf dem zweiten Gerät:** dieselbe Web-Client-ID eintragen und abgleichen. Dasselbe Google-Konto verwenden.

Nach dem ersten erfolgreichen Abgleich läuft er von selbst: beim Start der App und nach jedem Training.

## Was synchronisiert wird

- Trainings mit Messpunkten, Runden und Notizen
- Intervall-Vorlagen
- Übungen (ohne selbst hinterlegte Bilder; die bleiben auf dem Gerät) und Programme
- Geburtsjahr und Maximalpuls

Nicht synchronisiert werden gemerkte Bluetooth-Geräte, die Strava-Zugangsdaten und die Signal-Einstellungen.

## Regeln beim Abgleich

- Wurde derselbe Eintrag auf zwei Geräten geändert, gilt die jüngere Änderung.
- Gelöschtes wird auf allen Geräten gelöscht.
- Die Dateien liegen im App-Datenordner von Drive. Er ist in der Drive-Oberfläche nicht sichtbar, und die App hat keinen Zugriff auf deine übrigen Dateien.

## Wenn die Anmeldung fehlschlägt

Die häufigsten Ursachen laut Dokumentation: falscher oder fehlender SHA-1-Fingerabdruck beim Android-Client, eine falsche Web-Client-ID in der App, oder dein Konto fehlt unter den Testnutzern.
