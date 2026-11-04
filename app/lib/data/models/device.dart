import 'package:agent_orchestration/data/models/identifiers.dart';

enum DeviceRole {
  client('Client'),
  runner('Runner'),
  clientAndRunner('Client and runner');

  const DeviceRole(this.label);

  final String label;
}

enum DeviceKind {
  computer('Computer'),
  phone('Phone');

  const DeviceKind(this.label);

  final String label;
}

enum HardwareKeyKind {
  secureEnclave('Secure Enclave'),
  tpm('TPM 2.0'),
  strongBox('StrongBox'),
  software('Software key');

  const HardwareKeyKind(this.label);

  final String label;
}

final class Device {
  Device({
    required this.id,
    required this.name,
    required this.role,
    required this.kind,
    required this.keyKind,
    required List<int> signingPublicKey,
    required List<int> sealingPublicKey,
    required List<WorkspaceId> workspaces,
    required this.pairedAt,
    required this.approvedBy,
    required this.lastSeen,
    required this.revoked,
  }) : signingPublicKey = List<int>.unmodifiable(signingPublicKey),
       sealingPublicKey = List<int>.unmodifiable(sealingPublicKey),
       workspaces = List<WorkspaceId>.unmodifiable(workspaces);

  final DeviceId id;
  final String name;
  final DeviceRole role;
  final DeviceKind kind;
  final HardwareKeyKind keyKind;
  final List<int> signingPublicKey;
  final List<int> sealingPublicKey;
  final List<WorkspaceId> workspaces;
  final DateTime pairedAt;
  final DeviceId? approvedBy;
  final DateTime lastSeen;
  final bool revoked;

  Device withWorkspaces(List<WorkspaceId> nextWorkspaces) {
    return Device(
      id: id,
      name: name,
      role: role,
      kind: kind,
      keyKind: keyKind,
      signingPublicKey: signingPublicKey,
      sealingPublicKey: sealingPublicKey,
      workspaces: nextWorkspaces,
      pairedAt: pairedAt,
      approvedBy: approvedBy,
      lastSeen: lastSeen,
      revoked: revoked,
    );
  }

  Device asRevoked() {
    return Device(
      id: id,
      name: name,
      role: role,
      kind: kind,
      keyKind: keyKind,
      signingPublicKey: signingPublicKey,
      sealingPublicKey: sealingPublicKey,
      workspaces: workspaces,
      pairedAt: pairedAt,
      approvedBy: approvedBy,
      lastSeen: lastSeen,
      revoked: true,
    );
  }
}
