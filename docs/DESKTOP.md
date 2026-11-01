# FitApp für Windows und Linux

Stand: Version 0.22.0. Der Code ist vorbereitet, gebaut wurde die Desktop-Fassung noch nicht: Dafür fehlen auf dem Entwicklungsrechner die Build-Werkzeuge.

## Was am PC anders ist

| Bereich | Am PC |
|---|---|
| Kamera bei den WODs | Entfällt, gezählt wird mit + und − |
| GPS-Sportarten | Nicht wählbar |
| Export und Sicherung | Speichern in einem Ordner statt Teilen-Dialog |
| Automatische Sicherung | Normaler Ordner |
| Aufzeichnung im Hintergrund | Nicht nötig, der Android-Dienst läuft nicht |
| Google Drive | Anmeldung im Browser, eigener Client vom Typ „Desktop-App" |
| Strava | Anmeldung im Browser, Rückleitung auf `http://localhost:43823` |
| Sprachansagen unter Linux | Über speech-dispatcher (`spd-say`) |

## Windows bauen

1. Entwicklermodus einschalten: Windows braucht ihn für die symbolischen Verknüpfungen der Plugins.

   ```bash
   start ms-settings:developers
   ```

2. Visual Studio Build Tools mit dem C++-Paket installieren:

   ```bash
   winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --override "--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
   ```

3. Bauen:

   ```bash
   flutter build windows --debug
   ```

Das Programm liegt danach unter `build\windows\x64\runner\Debug\fitapp.exe`.

## Linux bauen

Gebaut wird unter Linux selbst. Unter Debian und Ubuntu:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libsecret-1-dev libjsoncpp-dev speech-dispatcher
```

```bash
flutter config --enable-linux-desktop
```

```bash
flutter build linux --debug
```

Das Programm liegt unter `build/linux/x64/debug/bundle/fitapp`. Bluetooth läuft über BlueZ und braucht echte Hardware; in WSL lässt sich bauen, aber nicht koppeln.

## Zuerst prüfen

Bluetooth ist das Hauptrisiko: Mit Laufband und Brustgurt koppeln und eine Einheit aufzeichnen, bevor der Rest geprüft wird.
