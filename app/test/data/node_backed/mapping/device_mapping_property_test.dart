import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../bridge/support/random_devices.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';
import '../support/node_enum_mapping_properties.dart';

node.Device _decodeRandomDevice(Random random) {
  return node.Device.fromJson(randomDeviceJson(random));
}

Map<String, Object?> _writeDeviceAsNodeJson(Device device) {
  return <String, Object?>{
    'id': device.id.value,
    'name': device.name,
    'role': mapDeviceRoleToNode(device.role).wireName,
    'kind': node.DeviceKind.values.byName(device.kind.name).wireName,
    'key_kind': node.HardwareKeyKind.values
        .byName(device.keyKind.name)
        .wireName,
    'signing_public_key': device.signingPublicKey,
    'sealing_public_key': device.sealingPublicKey,
    'workspaces': <String>[
      for (final WorkspaceId workspace in device.workspaces) workspace.value,
    ],
    'paired_at': encodeMoment(device.pairedAt),
    'approved_by': device.approvedBy?.value,
    'last_seen': encodeMoment(device.lastSeen),
    'revoked': device.revoked,
  };
}

void main() {
  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.DeviceRole, DeviceRole>(
      functionName: 'map_device_role_from_node',
      seed: 71101,
      rustWireNames: nodeDeviceRoles,
      decodeNode: node.DeviceRole.decode,
      modelValues: DeviceRole.values,
      mapFromNode: mapDeviceRoleFromNode,
    ),
  );

  testEnumMappingToNodeProperties(
    const EnumMappingToNode<node.DeviceRole, DeviceRole>(
      functionName: 'map_device_role_to_node',
      rustWireNames: nodeDeviceRoles,
      nodeValues: node.DeviceRole.values,
      modelValues: DeviceRole.values,
      mapToNode: mapDeviceRoleToNode,
      mapFromNode: mapDeviceRoleFromNode,
    ),
  );

  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.DeviceKind, DeviceKind>(
      functionName: 'map_device_kind_from_node',
      seed: 71103,
      rustWireNames: nodeDeviceKinds,
      decodeNode: node.DeviceKind.decode,
      modelValues: DeviceKind.values,
      mapFromNode: mapDeviceKindFromNode,
    ),
  );

  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.HardwareKeyKind, HardwareKeyKind>(
      functionName: 'map_hardware_key_kind_from_node',
      seed: 71105,
      rustWireNames: nodeHardwareKeyKinds,
      decodeNode: node.HardwareKeyKind.decode,
      modelValues: HardwareKeyKind.values,
      mapFromNode: mapHardwareKeyKindFromNode,
    ),
  );

  test('test_map_device_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(71107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Device wire = randomDevice(random);

      final Device device = mapDeviceFromNode(wire);

      expect(device.id, wire.id);
      expect(device.name, wire.name);
      expect(device.role, mapDeviceRoleFromNode(wire.role));
      expect(device.kind, mapDeviceKindFromNode(wire.kind));
      expect(device.keyKind, mapHardwareKeyKindFromNode(wire.keyKind));
      expect(device.signingPublicKey, orderedEquals(wire.signingPublicKey));
      expect(device.sealingPublicKey, orderedEquals(wire.sealingPublicKey));
      expect(device.workspaces, orderedEquals(wire.workspaces));
      expect(device.pairedAt, wire.pairedAt);
      expect(device.approvedBy, wire.approvedBy);
      expect(device.lastSeen, wire.lastSeen);
      expect(device.revoked, wire.revoked);
    }
  });

  test('test_map_device_from_node_property_writes_back_the_node_json', () {
    final Random random = seededRandom(71108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Device wire = _decodeRandomDevice(random);

      final Device device = mapDeviceFromNode(wire);

      expect(
        jsonEncode(_writeDeviceAsNodeJson(device)),
        jsonEncode(wire.toJson()),
      );
    }
  });

  test('test_map_device_from_node_property_keeps_the_instant_of_offsets', () {
    final Random random = seededRandom(71109);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> deviceJson = randomDeviceJson(random);
      final DateTime pairedAt = randomPreciseMoment(random);
      final DateTime lastSeen = randomPreciseMoment(random);
      deviceJson['paired_at'] = writeMomentWithRandomOffset(random, pairedAt);
      deviceJson['last_seen'] = writeMomentWithRandomOffset(random, lastSeen);

      final Device device = mapDeviceFromNode(
        node.Device.fromJson(deviceJson),
      );

      expect(device.pairedAt.isAtSameMomentAs(pairedAt), isTrue);
      expect(device.lastSeen.isAtSameMomentAs(lastSeen), isTrue);
    }
  });

  test('test_map_device_from_node_property_gives_lists_nobody_can_change', () {
    final Random random = seededRandom(71110);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = mapDeviceFromNode(randomDevice(random));

      expect(() => device.signingPublicKey.add(0), throwsUnsupportedError);
      expect(() => device.sealingPublicKey.add(0), throwsUnsupportedError);
      expect(
        () => device.workspaces.add(const WorkspaceId('another')),
        throwsUnsupportedError,
      );
    }
  });
}
