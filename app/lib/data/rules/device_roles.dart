import 'package:agent_orchestration/data/models/device.dart';

bool roleRunsTasks(DeviceRole role) {
  switch (role) {
    case DeviceRole.client:
      return false;
    case DeviceRole.runner:
    case DeviceRole.clientAndRunner:
      return true;
  }
}
