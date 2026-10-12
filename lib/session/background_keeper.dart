import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Hält die App während eines Trainings mit Bluetooth-Geräten am Leben, auch
/// bei gesperrtem Display oder wenn eine andere App im Vordergrund ist.
///
/// Android legt Apps im Hintergrund schlafen; dann kämen keine Messwerte mehr
/// an und der Timer bliebe stehen. Ein Vordergrunddienst mit dauerhafter
/// Benachrichtigung verhindert das. Aufzeichnungen im Freien brauchen ihn
/// nicht: Dort hält der Dienst des GPS die App wach.
abstract final class BackgroundKeeper {
  static const _serviceId = 4711;
  static bool _initialized = false;
  static bool _running = false;

  /// Startet den Dienst. Schlägt das fehl, läuft das Training trotzdem; es
  /// ist dann nur nicht vor dem Schlafenlegen geschützt.
  static Future<void> start(String title) async {
    try {
      if (!_initialized) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'aufzeichnung',
            channelName: 'Aufzeichnung',
            channelDescription:
                'Zeigt an, dass ein Training aufgezeichnet wird.',
          ),
          iosNotificationOptions: const IOSNotificationOptions(),
          foregroundTaskOptions: ForegroundTaskOptions(
            // Die App erledigt die Arbeit selbst; der Dienst soll sie nur
            // wach halten.
            eventAction: ForegroundTaskEventAction.nothing(),
            allowAutoRestart: false,
          ),
        );
        _initialized = true;
      }
      if (await FlutterForegroundTask.checkNotificationPermission() !=
          NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        notificationTitle: 'FitApp zeichnet auf',
        notificationText: title,
      );
      _running = result is ServiceRequestSuccess;
    } catch (_) {
      _running = false;
    }
  }

  static Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Der Dienst war schon beendet.
    }
  }
}
