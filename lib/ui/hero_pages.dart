import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../interval/signals.dart';
import '../session/workout_session.dart';
import '../vision/hero_workouts.dart';
import '../vision/pose_camera.dart';
import '../vision/rep_counter.dart';
import 'format.dart';
import 'program_start.dart';

/// Die Bestzeit eines Workouts in Sekunden, oder `null`, wenn es noch nie zu
/// Ende geturnt wurde.
int? heroBestTime(AppDatabase db, HeroWorkout workout) {
  int? best;
  for (final w in db.workouts(sport: Sport.crossfit)) {
    if (w.title != workout.title) continue;
    if (best == null || w.durationS < best) best = w.durationS;
  }
  return best;
}

/// Ein Workout vor dem Start: Ablauf, Bestzeit und Kamerawahl.
class HeroWorkoutPage extends StatefulWidget {
  const HeroWorkoutPage({
    super.key,
    required this.db,
    required this.workout,
    required this.onWorkoutSaved,
  });

  final AppDatabase db;
  final HeroWorkout workout;
  final VoidCallback onWorkoutSaved;

  @override
  State<HeroWorkoutPage> createState() => _HeroWorkoutPageState();
}

class _HeroWorkoutPageState extends State<HeroWorkoutPage> {
  static const _cameraKey = 'hero.camera';

  late CameraLensDirection _lens = widget.db.setting(_cameraKey) == 'front'
      ? CameraLensDirection.front
      : CameraLensDirection.back;

  Future<void> _start() async {
    final db = widget.db;
    db.setSetting(_cameraKey,
        _lens == CameraLensDirection.front ? 'front' : 'back');
    final session = WorkoutSession(
      db: db,
      sport: Sport.crossfit,
      devices: heartRateSensors(db, Sport.crossfit),
      signals: createSignals(SignalSettings.load(db)),
    );
    final done = await Navigator.of(context).push<(Workout, bool)?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => HeroPlayerPage(
          session: session,
          workout: widget.workout,
          lens: _lens,
        ),
      ),
    );
    if (!mounted || done == null) {
      if (mounted) setState(() {});
      return;
    }
    final (saved, complete) = done;
    db.updateWorkout(
      saved.id,
      title: complete ? widget.workout.title : widget.workout.abortedTitle,
      sport: saved.sport,
      notes: saved.notes ?? '',
    );
    final titled = db.workout(saved.id) ?? saved;
    setState(() {});
    await showSavedWorkout(context, db, titled, widget.onWorkoutSaved);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = widget.workout;
    final best = heroBestTime(widget.db, w);
    final kinds = {for (final b in w.blocks) b.label: b.kind};
    return Scaffold(
      appBar: AppBar(title: Text(w.name)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'start-hero',
        onPressed: _start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(w.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('${w.totalReps} Wiederholungen  ·  ${w.equipment}'),
          Text(best == null
              ? 'Noch keine Bestzeit'
              : 'Bestzeit ${formatDuration(best)}'),
          const SizedBox(height: 16),
          Text('Kamera', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<CameraLensDirection>(
            segments: const [
              ButtonSegment(
                value: CameraLensDirection.back,
                icon: Icon(Icons.camera_rear),
                label: Text('Rückkamera'),
              ),
              ButtonSegment(
                value: CameraLensDirection.front,
                icon: Icon(Icons.camera_front),
                label: Text('Frontkamera'),
              ),
            ],
            selected: {_lens},
            onSelectionChanged: (s) => setState(() => _lens = s.first),
          ),
          const SizedBox(height: 16),
          Text('So stellst du das Phone auf',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Fest hinstellen, etwa 2 bis 3 Meter entfernt. Dein '
              'ganzer Körper muss in jeder Phase im Bild sein. Bei jedem '
              'Abschnitt steht, wo die Kamera am besten steht; im Training '
              'lässt sie sich jederzeit wechseln.'),
          const SizedBox(height: 8),
          for (final e in kinds.entries)
            Text('${e.key}: ${e.value.hint}'),
          const SizedBox(height: 12),
          const Text('Zählt die Kamera falsch, korrigierst du mit + und −, '
              'oder gehst mit „Weiter" zum nächsten Abschnitt. Die Bilder '
              'werden nur auf dem Phone ausgewertet und nicht gespeichert.'),
        ],
      ),
    );
  }
}

/// Das laufende Workout: Kamerabild mit Gerüst, Zähler und Korrekturknöpfe.
class HeroPlayerPage extends StatefulWidget {
  const HeroPlayerPage({
    super.key,
    required this.session,
    required this.workout,
    required this.lens,
  });

  final WorkoutSession session;
  final HeroWorkout workout;
  final CameraLensDirection lens;

  @override
  State<HeroPlayerPage> createState() => _HeroPlayerPageState();
}

class _HeroPlayerPageState extends State<HeroPlayerPage> {
  late final HeroRun _run = HeroRun(widget.workout);
  late final PoseCamera _camera = PoseCamera(onPose: _onPose);
  late RepCounter _counter = RepCounter(widget.workout.blocks.first.kind);
  bool _finishing = false;

