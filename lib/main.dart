import 'package:flutter/material.dart';

import 'ui/scan_page.dart';

void main() {
  runApp(const FitApp());
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE8734A);
    return MaterialApp(
      title: 'FitApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      home: const ScanPage(),
    );
  }
}
