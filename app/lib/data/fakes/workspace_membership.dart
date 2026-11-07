import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';

const String outsiderDeviceProblem = 'the device is not in that workspace';
const int _forbiddenStatus = 403;

void refuseDeviceOutsideWorkspace(
  DeviceRepository deviceRepository,
  WorkspaceId workspaceId,
) {
  final Device device = deviceRepository.currentDevice();
  if (!device.workspaces.contains(workspaceId)) {
    throw AppServerRefusal(
      status: _forbiddenStatus,
      reason: outsiderDeviceProblem,
    );
  }
}
