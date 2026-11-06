import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/approval_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/node_wire_names.dart';
import '../support/random_run_json.dart';
import '../support/simple_command_properties.dart';

const int _decideReplySeed = 86000;
const int _createFieldsSeed = 86010;
const int _createActionSeed = 86020;
const int _createCollisionSeed = 86030;
const int _decideFieldsSeed = 86040;
const int _decideCollisionSeed = 86050;

void main() {
  testNothingReplyProperties(
    typeName: 'decide_approval_command',
    seed: _decideReplySeed,
    buildCommand: _randomDecideApproval,
  );

  test('test_create_approval_command_arguments_property_run_and_action', () {
    final Random random = seededRandom(_createFieldsSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CreateApprovalCommand command = _randomCreateApproval(random);
      final JsonObject arguments = command.arguments;

      expect(arguments.keys.toSet(), equals(<String>{'run_id', 'action'}));
      expect(arguments['run_id'], command.runId?.value);
    }
  });

  test(
    'test_create_approval_command_arguments_property_action_reads_back',
    () {
      final Random random = seededRandom(_createActionSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CreateApprovalCommand command = _randomCreateApproval(random);
        final String wireText = jsonEncode(command.arguments);
        final JsonObject rereadArguments = decodeObject(jsonDecode(wireText));
        final ApprovalAction rereadAction = ApprovalAction.fromJson(
          rereadArguments['action'],
        );

        expect(rereadAction.toJson(), equals(command.action.toJson()));
      }
    },
  );

  test(
    'test_create_approval_command_arguments_property_runs_never_collide',
    () {
      final Random random = seededRandom(_createCollisionSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ApprovalAction action = _randomApprovalAction(random);
        final RunId? firstRunId = _randomNearbyRunId(random);
        final RunId? secondRunId = _randomNearbyRunId(random);
        final String firstWireText = jsonEncode(
          CreateApprovalCommand(runId: firstRunId, action: action).arguments,
        );
        final String secondWireText = jsonEncode(
          CreateApprovalCommand(runId: secondRunId, action: action).arguments,
        );

        expect(
          firstWireText == secondWireText,
          firstRunId == secondRunId,
          reason: '$firstRunId / $secondRunId',
        );
      }
    },
  );

  test('test_decide_approval_command_arguments_property_id_and_decision', () {
    final Random random = seededRandom(_decideFieldsSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String idText = randomHostileText(random);
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final DecideApprovalCommand command = DecideApprovalCommand(
        approvalId: ApprovalId(idText),
        decision: decision,
      );
      final String wireText = jsonEncode(command.arguments);
      final JsonObject rereadArguments = decodeObject(jsonDecode(wireText));

      expect(
        rereadArguments.keys.toSet(),
        equals(<String>{'approval_id', 'decision'}),
      );
      expect(rereadArguments['approval_id'], idText);
      expect(ApprovalDecision.decode(rereadArguments['decision']), decision);
    }
  });

  test('test_decide_approval_command_arguments_property_node_names', () {
    final Set<Object?> sentDecisionNames = <Object?>{};
    for (final ApprovalDecision decision in ApprovalDecision.values) {
      final DecideApprovalCommand command = DecideApprovalCommand(
        approvalId: const ApprovalId('approval'),
        decision: decision,
      );
      sentDecisionNames.add(command.arguments['decision']);
    }

    expect(sentDecisionNames, equals(nodeApprovalDecisions.toSet()));
  });

  test('test_decide_approval_command_arguments_property_never_collide', () {
    final Random random = seededRandom(_decideCollisionSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DecideApprovalCommand first = _randomDecideApproval(random);
      final DecideApprovalCommand second = random.nextBool()
          ? _randomDecideApproval(random)
          : DecideApprovalCommand(
              approvalId: first.approvalId,
              decision: pickOne(random, ApprovalDecision.values),
            );
      final bool isSameDecision =
          first.approvalId == second.approvalId &&
          first.decision == second.decision;

      expect(
        jsonEncode(first.arguments) == jsonEncode(second.arguments),
        isSameDecision,
      );
    }
  });
}

DecideApprovalCommand _randomDecideApproval(Random random) {
  return DecideApprovalCommand(
    approvalId: ApprovalId(randomHostileText(random)),
    decision: pickOne(random, ApprovalDecision.values),
  );
}

CreateApprovalCommand _randomCreateApproval(Random random) {
  final RunId? runId = random.nextBool()
      ? null
      : RunId(randomHostileText(random));
  return CreateApprovalCommand(
    runId: runId,
    action: _randomApprovalAction(random),
  );
}

ApprovalAction _randomApprovalAction(Random random) {
  return ApprovalAction.fromJson(randomApprovalActionJson(random));
}

RunId? _randomNearbyRunId(Random random) {
  final List<RunId?> nearbyRunIds = <RunId?>[
    null,
    const RunId(''),
    const RunId('null'),
    const RunId('run'),
    const RunId('run '),
    RunId(randomHostileText(random)),
  ];
  return pickOne(random, nearbyRunIds);
}
