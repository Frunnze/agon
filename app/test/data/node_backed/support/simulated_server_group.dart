import 'simulated_node_replies.dart';

const String simulatedActiveServerId = 'simulated-active-server';
const String simulatedActiveServerMessage =
    'this device is the active app server';
const String simulatedNoGroupMessage = 'the app server keeps no backups';
const String simulatedNotClientMessage =
    'only a client device can keep a backup of the app server';
const String simulatedAlreadyHostingMessage =
    'this device already keeps the app server';
const String _activeStanding = 'active';
const String _backupStanding = 'backup';
const String _noStanding = 'none';
const String _deviceIdField = 'device_id';
const String _standingField = 'standing';

Map<String, Object?> describeStandaloneServer() {
  return <String, Object?>{
    'servers': <Object?>[],
    'this_device': _noStanding,
    'can_keep_backup': false,
  };
}

final class SimulatedServerGroup {
  SimulatedServerGroup({required this.thisDeviceId});

  final String thisDeviceId;
  final List<Map<String, Object?>> servers = <Map<String, Object?>>[];
  String thisDeviceStanding = _noStanding;
  bool canKeepBackup = false;

  void foundGroup() {
    servers.add(<String, Object?>{
      _deviceIdField: simulatedActiveServerId,
      _standingField: _activeStanding,
    });
  }

  void makeThisDeviceActive() {
    servers.add(<String, Object?>{
      _deviceIdField: thisDeviceId,
      _standingField: _activeStanding,
    });
    thisDeviceStanding = _activeStanding;
  }

  Map<String, Object?> describe() {
    return <String, Object?>{
      'servers': <Object?>[...servers],
      'this_device': thisDeviceStanding,
      'can_keep_backup': canKeepBackup,
    };
  }

  Object? startBackup(SimulatedCommand command) {
    if (!canKeepBackup) {
      throw const SimulatedNodeFailure(simulatedNotClientMessage);
    }
    if (servers.isEmpty) {
      throw const SimulatedNodeFailure(simulatedNoGroupMessage);
    }
    if (thisDeviceStanding != _noStanding) {
      throw const SimulatedNodeFailure(simulatedAlreadyHostingMessage);
    }

    servers.add(<String, Object?>{
      _deviceIdField: thisDeviceId,
      _standingField: _backupStanding,
    });
    thisDeviceStanding = _backupStanding;
    return describe();
  }

  Object? stopBackup(SimulatedCommand command) {
    if (thisDeviceStanding == _activeStanding) {
      throw const SimulatedNodeFailure(simulatedActiveServerMessage);
    }

    servers.removeWhere(
      (Map<String, Object?> server) => server[_deviceIdField] == thisDeviceId,
    );
    thisDeviceStanding = _noStanding;
    return describe();
  }
}
