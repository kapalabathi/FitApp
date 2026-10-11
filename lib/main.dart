import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/database.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  final db = await AppDatabase.open();
  // Ein Training, das beim letzten Mal nicht beendet wurde, wird gerettet,
  // bevor ein neues beginnen kann (Lastenheft A-024).
  final recovered = db.recoverUnfinished();
  runApp(FitApp(db: db, recoveredWorkouts: recovered));
}

class FitApp extends StatelessWidget {
  const FitApp({super.key, required this.db, this.recoveredWorkouts = 0});

  final AppDatabase db;
  final int recoveredWorkouts;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE8734A);
    return MaterialApp(
      title: 'FitApp',
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      home: HomePage(db: db, recoveredWorkouts: recoveredWorkouts),
    );
  }
}
