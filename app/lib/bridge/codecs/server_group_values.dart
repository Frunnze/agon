import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum ServerStanding implements WireNamed {
  active('active'),
  backup('backup');

  const ServerStanding(this.wireName);

  @override
  final String wireName;

  static ServerStanding decode(Object? json) => decodeWireName(values, json);
}

enum ThisDeviceStanding implements WireNamed {
  active('active'),
  backup('backup'),
  none('none');

  const ThisDeviceStanding(this.wireName);

  @override
  final String wireName;

  static ThisDeviceStanding decode(Object? json) {
    return decodeWireName(values, json);
  }
}

final class AppServerView implements JsonEncodable {
  const AppServerView({required this.deviceId, required this.standing});

  factory AppServerView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AppServerView(
      deviceId: readField(fields, 'device_id', decodeDeviceId),
      standing: readField(fields, 'standing', ServerStanding.decode),
    );
  }

  final DeviceId deviceId;
  final ServerStanding standing;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'device_id': deviceId.value,
      'standing': standing.wireName,
    };
  }
}

final class AppServersView implements JsonEncodable {
  AppServersView({
    required List<AppServerView> servers,
    required this.thisDevice,
    required this.canKeepBackup,
  }) : servers = List<AppServerView>.unmodifiable(servers);

  factory AppServersView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AppServersView(
      servers: readListField(fields, 'servers', AppServerView.fromJson),
      thisDevice: readField(fields, 'this_device', ThisDeviceStanding.decode),
      canKeepBackup: readField(fields, 'can_keep_backup', decodeFlag),
    );
  }

  final List<AppServerView> servers;
  final ThisDeviceStanding thisDevice;
  final bool canKeepBackup;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'servers': encodeList(servers),
      'this_device': thisDevice.wireName,
      'can_keep_backup': canKeepBackup,
    };
  }
}
