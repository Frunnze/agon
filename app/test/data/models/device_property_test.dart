import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestByte = 256;
const int _signingKeyFieldIndex = 5;
const int _sealingKeyFieldIndex = 6;
const int _workspacesFieldIndex = 7;
const int _revokedFieldIndex = 11;

ModelFieldValues _randomDeviceFields(Random random) {
  return <Object?>[
    randomDeviceId(random),
    randomHostileText(random),
    pickOne(random, DeviceRole.values),
    pickOne(random, DeviceKind.values),
    pickOne(random, HardwareKeyKind.values),
    randomBytes(random),
    randomBytes(random),
    randomWorkspaceIds(random),
    randomPreciseMoment(random),
    if (random.nextBool()) null else randomDeviceId(random),
    randomPreciseMoment(random),
    random.nextBool(),
  ];
}

Device _buildDevice(ModelFieldValues fieldValues) {
  return Device(
    id: fieldValues[0]! as DeviceId,
    name: fieldValues[1]! as String,
    role: fieldValues[2]! as DeviceRole,
    kind: fieldValues[3]! as DeviceKind,
    keyKind: fieldValues[4]! as HardwareKeyKind,
    signingPublicKey: fieldValues[_signingKeyFieldIndex]! as List<int>,
    sealingPublicKey: fieldValues[_sealingKeyFieldIndex]! as List<int>,
    workspaces: fieldValues[_workspacesFieldIndex]! as List<WorkspaceId>,
    pairedAt: fieldValues[8]! as DateTime,
    approvedBy: fieldValues[9] as DeviceId?,
    lastSeen: fieldValues[10]! as DateTime,
    revoked: fieldValues[_revokedFieldIndex]! as bool,
  );
}

ModelFieldValues _readDeviceFields(Device device) {
  return <Object?>[
    device.id,
    device.name,
    device.role,
    device.kind,
    device.keyKind,
    device.signingPublicKey,
    device.sealingPublicKey,
    device.workspaces,
    device.pairedAt,
    device.approvedBy,
    device.lastSeen,
    device.revoked,
  ];
}

ModelFieldValues _readDeviceFieldsBesides(Device device, int skippedIndex) {
  final ModelFieldValues allFields = _readDeviceFields(device);
  final ModelFieldValues keptFields = <Object?>[];
  for (int i = 0; i < allFields.length; i += 1) {
    if (i != skippedIndex) {
      keptFields.add(allFields[i]);
    }
  }
  return keptFields;
}

Device _randomDevice(Random random) =>
    _buildDevice(_randomDeviceFields(random));

Device _deviceWithList(Random random, int listIndex, List<Object?> list) {
  final ModelFieldValues fieldValues = _randomDeviceFields(random);
  return _buildDevice(<Object?>[
    for (int i = 0; i < fieldValues.length; i += 1)
      if (i == listIndex) list else fieldValues[i],
  ]);
}

void main() {
  testEnumLabelProperties<DeviceRole>(
    testNamePrefix: 'test_device_role_label_property',
    choices: DeviceRole.values,
    readLabel: (DeviceRole role) => role.label,
  );

  testEnumLabelProperties<DeviceKind>(
    testNamePrefix: 'test_device_kind_label_property',
    choices: DeviceKind.values,
    readLabel: (DeviceKind kind) => kind.label,
  );

  testEnumLabelProperties<HardwareKeyKind>(
    testNamePrefix: 'test_hardware_key_kind_label_property',
    choices: HardwareKeyKind.values,
    readLabel: (HardwareKeyKind kind) => kind.label,
  );

  const NodeEnumMapping<DeviceRole, node.DeviceRole> roleMapping =
      NodeEnumMapping<DeviceRole, node.DeviceRole>(
        testNamePrefix: 'test_device_role_values_property',
        choices: DeviceRole.values,
        nodeChoices: node.DeviceRole.values,
        mapFromNode: mapDeviceRoleFromNode,
      );
  testNodeEnumMappingProperties(roleMapping);
  testNodeEnumRoundTripProperty(roleMapping, mapDeviceRoleToNode);

  testNodeEnumMappingProperties(
    const NodeEnumMapping<DeviceKind, node.DeviceKind>(
      testNamePrefix: 'test_device_kind_values_property',
      choices: DeviceKind.values,
      nodeChoices: node.DeviceKind.values,
      mapFromNode: mapDeviceKindFromNode,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<HardwareKeyKind, node.HardwareKeyKind>(
      testNamePrefix: 'test_hardware_key_kind_values_property',
      choices: HardwareKeyKind.values,
      nodeChoices: node.HardwareKeyKind.values,
      mapFromNode: mapHardwareKeyKindFromNode,
    ),
  );

  testModelConstructorProperties(
    const ModelConstructor<Device>(
      testNamePrefix: 'test_device_constructor_property',
      seed: 690601,
      randomFieldValues: _randomDeviceFields,
      construct: _buildDevice,
      readFieldValues: _readDeviceFields,
    ),
  );

  testListCopyProperties(
    ListCopy<Device, int>(
      testNamePrefix: 'test_device_constructor_property_signing_public_key',
      seed: 690611,
      buildElement: (Random random) => random.nextInt(_largestByte),
      construct: (Random random, List<int> key) =>
          _deviceWithList(random, _signingKeyFieldIndex, key),
      readList: (Device device) => device.signingPublicKey,
    ),
  );

  testListCopyProperties(
    ListCopy<Device, int>(
      testNamePrefix: 'test_device_constructor_property_sealing_public_key',
      seed: 690621,
      buildElement: (Random random) => random.nextInt(_largestByte),
      construct: (Random random, List<int> key) =>
          _deviceWithList(random, _sealingKeyFieldIndex, key),
      readList: (Device device) => device.sealingPublicKey,
    ),
  );

  testListCopyProperties(
    ListCopy<Device, WorkspaceId>(
      testNamePrefix: 'test_device_constructor_property_workspaces',
      seed: 690631,
      buildElement: randomWorkspaceId,
      construct: (Random random, List<WorkspaceId> workspaces) =>
          _deviceWithList(random, _workspacesFieldIndex, workspaces),
      readList: (Device device) => device.workspaces,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Device, List<WorkspaceId>>(
      testNamePrefix: 'test_with_workspaces_property',
      seed: 690641,
      randomModel: _randomDevice,
      randomChange: randomWorkspaceIds,
      applyChange: (Device device, List<WorkspaceId> workspaces) =>
          device.withWorkspaces(workspaces),
      readChangedField: (Device device) => device.workspaces,
      readOtherFields: (Device device) =>
          _readDeviceFieldsBesides(device, _workspacesFieldIndex),
    ),
  );

  testModelCopyProperties(
    ModelCopy<Device, bool>(
      testNamePrefix: 'test_as_revoked_property',
      seed: 690651,
      randomModel: _randomDevice,
      randomChange: (Random random) => true,
      applyChange: (Device device, bool revoked) => device.asRevoked(),
      readChangedField: (Device device) => device.revoked,
      readOtherFields: (Device device) =>
          _readDeviceFieldsBesides(device, _revokedFieldIndex),
    ),
  );
}
