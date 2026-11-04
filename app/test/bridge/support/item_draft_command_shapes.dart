import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/commands/item_draft_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';
import 'random_work_json.dart';

const List<String> nodeDraftKinds = <String>[
  'task',
  'job',
  'skill',
  'rule',
];

const List<CommandShape> itemDraftCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'draft_item',
    argumentFields: <String>{
      'workspace_id',
      'kind',
      'request',
      'started_from',
      'change',
    },
    buildCommand: _buildDraftItem,
    buildReplyJson: randomDraftingTaskViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'item_draft_status',
    argumentFields: <String>{
      'workspace_id',
      'task_id',
      'kind',
    },
    buildCommand: _buildItemDraftStatus,
    buildReplyJson: randomItemDraftStatusJson,
    encodeReply: encodeValueReply,
  ),
];

Map<String, Object?> _randomWorkDraftJson(Random random, String kind) {
  return <String, Object?>{
    'kind': kind,
    'title': randomText(random),
    'details': randomText(random),
    'project_id': randomOptional(random, randomUuidText),
    'doer': randomTaskDoerJson(random),
    'runs_on': randomRunnerTargetJson(random),
    'agent_place': pickOne(random, nodeAgentPlaces),
    'skills': randomUuidTexts(random),
    'uses_automatic_skills': random.nextBool(),
    'approval_policy': randomOptionalApprovalPolicyJson(random),
    'schedule': randomOptional(random, randomScheduleJson),
  };
}

Map<String, Object?> randomItemDraftJson(Random random) {
  final String kind = pickOne(random, nodeDraftKinds);
  return switch (kind) {
    'skill' => <String, Object?>{
      'kind': kind,
      'name': randomText(random),
      'summary': randomText(random),
      'instructions': randomText(random),
      'scope': randomScopeJson(random),
      'usage': pickOne(random, nodeSkillUsages),
      'improvement': pickOne(random, nodeSkillImprovements),
    },
    'rule' => <String, Object?>{
      'kind': kind,
      'title': randomText(random),
      'details': randomText(random),
      'scope': randomScopeJson(random),
    },
    _ => _randomWorkDraftJson(random, kind),
  };
}

Map<String, Object?> randomItemDraftStatusJson(Random random) {
  final List<Map<String, Object?>> states = <Map<String, Object?>>[
    <String, Object?>{'state': 'working'},
    <String, Object?>{
      'state': 'done',
      'draft': randomItemDraftJson(random),
      'problems': randomTexts(random),
    },
  ];
  return pickOne(random, states);
}

Map<String, Object?> randomDraftingTaskViewJson(Random random) {
  return <String, Object?>{
    'task_id': randomUuidText(random),
    'drafter': pickOne(random, nodeAgentKinds),
  };
}

DraftKind _randomDraftKind(Random random) {
  return pickOne(random, DraftKind.values);
}

DraftChange? _randomDraftChange(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return DraftChange(
    draft: ItemDraft.fromJson(randomItemDraftJson(random)),
    note: randomText(random),
  );
}

NodeCommand<Object?> _buildDraftItem(Random random) {
  return DraftItemCommand(
    workspaceId: randomWorkspaceId(random),
    kind: _randomDraftKind(random),
    wish: randomText(random),
    startedFrom: random.nextBool() ? null : randomText(random),
    change: _randomDraftChange(random),
  );
}

NodeCommand<Object?> _buildItemDraftStatus(Random random) {
  return ItemDraftStatusCommand(
    workspaceId: randomWorkspaceId(random),
    taskId: randomTaskId(random),
    kind: _randomDraftKind(random),
  );
}
