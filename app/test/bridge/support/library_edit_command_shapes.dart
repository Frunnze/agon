import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/library_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';

const List<CommandShape> libraryEditCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'update_skill',
    argumentFields: <String>{
      'workspace_id',
      'skill_id',
      'name',
      'summary',
      'instructions',
      'scope',
      'usage',
      'improvement',
    },
    buildCommand: _buildUpdateSkill,
    buildReplyJson: randomSkillJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'delete_skill',
    argumentFields: <String>{'skill_id'},
    buildCommand: _buildDeleteSkill,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'undo_skill_change',
    argumentFields: <String>{'skill_id'},
    buildCommand: _buildUndoSkillChange,
    buildReplyJson: randomSkillJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'update_rule',
    argumentFields: <String>{
      'workspace_id',
      'rule_id',
      'title',
      'details',
      'scope',
    },
    buildCommand: _buildUpdateRule,
    buildReplyJson: randomRuleJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'delete_rule',
    argumentFields: <String>{'rule_id'},
    buildCommand: _buildDeleteRule,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
];

NodeCommand<Object?> _buildUpdateSkill(Random random) {
  return UpdateSkillCommand(
    workspaceId: randomWorkspaceId(random),
    skillId: SkillId(randomUuidText(random)),
    skillName: randomText(random),
    summary: randomText(random),
    instructions: randomText(random),
    scope: Scope.fromJson(randomScopeJson(random)),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

NodeCommand<Object?> _buildDeleteSkill(Random random) {
  return DeleteSkillCommand(skillId: SkillId(randomUuidText(random)));
}

NodeCommand<Object?> _buildUndoSkillChange(Random random) {
  return UndoSkillChangeCommand(skillId: SkillId(randomUuidText(random)));
}

NodeCommand<Object?> _buildUpdateRule(Random random) {
  return UpdateRuleCommand(
    workspaceId: randomWorkspaceId(random),
    ruleId: RuleId(randomUuidText(random)),
    title: randomText(random),
    details: randomText(random),
    scope: Scope.fromJson(randomScopeJson(random)),
  );
}

NodeCommand<Object?> _buildDeleteRule(Random random) {
  return DeleteRuleCommand(ruleId: RuleId(randomUuidText(random)));
}
