import 'package:flutter/material.dart';

import 'uuids.dart';

/// Geräteart, soweit sie sich aus Name und beworbenen Diensten ablesen lässt.
enum DeviceKind {
  heartRate('Pulssensor', Icons.favorite),
  fitnessMachine('Fitnessgerät', Icons.fitness_center),
  concept2('Concept2', Icons.rowing),
  power('Leistungsmesser', Icons.bolt),
  cadence('Tritt-/Geschwindigkeitssensor', Icons.speed),
  footPod('Laufsensor', Icons.directions_run),

  /// Der Name klingt nach einem Fitnessgerät, die Suche zeigt aber keinen
  /// bekannten Dienst. Ob es passt, klärt erst das Verbinden.
  likelyMachine('Vermutlich Fitnessgerät', Icons.fitness_center),
  unknown('Unbekannt', Icons.bluetooth);

  const DeviceKind(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Hersteller und Wörter, die in den Namen von Fitnessgeräten vorkommen.
  static final _machineName = RegExp(
    r'technogym|matrix|precor|life ?fitness|cybex|peloton|bowflex|nautilus|'
    r'schwinn|keiser|wahoo|kickr|tacx|echelon|nordictrack|proform|'
    r'kettler|domyos|decathlon|skandika|sportstech|toorx|waterrower|hydrow|'
    r'star ?trac|true ?fitness|tunturi|yesoul|merach|horizon|'
    r'\b(ftms|treadmill|tread|bike|rower|row|elliptical|crosstrainer|'
    r'laufband|ergometer|erg|spin)\b',
    caseSensitive: false,
  );

  static DeviceKind detect(String? name, Iterable<String> services) {
    if (Uuids.contains(services, Uuids.pm5Service) ||
        (name ?? '').startsWith('PM5')) {
      return concept2;
    }
    if (Uuids.contains(services, Uuids.ftmsService)) return fitnessMachine;
    if (Uuids.contains(services, Uuids.heartRateService)) return heartRate;
    if (Uuids.contains(services, Uuids.cyclingPowerService)) return power;
    if (Uuids.contains(services, Uuids.cyclingSpeedCadenceService)) {
      return cadence;
    }
    if (Uuids.contains(services, Uuids.runningSpeedCadenceService)) {
      return footPod;
    }
    if (_machineName.hasMatch(name ?? '')) return likelyMachine;
    return unknown;
  }
}
