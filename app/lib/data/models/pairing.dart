import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';

final class PairingSession {
  const PairingSession({
    required this.code,
    required this.createdAt,
    required this.expiresAt,
  });

  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;
}

final class PairingRequest {
  PairingRequest({
    required this.deviceName,
    required this.role,
    required this.keyKind,
    required this.codeUsed,
    required List<String> fingerprintWords,
    required this.link,
  }) : fingerprintWords = List<String>.unmodifiable(fingerprintWords);

  final String deviceName;
  final DeviceRole role;
  final HardwareKeyKind keyKind;
  final String codeUsed;
  final List<String> fingerprintWords;
  final RunnerLink? link;
}

final class WaitingJoin {
  WaitingJoin({required this.code, required List<String> fingerprintWords})
    : fingerprintWords = List<String>.unmodifiable(fingerprintWords);

  final String code;
  final List<String> fingerprintWords;
}

final class PairingOutcome {
  PairingOutcome({
    required this.deviceName,
    required this.role,
    required List<String> workspaceNames,
    required List<String> runnerLabels,
    required this.approverName,
  }) : workspaceNames = List<String>.unmodifiable(workspaceNames),
       runnerLabels = List<String>.unmodifiable(runnerLabels);

  final String deviceName;
  final DeviceRole role;
  final List<String> workspaceNames;
  final List<String> runnerLabels;
  final String? approverName;
}

final class PairingInvitation {
  const PairingInvitation({required this.code, required this.serverAddress});

  final String code;
  final String serverAddress;
}
