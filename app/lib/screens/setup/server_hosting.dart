import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

const String firstWorkspaceName = 'personal';

typedef HostAppServer = Future<PairingOutcome> Function();

const Set<TargetPlatform> _computerPlatforms = <TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.linux,
  TargetPlatform.windows,
};
const List<DeviceRole> _computerRoles = <DeviceRole>[
  DeviceRole.clientAndRunner,
  DeviceRole.client,
  DeviceRole.runner,
];
const List<DeviceRole> _phoneRoles = <DeviceRole>[DeviceRole.client];

List<DeviceRole> listSetupRoles(TargetPlatform platform) {
  if (_computerPlatforms.contains(platform)) {
    return _computerRoles;
  }
  return _phoneRoles;
}

bool canHostAppServer({
  required TargetPlatform platform,
  required DeviceRole role,
}) {
  return _computerPlatforms.contains(platform) && role != DeviceRole.runner;
}
