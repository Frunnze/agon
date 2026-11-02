import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

final class DeviceNames {
  DeviceNames(List<Device> devices)
    : _namesById = <DeviceId, String>{
        for (final Device device in devices) device.id: device.name,
      };

  final Map<DeviceId, String> _namesById;

  String? findName(DeviceId deviceId) => _namesById[deviceId];

  String nameOf(DeviceId deviceId) {
    final String? name = findName(deviceId);
    if (name == null) {
      throw RecordNotFound(kind: 'device', identifier: deviceId.value);
    }
    return name;
  }

  String describeDevice(DeviceId deviceId) {
    final String? name = findName(deviceId);
    if (name == null) {
      return shortenIdentifier(deviceId.value);
    }
    return name;
  }
}
