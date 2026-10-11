import 'dart:io';

import 'package:flutter/material.dart';

import '../programs/program_models.dart';

/// Die Grafik einer Übung: das selbst hinterlegte Bild, sonst die
/// mitgelieferte Grafik, sonst ein einheitlicher Platzhalter (A-046).
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({super.key, required this.exercise, this.size});

  final Exercise exercise;

  /// Kantenlänge; ohne Angabe füllt das Bild den verfügbaren Platz.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(exercise.category.sport.icon,
              color: scheme.onSurfaceVariant),
        ),
      ),
    );
    Widget onError(BuildContext _, Object _, StackTrace? _) => placeholder;

    final path = exercise.imagePath;
    final asset = exercise.imageAsset;
    final Widget image = path != null
        ? Image.file(File(path), fit: BoxFit.cover, errorBuilder: onError)
        : asset != null
            ? Image.asset(asset, fit: BoxFit.cover, errorBuilder: onError)
            : placeholder;

    return SizedBox(
      width: size,
      height: size,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image,
        ),
      ),
    );
  }
}
