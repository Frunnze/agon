import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

abstract interface class DeviceRepository implements Listenable {
  List<Device> listDevices();

  Device findDevice(DeviceId deviceId);

  Device currentDevice();

  String? findPeerAddressProblem();

  Future<CheckedFolder> checkLocalFolder(String path);

  Future<CheckedFolder> createLocalFolder({
    required String parent,
    required String name,
  });

  Future<Device> revokeDevice(DeviceId deviceId);

  Future<Device> addDeviceToWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  );

  Future<Device> removeDeviceFromWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  );
}
