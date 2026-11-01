import 'dart:convert';
import 'dart:io';

import 'package:fitapp/data/database.dart';
import 'package:fitapp/gps/phone_gps.dart';
import 'package:fitapp/interval/speaker.dart';
import 'package:fitapp/platform/app_platform.dart';
import 'package:fitapp/strava/strava_api.dart';
import 'package:fitapp/sync/auto_backup.dart';
import 'package:fitapp/sync/desktop_google_auth.dart';
import 'package:fitapp/ui/file_handover.dart';
import 'package:fitapp/ui/hero_pages.dart';
import 'package:fitapp/vision/hero_workouts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  void asPlatform(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  test('Windows und Linux gelten als PC ohne Kamera und GPS', () {
    expect(AppPlatform.isDesktop, isFalse);
    expect(AppPlatform.hasCamera, isTrue);
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      asPlatform(platform);
      expect(AppPlatform.isDesktop, isTrue);
      expect(AppPlatform.hasCamera, isFalse);
      expect(AppPlatform.hasGps, isFalse);
    }
    expect(AppPlatform.isLinux, isTrue);
  });

  test('am PC sagt die GPS-Vorbereitung ab', () async {
    asPlatform(TargetPlatform.windows);
    expect(await PhoneGps.prepare(), contains('PC'));
  });

  test('Strava leitet am PC auf den eigenen Rechner zurück', () {
    expect(StravaApi.redirectUri, startsWith('fitapp://'));
    expect(StravaApi.callbackScheme, 'fitapp');
    asPlatform(TargetPlatform.linux);
    expect(StravaApi.redirectUri, 'http://localhost:43823/strava');
    expect(StravaApi.callbackScheme, 'http://localhost:43823');
  });

  test('speech-dispatcher bekommt Sprache und geschützten Text', () {
    expect(SpdSpeaker.arguments('-5 Sekunden'),
        ['-l', 'de', '--', '-5 Sekunden']);
  });

  test('die Sicherung landet am PC in einem normalen Ordner', () async {
    asPlatform(TargetPlatform.windows);
    final folder = await Directory.systemTemp.createTemp('fitapp');
    addTearDown(() => folder.delete(recursive: true));
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    AutoBackup.useFolder(db, folder.path);
    final day = DateTime(2026, 11, 2);
    await AutoBackup.run(db, now: day);
    final file = File(p.join(folder.path, AutoBackup.fileName(day)));
    expect(await file.length(), greaterThan(0));
    expect(AutoBackup.folderName(db), folder.path);
    expect(AutoBackup.isDue(db, day), isFalse);
  });

  test('Dateien lassen sich in einen Ordner kopieren', () async {
    final folder = await Directory.systemTemp.createTemp('fitapp');
    addTearDown(() => folder.delete(recursive: true));
    final source = File(p.join(folder.path, 'lauf.fit'))
      ..writeAsStringSync('x');
    final target = await folder.createTemp('ziel');
    await copyFilesTo(target.path, [source.path]);
    expect(File(p.join(target.path, 'lauf.fit')).existsSync(), isTrue);
  });

  group('Google-Anmeldung am PC', () {
    const scope = 'https://www.googleapis.com/auth/drive.appdata';

    test('ohne Anmeldung fragt sie nicht von selbst nach', () async {
      final auth = DesktopGoogleAuth(MemorySecretStore());
      expect(await auth.client('id', [scope], interactive: false), isNull);
    });

    test('merkt sich das Geheimnis', () async {
      final auth = DesktopGoogleAuth(MemorySecretStore());
      expect(await auth.hasSecret, isFalse);
      await auth.setSecret('  geheim ');
      expect(await auth.hasSecret, isTrue);
    });

    test('eine gespeicherte Anmeldung gilt nur für ihre Rechte', () async {
      final store = MemorySecretStore();
      final saved = AccessCredentials(
        AccessToken('Bearer', 'a',
            DateTime.now().toUtc().add(const Duration(hours: 1))),
        'r',
        [scope],
      );
      await store.write(
          'google.desktopCredentials', jsonEncode(saved.toJson()));
      final auth = DesktopGoogleAuth(store);
      final client = await auth.client('id', [scope], interactive: false);
      expect(client, isNotNull);
      client!.close();
      expect(await auth.client('id', ['anderes'], interactive: false), isNull);
      await auth.signOut();
      expect(await auth.client('id', [scope], interactive: false), isNull);
    });
  });

  testWidgets('am PC erklärt das Workout das Zählen von Hand', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(MaterialApp(
      home: HeroWorkoutPage(
          db: db, workout: heroWorkouts.first, onWorkoutSaved: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rückkamera'), findsNothing);
    expect(find.textContaining('zählt keine Kamera'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
