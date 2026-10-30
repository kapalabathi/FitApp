import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_smoother.dart';
import 'rep_counter.dart';

/// Kamera samt Haltungserkennung. Die Bilder werden nur auf dem Gerät
/// ausgewertet und nirgends gespeichert.
class PoseCamera extends ChangeNotifier {
  PoseCamera({required this.onPose});

  /// Wird für jedes ausgewertete Bild mit der erkannten Haltung aufgerufen.
  final void Function(BodyPose pose, Duration at) onPose;

  static const _landmarks = {
    PoseLandmarkType.leftShoulder: Joint.leftShoulder,
    PoseLandmarkType.rightShoulder: Joint.rightShoulder,
    PoseLandmarkType.leftElbow: Joint.leftElbow,
    PoseLandmarkType.rightElbow: Joint.rightElbow,
    PoseLandmarkType.leftWrist: Joint.leftWrist,
    PoseLandmarkType.rightWrist: Joint.rightWrist,
    PoseLandmarkType.leftHip: Joint.leftHip,
    PoseLandmarkType.rightHip: Joint.rightHip,
    PoseLandmarkType.leftKnee: Joint.leftKnee,
    PoseLandmarkType.rightKnee: Joint.rightKnee,
    PoseLandmarkType.leftAnkle: Joint.leftAnkle,
    PoseLandmarkType.rightAnkle: Joint.rightAnkle,
  };

  static const _deviceTurn = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final Stopwatch _clock = Stopwatch()..start();

  CameraController? controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _camera;
  bool _busy = false;
  bool _switching = false;
  bool _disposed = false;

  /// Die beruhigte Haltung für das Gerüst über dem Bild.
  BodyPose pose = const {};
  final PoseSmoother _smoother = PoseSmoother();

  /// Größe des aufrecht gedrehten Bildes, auf das sich [pose] bezieht.
  Size imageSize = Size.zero;

  /// Die Meldung, wenn die Kamera nicht zur Verfügung steht.
  String? error;

  CameraLensDirection get lens =>
      _camera?.lensDirection ?? CameraLensDirection.back;

  bool get canSwitch =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
      _cameras.any((c) => c.lensDirection == CameraLensDirection.back);

  /// Startet die Kamera mit Blick nach [lens], soweit vorhanden.
  Future<void> start(CameraLensDirection lens) async {
    try {
      _cameras = await availableCameras();
      await _open(lens);
    } catch (e) {
      error = _message(e);
      notifyListeners();
    }
  }

  /// Wechselt zwischen Front- und Rückkamera; der Zähler läuft weiter.
  Future<void> switchCamera() async {
    if (_switching || !canSwitch) return;
    _switching = true;
    final next = lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    try {
      await _close();
      await _open(next);
    } catch (e) {
      error = _message(e);
    }
    _switching = false;
    notifyListeners();
  }

  String _message(Object e) =>
      e is CameraException && e.code.contains('Access')
          ? 'Die App darf die Kamera nicht nutzen. Du kannst trotzdem von '
              'Hand zählen.'
          : 'Kamera nicht verfügbar: $e';

  Future<void> _open(CameraLensDirection wanted) async {
    if (_cameras.isEmpty) {
      error = 'Dieses Gerät hat keine Kamera. Du kannst von Hand zählen.';
      notifyListeners();
      return;
    }
    final camera = _cameras.firstWhere((c) => c.lensDirection == wanted,
        orElse: () => _cameras.first);
    final c = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await c.initialize();
    if (_disposed) {
      await c.dispose();
      return;
    }
    _camera = camera;
    controller = c;
    error = null;
    pose = const {};
    _smoother.reset();
    await c.startImageStream(_onImage);
    notifyListeners();
  }

  Future<void> _close() async {
    final c = controller;
    controller = null;
    notifyListeners();
    if (c == null) return;
    try {
      await c.stopImageStream();
    } catch (_) {
      // War schon gestoppt.
    }
    await c.dispose();
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy || _disposed) return;
    final input = _toInput(image);
    if (input == null) return;
    _busy = true;
    try {
      final found = await _detector.processImage(input);
      if (_disposed) return;
      final rotated = input.metadata!.rotation.rawValue % 180 != 0;
      imageSize = rotated
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());
      final BodyPose raw = found.isEmpty
          ? const {}
          : {
              for (final e in _landmarks.entries)
                if (found.first.landmarks[e.key] case final l?)
                  e.value: PosePoint(l.x, l.y, l.likelihood),
            };
      final at = _clock.elapsed;
      pose = _smoother.update(raw, at, imageSize.longestSide);
      onPose(raw, at);
      notifyListeners();
    } catch (_) {
      // Ein einzelnes unlesbares Bild darf das Training nicht stören.
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInput(CameraImage image) {
    final c = controller;
    final camera = _camera;
    if (c == null || camera == null) return null;
    final turn = _deviceTurn[c.value.deviceOrientation] ?? 0;
    final sensor = camera.sensorOrientation;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (sensor + turn) % 360
        : (sensor - turn + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    if (rotation == null) return null;
    final bytes = image.planes.length == 1
        ? image.planes.first.bytes
        : _join(image.planes);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static Uint8List _join(List<Plane> planes) {
    final out = BytesBuilder(copy: false);
    for (final p in planes) {
      out.add(p.bytes);
    }
    return out.toBytes();
  }

  @override
  void dispose() {
    _disposed = true;
    _close();
    _detector.close();
    super.dispose();
  }
}
