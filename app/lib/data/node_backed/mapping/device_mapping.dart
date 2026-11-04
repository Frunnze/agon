import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';

DeviceRole mapDeviceRoleFromNode(node.DeviceRole role) {
  return switch (role) {
    node.DeviceRole.client => DeviceRole.client,
    node.DeviceRole.runner => DeviceRole.runner,
    node.DeviceRole.clientAndRunner => DeviceRole.clientAndRunner,
  };
}

node.DeviceRole mapDeviceRoleToNode(DeviceRole role) {
  return switch (role) {
    DeviceRole.client => node.DeviceRole.client,
    DeviceRole.runner => node.DeviceRole.runner,
    DeviceRole.clientAndRunner => node.DeviceRole.clientAndRunner,
  };
}

DeviceKind mapDeviceKindFromNode(node.DeviceKind kind) {
  return switch (kind) {
    node.DeviceKind.computer => DeviceKind.computer,
    node.DeviceKind.phone => DeviceKind.phone,
  };
}

HardwareKeyKind mapHardwareKeyKindFromNode(node.HardwareKeyKind kind) {
  return switch (kind) {
    node.HardwareKeyKind.secureEnclave => HardwareKeyKind.secureEnclave,
    node.HardwareKeyKind.tpm => HardwareKeyKind.tpm,
    node.HardwareKeyKind.strongBox => HardwareKeyKind.strongBox,
    node.HardwareKeyKind.software => HardwareKeyKind.software,
  };
}

Device mapDeviceFromNode(node.Device device) {
  return Device(
    id: device.id,
    name: device.name,
    role: mapDeviceRoleFromNode(device.role),
    kind: mapDeviceKindFromNode(device.kind),
    keyKind: mapHardwareKeyKindFromNode(device.keyKind),
    signingPublicKey: device.signingPublicKey,
    sealingPublicKey: device.sealingPublicKey,
    workspaces: device.workspaces,
    pairedAt: device.pairedAt,
    approvedBy: device.approvedBy,
    lastSeen: device.lastSeen,
    revoked: device.revoked,
  );
}
