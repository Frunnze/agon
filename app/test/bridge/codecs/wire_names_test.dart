import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/node_wire_names.dart';

final class _WireNameFamily {
  const _WireNameFamily(this.choices, this.nodeNames);

  final List<WireNamed> choices;
  final List<String> nodeNames;
}

const List<_WireNameFamily> _families = <_WireNameFamily>[
  _WireNameFamily(DeviceRole.values, nodeDeviceRoles),
  _WireNameFamily(HardwareKeyKind.values, nodeHardwareKeyKinds),
  _WireNameFamily(RunnerLink.values, nodeRunnerLinks),
  _WireNameFamily(AgentPlace.values, nodeAgentPlaces),
  _WireNameFamily(AgentAccess.values, nodeAgentAccesses),
  _WireNameFamily(SkillUsage.values, nodeSkillUsages),
  _WireNameFamily(SkillSource.values, nodeSkillSources),
  _WireNameFamily(AgentKind.values, nodeAgentKinds),
  _WireNameFamily(SignatureState.values, nodeSignatureStates),
  _WireNameFamily(DiffLineChange.values, nodeDiffChanges),
  _WireNameFamily(TaskStatus.values, nodeTaskStatuses),
  _WireNameFamily(Weekday.values, nodeWeekdays),
  _WireNameFamily(StepStatus.values, nodeStepStatuses),
  _WireNameFamily(RunStatus.values, nodeRunStatuses),
  _WireNameFamily(ChatAuthor.values, nodeChatAuthors),
  _WireNameFamily(ApprovalPolicy.values, nodeApprovalPolicies),
  _WireNameFamily(ApprovalDecision.values, nodeApprovalDecisions),
  _WireNameFamily(ChangeArea.values, nodeChangeAreas),
  _WireNameFamily(TaskStart.values, nodeTaskStarts),
  _WireNameFamily(RepositoryEntryKind.values, nodeRepositoryEntryKinds),
  _WireNameFamily(ServerStanding.values, nodeServerStandings),
  _WireNameFamily(ThisDeviceStanding.values, nodeThisDeviceStandings),
];

void main() {
  test('test_wire_name_property_every_enum_matches_node_names_exactly', () {
    for (final _WireNameFamily family in _families) {
      final Set<String> wireNames = <String>{};
      for (final WireNamed choice in family.choices) {
        wireNames.add(choice.wireName);
      }

      expect(wireNames, equals(family.nodeNames.toSet()));
      expect(wireNames.length, family.choices.length);
    }
  });

  test('test_decode_wire_name_property_finds_the_choice_named', () {
    final Random random = seededRandom(4401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WireNameFamily family = pickOne(random, _families);
      final WireNamed choice = pickOne(random, family.choices);

      expect(decodeWireName(family.choices, choice.wireName), same(choice));
    }
  });

  test('test_decode_wire_name_property_rejects_unknown_names', () {
    final Random random = seededRandom(4402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WireNameFamily family = pickOne(random, _families);
      final String unknownName = '${randomText(random)}?';

      expect(
        () => decodeWireName(family.choices, unknownName),
        throwsFormatException,
      );
    }
  });
}
