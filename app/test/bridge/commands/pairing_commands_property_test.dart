import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/fieldless_command_properties.dart';
import 'support/pairing_command_rows.dart';

const int _fieldSeed = 5917400;
const int _fieldlessSeed = 5917500;
const int _firstSeed = 5917600;
const String _workspaceIdsField = 'workspace_ids';
const String _serverAddressField = 'server_address';
const String _roleField = 'role';

List<WorkspaceId> _randomWorkspaceIdsWithOne(Random random) {
  return <WorkspaceId>[
    WorkspaceId(randomArgumentText(random)),
    ...randomHostileWorkspaceIds(random),
  ];
}

void main() {
  testModelledCommandRows(pairingFieldCommandRows, _fieldSeed);
  testFieldlessCommandRows(pairingFieldlessCommandRows, _fieldlessSeed);

  test('test_approve_pairing_command_constructor_property_'
      'ignores_later_changes_to_the_given_ids', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> givenIds = _randomWorkspaceIdsWithOne(random);
      final ApprovePairingCommand command = ApprovePairingCommand(
        code: randomArgumentText(random),
        workspaceIds: givenIds,
      );
      final Object? sentIdsBefore = rereadThroughWire(
        command.arguments[_workspaceIdsField],
      );

      expectListIgnoresCallerChanges(
        givenIds,
        command.workspaceIds,
        WorkspaceId(randomArgumentText(random)),
      );
      expect(
        rereadThroughWire(command.arguments[_workspaceIdsField]),
        equals(sentIdsBefore),
      );
    }
  });

  test('test_approve_pairing_command_constructor_property_'
      'kept_ids_refuse_changes', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovePairingCommand command = ApprovePairingCommand(
        code: randomArgumentText(random),
        workspaceIds: randomHostileWorkspaceIds(random),
      );
      final WorkspaceId extraId = WorkspaceId(randomArgumentText(random));
      final List<Object?> sentIds =
          command.arguments[_workspaceIdsField]! as List<Object?>;

      expectListRefusesChanges(command.workspaceIds, extraId);
      expect(() => sentIds.add(extraId), throwsUnsupportedError);
    }
  });

  test('test_approve_pairing_command_arguments_property_'
      'keeps_the_order_and_repeats_of_ids', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> givenIds = _randomWorkspaceIdsWithOne(random);
      final List<WorkspaceId> repeatedIds = <WorkspaceId>[
        ...givenIds,
        ...givenIds.reversed,
      ];
      final ApprovePairingCommand command = ApprovePairingCommand(
        code: randomArgumentText(random),
        workspaceIds: repeatedIds,
      );
      final Object? sentIds = rereadThroughWire(
        command.arguments[_workspaceIdsField],
      );

      expect(sentIds, hasLength(repeatedIds.length));
      expect(sentIds, orderedEquals(repeatedIds));
    }
  });

  test('test_join_with_code_command_arguments_property_'
      'role_reads_back_as_the_given_role', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = buildJoinWithCodeCommand(random);
      final JoinWithCodeCommand command =
          modelled.command as JoinWithCodeCommand;
      final JsonObject wireCommand = decodeObject(
        rereadThroughWire(encodeNodeCommand(command)),
      );

      expect(DeviceRole.decode(wireCommand[_roleField]), command.role);
    }
  });

  test('test_join_with_code_command_arguments_property_'
      'no_address_reads_as_no_address', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinWithCodeCommand command = JoinWithCodeCommand(
        serverAddress: null,
        code: randomArgumentText(random),
        deviceName: randomArgumentText(random),
        role: pickOne(random, DeviceRole.values),
      );
      final JsonObject wireCommand = decodeObject(
        rereadThroughWire(encodeNodeCommand(command)),
      );

      expect(wireCommand[_serverAddressField], isNull);
      expect(wireCommand['code'], command.code);
      expect(wireCommand['device_name'], command.deviceName);
    }
  });
}