  WorkoutSession get _session => widget.session;
  int get _elapsed => _session.recorder.elapsedS;

  @override
  void initState() {
    super.initState();
    _camera.start(widget.lens);
    _announce();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _announce() {
    final block = _run.current;
    if (block == null) return;
    _session.signals.change();
    _session.signals.say('${block.reps} ${block.label}');
  }

  void _onPose(BodyPose pose, Duration at) {
    if (_session.recorder.paused || _finishing) return;
    if (_counter.add(pose, at)) _apply(_run.addRep(_elapsed));
  }

  void _apply(HeroChange? change) {
    switch (change) {
      case HeroChange.counted:
        _session.signals.warn();
      case HeroChange.blockDone:
        _logLastSplit();
        _counter = RepCounter(_run.current!.kind);
        _announce();
      case HeroChange.finished:
        _logLastSplit();
        _finish(complete: true);
      case null:
        break;
    }
    if (mounted) setState(() {});
  }

  void _logLastSplit() {
    final s = _run.splits.last;
    _session.recorder.db.addSetLog(
      _session.recorder.workoutId,
      SetLog(
        exerciseUuid: s.block.exerciseUuid,
        t: s.endT,
        reps: s.reps,
        seconds: s.seconds,
      ),
    );
  }

  void _finish({required bool complete}) {
    if (_finishing) return;
    _finishing = true;
    if (complete) _session.signals.finish();
    final saved = _session.finish();
    Navigator.of(context).pop(saved == null ? null : (saved, complete));
  }

  Future<void> _confirmStop() async {
    if (_finishing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout abbrechen?'),
        content:
            const Text('Das bisherige Training wird gespeichert, zählt '
                'aber nicht als Bestzeit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weitermachen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abbrechen und speichern'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _finish(complete: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_session, _camera]),
        builder: (context, _) {
          final block = _run.current;
          final heartRate =
              _session.recorder.value(Metric.heartRate)?.round();
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(widget.workout.name),
              actions: [
                if (_camera.canSwitch)
                  IconButton(
                    tooltip: 'Kamera wechseln',
                    onPressed: _camera.switchCamera,
                    icon: const Icon(Icons.cameraswitch),
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _run.progress),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(child: _CameraView(camera: _camera)),
                  if (block != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(_elapsed),
                              style: theme.textTheme.titleMedium),
                          Text(
                              'Abschnitt ${_run.blockNumber}/${_run.blockTotal}',
                              style: theme.textTheme.titleMedium),
                          Text(heartRate == null ? '♥ –' : '♥ $heartRate',
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
                    Text(block.label, style: theme.textTheme.titleLarge),
                    Text('${_run.count} / ${block.reps}',
                        style: theme.textTheme.displayMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      _counter.tracking
                          ? block.kind.hint
                          : 'Nicht im Bild: ${block.kind.hint}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Workout abbrechen',
                          onPressed: _confirmStop,
                          icon: const Icon(Icons.stop),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Eine Wiederholung weniger',
                          onPressed: () => setState(_run.removeRep),
                          icon: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Eine Wiederholung mehr',
                          onPressed: () => _apply(_run.addRep(_elapsed)),
                          icon: const Icon(Icons.add),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                _apply(_run.skipBlock(_elapsed)),
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Weiter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({required this.camera});

  final PoseCamera camera;

  @override
  Widget build(BuildContext context) {
    final controller = camera.controller;
    final error = camera.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: CameraPreview(
        controller,
        child: CustomPaint(
          size: Size.infinite,
          painter: _SkeletonPainter(
            pose: camera.pose,
            imageSize: camera.imageSize,
            mirrored: camera.lens == CameraLensDirection.front,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Zeichnet das erkannte Gerüst über das Kamerabild.
class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.mirrored,
    required this.color,
  });

  final BodyPose pose;
  final Size imageSize;
  final bool mirrored;
  final Color color;

  static const _bones = [
    (Joint.leftShoulder, Joint.rightShoulder),
    (Joint.leftShoulder, Joint.leftElbow),
    (Joint.leftElbow, Joint.leftWrist),
    (Joint.rightShoulder, Joint.rightElbow),
    (Joint.rightElbow, Joint.rightWrist),
    (Joint.leftShoulder, Joint.leftHip),
    (Joint.rightShoulder, Joint.rightHip),
    (Joint.leftHip, Joint.rightHip),
    (Joint.leftHip, Joint.leftKnee),
    (Joint.leftKnee, Joint.leftAnkle),
    (Joint.rightHip, Joint.rightKnee),
    (Joint.rightKnee, Joint.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    Offset place(PosePoint p) {
      final x = p.x / imageSize.width * size.width;
      return Offset(mirrored ? size.width - x : x,
          p.y / imageSize.height * size.height);
    }

    for (final (a, b) in _bones) {
      final pa = pose[a];
      final pb = pose[b];
      if (pa == null || pb == null) continue;
      canvas.drawLine(place(pa), place(pb), paint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.pose != pose || old.imageSize != imageSize;
}
