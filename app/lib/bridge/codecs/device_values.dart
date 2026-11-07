import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum DeviceRole implements WireNamed {
  client('client'),
  runner('runner'),
  clientAndRunner('client_and_runner');

  const DeviceRole(this.wireName);

  @override
  final String wireName;

  static DeviceRole decode(Object? json) => decodeWireName(values, json);
}

enum DeviceKind implements WireNamed {
  computer('computer'),
  phone('phone');

  const DeviceKind(this.wireName);

  @override
  final String wireName;

  static DeviceKind decode(Object? json) => decodeWireName(values, json);
}

enum HardwareKeyKind implements WireNamed {
  secureEnclave('secure_enclave'),
  tpm('tpm'),
  strongBox('strong_box'),
  software('software');

  const HardwareKeyKind(this.wireName);

  @override
  final String wireName;

  static HardwareKeyKind decode(Object? json) {
    return decodeWireName(values, json);
  }
}

enum RunnerLink implements WireNamed {
  direct('direct'),
  relay('relay'),
  localNetwork('local_network'),
  unreachable('unreachable');

  const RunnerLink(this.wireName);

  @override
  final String wireName;

  static RunnerLink decode(Object? json) => decodeWireName(values, json);
}

final class Device implements JsonEncodable {
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

  factory Device.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Device(
      id: readField(fields, 'id', decodeDeviceId),
      name: readField(fields, 'name', decodeText),
      role: readField(fields, 'role', DeviceRole.decode),
      kind: readField(fields, 'kind', DeviceKind.decode),
      keyKind: readField(fields, 'key_kind', HardwareKeyKind.decode),
      signingPublicKey: readListField(
        fields,
        'signing_public_key',
        decodeByte,
      ),
      sealingPublicKey: readListField(
        fields,
        'sealing_public_key',
        decodeByte,
      ),
      workspaces: readListField(fields, 'workspaces', decodeWorkspaceId),
      pairedAt: readField(fields, 'paired_at', decodeMoment),
      approvedBy: readOptionalField(fields, 'approved_by', decodeDeviceId),
      lastSeen: readField(fields, 'last_seen', decodeMoment),
      revoked: readField(fields, 'revoked', decodeFlag),
    );
  }

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

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'name': name,
      'role': role.wireName,
      'kind': kind.wireName,
      'key_kind': keyKind.wireName,
      'signing_public_key': signingPublicKey,
      'sealing_public_key': sealingPublicKey,
      'workspaces': workspaces,
      'paired_at': encodeMoment(pairedAt),
      'approved_by': approvedBy?.value,
      'last_seen': encodeMoment(lastSeen),
      'revoked': revoked,
    };
  }
}

final class Runner implements JsonEncodable {
  Runner({
    required this.deviceId,
    required List<String> labels,
    required this.slotsTotal,
    required this.slotsBusy,
    required this.link,
    required this.online,
    required this.acceptingNewRuns,
    required List<AgentPlace> offers,
    required List<String> allowedHosts,
  }) : labels = List<String>.unmodifiable(labels),
       offers = List<AgentPlace>.unmodifiable(offers),
       allowedHosts = List<String>.unmodifiable(allowedHosts);

  factory Runner.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Runner(
      deviceId: readField(fields, 'device_id', decodeDeviceId),
      labels: readListField(fields, 'labels', decodeText),
      slotsTotal: readField(fields, 'slots_total', decodeCount),
      slotsBusy: readField(fields, 'slots_busy', decodeCount),
      link: readField(fields, 'link', RunnerLink.decode),
      online: readField(fields, 'online', decodeFlag),
      acceptingNewRuns: readField(fields, 'accepting_new_runs', decodeFlag),
      offers: readListField(fields, 'offers', AgentPlace.decode),
      allowedHosts: readListField(fields, 'allowed_hosts', decodeText),
    );
  }

  final DeviceId deviceId;
  final List<String> labels;
  final int slotsTotal;
  final int slotsBusy;
  final RunnerLink link;
  final bool online;
  final bool acceptingNewRuns;
  final List<AgentPlace> offers;
  final List<String> allowedHosts;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'device_id': deviceId.value,
      'labels': labels,
      'slots_total': slotsTotal,
      'slots_busy': slotsBusy,
      'link': link.wireName,
      'online': online,
      'accepting_new_runs': acceptingNewRuns,
      'offers': <String>[
        for (final AgentPlace offer in offers) offer.wireName,
      ],
      'allowed_hosts': allowedHosts,
    };
  }
}

sealed class RunnerTarget implements JsonEncodable {
  const RunnerTarget();

  factory RunnerTarget.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      AnyFreeRunner.kind => const AnyFreeRunner(),
      SpecificRunner.kind => SpecificRunner(
        deviceId: readField(fields, 'device_id', decodeDeviceId),
      ),
      RunnerWithLabels.kind => RunnerWithLabels(
        labels: readListField(fields, 'labels', decodeText),
      ),
      _ => throw FormatException('unknown runner target $kind'),
    };
  }
}

final class AnyFreeRunner extends RunnerTarget {
  const AnyFreeRunner();

  static const String kind = 'any_free_runner';

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind};
}

final class SpecificRunner extends RunnerTarget {
  const SpecificRunner({required this.deviceId});

  static const String kind = 'specific_runner';

  final DeviceId deviceId;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'device_id': deviceId.value};
  }
}

final class RunnerWithLabels extends RunnerTarget {
  RunnerWithLabels({required List<String> labels})
    : labels = List<String>.unmodifiable(labels);

  static const String kind = 'runner_with_labels';

  final List<String> labels;

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind, 'labels': labels};
}
