import 'dart:io';

import 'package:flutter/foundation.dart';

/// Was die App auf dem jeweiligen Gerät kann. Am PC fehlen Kamera-Erkennung
/// und GPS; Dateien gehen über normale Ordner statt über den Teilen-Dialog.
abstract final class AppPlatform {
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;

  static bool get isDesktop =>
      isLinux || defaultTargetPlatform == TargetPlatform.windows;

  static bool get hasCamera => !isDesktop;
  static bool get hasGps => !isDesktop;
}

/// Öffnet [url] im Standardbrowser des PCs. `rundll32` statt `start`, weil
/// die Eingabeaufforderung Adressen am Zeichen & abschneiden würde.
Future<void> openInBrowser(String url) => AppPlatform.isLinux
    ? Process.run('xdg-open', [url])
    : Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
