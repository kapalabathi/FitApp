/// Bluetooth-Kennungen der unterstützten Profile.
///
/// Kurze Kennungen (4 Stellen) stammen aus dem Bluetooth-Standard,
/// lange sind herstellereigen.
abstract final class Uuids {
  // Dienste
  static const heartRateService = '180d';
  static const ftmsService = '1826';
  static const cyclingPowerService = '1818';
  static const cyclingSpeedCadenceService = '1816';
  static const runningSpeedCadenceService = '1814';
  static const deviceInformationService = '180a';
  static const batteryService = '180f';
  static const pm5Service = 'ce060000-43e5-11e4-916c-0800200c9a66';

  // Herzfrequenz
  static const heartRateMeasurement = '2a37';

  // Fitnessgeräte (FTMS)
  static const ftmsFeature = '2acc';
  static const treadmillData = '2acd';
  static const crossTrainerData = '2ace';
  static const rowerData = '2ad1';
  static const indoorBikeData = '2ad2';
  static const supportedSpeedRange = '2ad4';
  static const supportedInclinationRange = '2ad5';
  static const supportedResistanceRange = '2ad6';
  static const supportedPowerRange = '2ad8';
  static const ftmsControlPoint = '2ad9';
  static const ftmsStatus = '2ada';

  /// Bringt eine Kennung in die lange, kleingeschriebene Form.
  static String full(String uuid) {
    final u = uuid.toLowerCase();
    if (u.length == 4) return '0000$u-0000-1000-8000-00805f9b34fb';
    if (u.length == 8) return '$u-0000-1000-8000-00805f9b34fb';
    return u;
  }

  static bool same(String a, String b) => full(a) == full(b);

  static bool contains(Iterable<String> uuids, String uuid) =>
      uuids.any((u) => same(u, uuid));

  /// Lesbarer Name für bekannte Dienste und Merkmale, sonst `null`.
  static String? label(String uuid) => _labels[full(uuid)];

  static final Map<String, String> _labels = {
    for (final e in const {
      heartRateService: 'Herzfrequenz',
      ftmsService: 'Fitnessgerät (FTMS)',
      cyclingPowerService: 'Leistungsmesser',
      cyclingSpeedCadenceService: 'Tritt-/Geschwindigkeitssensor',
      runningSpeedCadenceService: 'Laufsensor',
      deviceInformationService: 'Geräteinformation',
      batteryService: 'Batterie',
      pm5Service: 'Concept2 PM5',
      heartRateMeasurement: 'Herzfrequenz-Messwert',
      ftmsFeature: 'FTMS-Fähigkeiten',
      treadmillData: 'Laufband-Daten',
      crossTrainerData: 'Crosstrainer-Daten',
      rowerData: 'Rudergerät-Daten',
      indoorBikeData: 'Indoor-Bike-Daten',
      supportedSpeedRange: 'Geschwindigkeitsbereich',
      supportedInclinationRange: 'Steigungsbereich',
      supportedResistanceRange: 'Widerstandsbereich',
      supportedPowerRange: 'Leistungsbereich',
      ftmsControlPoint: 'FTMS-Steuerung',
      ftmsStatus: 'FTMS-Status',
    }.entries)
      full(e.key): e.value,
  };
}
