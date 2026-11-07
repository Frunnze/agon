import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class AccountSummary implements JsonEncodable {
  AccountSummary({required this.device, required List<Workspace> workspaces})
    : workspaces = List<Workspace>.unmodifiable(workspaces);

  factory AccountSummary.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return AccountSummary(
      device: readField(fields, 'device', Device.fromJson),
      workspaces: readListField(fields, 'workspaces', Workspace.fromJson),
    );
  }

  final Device device;
  final List<Workspace> workspaces;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'device': device.toJson(),
      'workspaces': encodeList(workspaces),
    };
  }
}

final class ServerHealthView implements JsonEncodable {
  const ServerHealthView({
    required this.reachable,
    required this.checkedAt,
    required this.problem,
  });

  factory ServerHealthView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ServerHealthView(
      reachable: readField(fields, 'reachable', decodeFlag),
      checkedAt: readField(fields, 'checked_at', decodeMoment),
      problem: readOptionalField(fields, 'problem', decodeText),
    );
  }

  final bool reachable;
  final DateTime checkedAt;
  final String? problem;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'reachable': reachable,
      'checked_at': encodeMoment(checkedAt),
      'problem': problem,
    };
  }
}

final class PendingJoin implements JsonEncodable {
  const PendingJoin({required this.joinId, required this.displayCode});

  factory PendingJoin.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return PendingJoin(
      joinId: readField(fields, 'join_id', decodeText),
      displayCode: readField(fields, 'display_code', decodeText),
    );
  }

  final String joinId;
  final String displayCode;

  @override
  JsonObject toJson() {
    return <String, Object?>{'join_id': joinId, 'display_code': displayCode};
  }
}

const int _endpointPublicKeyLength = 32;

List<int> _decodeEndpointPublicKey(Object? json) {
  final List<int> key = decodeList(json, decodeByte);
  if (key.length != _endpointPublicKeyLength) {
    throw FormatException(
      'expected a $_endpointPublicKeyLength byte endpoint key, '
      'found ${key.length} bytes',
    );
  }
  return key;
}

final class PeerAddress implements JsonEncodable {
  PeerAddress({
    required List<int> endpointPublicKey,
    required List<String> directAddresses,
    required this.relayUrl,
  }) : endpointPublicKey = List<int>.unmodifiable(endpointPublicKey),
       directAddresses = List<String>.unmodifiable(directAddresses);

  factory PeerAddress.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return PeerAddress(
      endpointPublicKey: readField(
        fields,
        'endpoint_public_key',
        _decodeEndpointPublicKey,
      ),
      directAddresses: readListField(fields, 'direct_addresses', decodeText),
      relayUrl: readOptionalField(fields, 'relay_url', decodeText),
    );
  }

  final List<int> endpointPublicKey;
  final List<String> directAddresses;
  final String? relayUrl;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'endpoint_public_key': endpointPublicKey,
      'direct_addresses': directAddresses,
      'relay_url': relayUrl,
    };
  }
}

final class PeerAnnouncement implements JsonEncodable {
  const PeerAnnouncement({
    required this.publishedAddress,
    required this.problem,
  });

  factory PeerAnnouncement.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return PeerAnnouncement(
      publishedAddress: readOptionalField(
        fields,
        'published_address',
        PeerAddress.fromJson,
      ),
      problem: readOptionalField(fields, 'problem', decodeText),
    );
  }

  final PeerAddress? publishedAddress;
  final String? problem;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'published_address': publishedAddress?.toJson(),
      'problem': problem,
    };
  }
}

final class StatusView implements JsonEncodable {
  const StatusView({
    required this.serverAddress,
    required this.serverReachable,
    required this.hostedServerAddress,
    required this.deviceId,
    required this.account,
    required this.pendingJoin,
    required this.peer,
    required this.rendezvousProblem,
    required this.runnerSettings,
    required this.appServers,
  });

  factory StatusView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return StatusView(
      serverAddress: readOptionalField(fields, 'server_address', decodeText),
      serverReachable: readField(fields, 'server_reachable', decodeFlag),
      hostedServerAddress: readOptionalField(
        fields,
        'hosted_server_address',
        decodeText,
      ),
      deviceId: readOptionalField(fields, 'device_id', decodeDeviceId),
      account: readOptionalField(fields, 'account', AccountSummary.fromJson),
      pendingJoin: readOptionalField(
        fields,
        'pending_join',
        PendingJoin.fromJson,
      ),
      peer: readOptionalField(fields, 'peer', PeerAnnouncement.fromJson),
      rendezvousProblem: readOptionalField(
        fields,
        'rendezvous_problem',
        decodeText,
      ),
      runnerSettings: readOptionalField(
        fields,
        'runner_settings',
        RunnerSettings.fromJson,
      ),
      appServers: readField(fields, 'app_servers', AppServersView.fromJson),
    );
  }

  final String? serverAddress;
  final bool serverReachable;
  final String? hostedServerAddress;
  final DeviceId? deviceId;
  final AccountSummary? account;
  final PendingJoin? pendingJoin;
  final PeerAnnouncement? peer;
  final String? rendezvousProblem;
  final RunnerSettings? runnerSettings;
  final AppServersView appServers;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'server_address': serverAddress,
      'server_reachable': serverReachable,
      'hosted_server_address': hostedServerAddress,
      'device_id': deviceId?.value,
      'account': account?.toJson(),
      'pending_join': pendingJoin?.toJson(),
      'peer': peer?.toJson(),
      'rendezvous_problem': rendezvousProblem,
      'runner_settings': runnerSettings?.toJson(),
      'app_servers': appServers.toJson(),
    };
  }
}
