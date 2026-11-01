import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../platform/app_platform.dart';

export 'package:share_plus/share_plus.dart' show XFile;

/// Gibt Dateien weiter: auf dem Phone über den Teilen-Dialog, am PC durch
/// Speichern in einem gewählten Ordner. Gibt zurück, ob das geschehen ist.
Future<bool> handOverFiles(List<XFile> files, {String? subject}) async {
  if (!AppPlatform.isDesktop) {
    await SharePlus.instance.share(ShareParams(files: files, subject: subject));
    return true;
  }
  final folder =
      await FilePicker.getDirectoryPath(dialogTitle: 'Speichern in …');
  if (folder == null) return false;
  await copyFilesTo(folder, [for (final f in files) f.path]);
  return true;
}

/// Kopiert die Dateien unter ihrem Namen nach [folder].
Future<void> copyFilesTo(String folder, List<String> paths) async {
  for (final path in paths) {
    await File(path).copy(p.join(folder, p.basename(path)));
  }
}

/// Gibt Text weiter: am PC landet er in der Zwischenablage. Gibt zurück, ob
/// er dort liegt.
Future<bool> handOverText(String text) async {
  if (!AppPlatform.isDesktop) {
    await SharePlus.instance.share(ShareParams(text: text));
    return false;
  }
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}
