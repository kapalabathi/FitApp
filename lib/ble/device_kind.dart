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
  unknown('Unbekannt', Icons.bluetooth);

  const DeviceKind(this.label, this.icon);

  final String label;
  final IconData icon;

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
    return unknown;
  }
}
