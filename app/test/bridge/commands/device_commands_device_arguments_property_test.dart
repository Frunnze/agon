import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';

typedef _MembershipCommandBuilder = NodeCommand<void> Function(
  WorkspaceId workspaceId,
  DeviceId deviceId,
);

const String _revokeDeviceCommandName = 'revoke_device';
const String _deviceIdField = 'device_id';
const String _workspaceIdField = 'workspace_id';
const int _collidingIdentifierCount = 3;

String _randomCollidingText(Random random) {
  return 'identifier ${random.nextInt(_collidingIdentifierCount)}';
}

String _randomIdentifierText(Random random) {
  if (random.nextBool()) {
    return _randomCollidingText(random);
  }
  return randomHostileText(random);
}

NodeCommand<void> _buildAddDevice(WorkspaceId workspaceId, DeviceId deviceId) {
  return AddDeviceToWorkspaceCommand(
    workspaceId: workspaceId,
    deviceId: deviceId,
  );
}

NodeCommand<void> _buildRemoveDevice(
  WorkspaceId workspaceId,
  DeviceId deviceId,
) {
  return RemoveDeviceFromWorkspaceCommand(
    workspaceId: workspaceId,
    deviceId: deviceId,
  );
}

void _expectBothIdentifiersSentUnswapped(
  int seed,
  _MembershipCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final WorkspaceId workspaceId = WorkspaceId(_randomIdentifierText(random));
    final DeviceId deviceId = DeviceId(_randomIdentifierText(random));

    final JsonObject arguments = buildCommand(workspaceId, deviceId).arguments;

    expect(arguments, <String, Object?>{
      _workspaceIdField: workspaceId.value,
      _deviceIdField: deviceId.value,
    });
  }
}

void _expectArgumentsSurviveJsonText(
  int seed,
  _MembershipCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final NodeCommand<void> command = buildCommand(
      WorkspaceId(_randomIdentifierText(random)),
      DeviceId(_randomIdentifierText(random)),
    );

    final JsonObject reread = rereadCommandThroughText(command);

    expect(reread, equals(encodeNodeCommand(command)));
    expect(reread[commandNameField], command.name);
  }
}

void _expectSwappingIdentifiersSwapsArguments(
  int seed,
  _MembershipCommandBuilder buildCommand,
) {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final String firstText = _randomIdentifierText(random);
    final String secondText = _randomIdentifierText(random);

    final JsonObject arguments = buildCommand(
      WorkspaceId(firstText),
      DeviceId(secondText),
    ).arguments;
    final JsonObject swappedArguments = buildCommand(
      WorkspaceId(secondText),
      DeviceId(firstText),
    ).arguments;

    expect(swappedArguments[_workspaceIdField], arguments[_deviceIdField]);
    expect(swappedArguments[_deviceIdField], arguments[_workspaceIdField]);
    final bool isSameText = firstText == secondText;
    expect(mapEquals(arguments, swappedArguments), isSameText);
  }
}

void main() {
  test('test_revoke_device_command_arguments_property_sends_only_the'
      '_device', () {
    final Random random = seededRandom(56401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = DeviceId(_randomIdentifierText(random));

      final JsonObject arguments = RevokeDeviceCommand(deviceId: deviceId)
          .arguments;

      expect(arguments, <String, Object?>{_deviceIdField: deviceId.value});
    }
  });

  test('test_revoke_device_command_arguments_property_survives_json'
      '_text', () {
    final Random random = seededRandom(56402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RevokeDeviceCommand command = RevokeDeviceCommand(
        deviceId: DeviceId(_randomIdentifierText(random)),
      );

      final JsonObject reread = rereadCommandThroughText(command);

      expect(reread, equals(encodeNodeCommand(command)));
      expect(reread[commandNameField], _revokeDeviceCommandName);
    }
  });

  test('test_revoke_device_command_arguments_property_tells_devices'
      '_apart', () {
    final Random random = seededRandom(56403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String firstText = _randomIdentifierText(random);
      final String secondText = _randomIdentifierText(random);

      final JsonObject firstArguments = RevokeDeviceCommand(
        deviceId: DeviceId(firstText),
      ).arguments;
      final JsonObject secondArguments = RevokeDeviceCommand(
        deviceId: DeviceId(secondText),
      ).arguments;

      final bool isSameText = firstText == secondText;
      expect(mapEquals(firstArguments, secondArguments), isSameText);
    }
  });

  test('test_add_device_to_workspace_command_arguments_property_sends_both'
      '_unswapped', () {
    _expectBothIdentifiersSentUnswapped(56411, _buildAddDevice);
  });

  test('test_add_device_to_workspace_command_arguments_property_survives'
      '_json_text', () {
    _expectArgumentsSurviveJsonText(56412, _buildAddDevice);
  });

  test('test_add_device_to_workspace_command_arguments_property_swaps_with'
      '_its_identifiers', () {
    _expectSwappingIdentifiersSwapsArguments(56413, _buildAddDevice);
  });

  test('test_remove_device_from_workspace_command_arguments_property_'
      'sends_both_unswapped', () {
    _expectBothIdentifiersSentUnswapped(56421, _buildRemoveDevice);
  });

  test('test_remove_device_from_workspace_command_arguments_property_'
      'survives_json_text', () {
    _expectArgumentsSurviveJsonText(56422, _buildRemoveDevice);
  });

  test('test_remove_device_from_workspace_command_arguments_property_'
      'swaps_with_its_identifiers', () {
    _expectSwappingIdentifiersSwapsArguments(56423, _buildRemoveDevice);
  });

  test('test_remove_device_from_workspace_command_arguments_property_'
      'matches_adding_the_same_device', () {
    final Random random = seededRandom(56424);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = WorkspaceId(
        _randomIdentifierText(random),
      );
      final DeviceId deviceId = DeviceId(_randomIdentifierText(random));

      final NodeCommand<void> adding = _buildAddDevice(workspaceId, deviceId);
      final NodeCommand<void> removing = _buildRemoveDevice(
        workspaceId,
        deviceId,
      );

      expect(removing.arguments, equals(adding.arguments));
      expect(removing.name, isNot(adding.name));
    }
  });
}
