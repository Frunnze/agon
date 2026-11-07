import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/library_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/simple_command_properties.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';

typedef _SkillFields = ({
  String skillName,
  String summary,
  String instructions,
  JsonObject scopeJson,
  String usageName,
  String improvementName,
});

const int _firstMemberSeed = 8610000;
const int _firstReplySeed = 8611000;
const int _firstListReplySeed = 8611500;
const int _nothingReplySeed = 8612000;

const List<String> _skillRequiredFields = <String>[
  'id',
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
  'source',
  'improvement',
];

const List<ModelledCommandRow> _skillCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_skills_command',
    commandName: 'list_skills',
    build: _buildListSkills,
  ),
  ModelledCommandRow(
    typeName: 'create_skill_command',
    commandName: 'create_skill',
    build: _buildCreateSkill,
  ),
  ModelledCommandRow(
    typeName: 'update_skill_command',
    commandName: 'update_skill',
    build: _buildUpdateSkill,
  ),
  ModelledCommandRow(
    typeName: 'delete_skill_command',
    commandName: 'delete_skill',
    build: _buildDeleteSkill,
  ),
  ModelledCommandRow(
    typeName: 'undo_skill_change_command',
    commandName: 'undo_skill_change',
    build: _buildUndoSkillChange,
  ),
];

const List<ReplyRow> _skillReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'create_skill_command',
    commandName: 'create_skill',
    buildObjectJson: randomSkillJson,
    requiredFields: _skillRequiredFields,
  ),
  ReplyRow(
    typeName: 'update_skill_command',
    commandName: 'update_skill',
    buildObjectJson: randomSkillJson,
    requiredFields: _skillRequiredFields,
  ),
  ReplyRow(
    typeName: 'undo_skill_change_command',
    commandName: 'undo_skill_change',
    buildObjectJson: randomSkillJson,
    requiredFields: _skillRequiredFields,
  ),
];

const List<ReplyRow> _skillListReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_skills_command',
    commandName: 'list_skills',
    buildObjectJson: randomSkillJson,
    requiredFields: _skillRequiredFields,
  ),
];

void main() {
  testModelledCommandRows(_skillCommandRows, _firstMemberSeed);
  testObjectReplyRows(_skillReplyRows, _firstReplySeed);
  testListReplyRows(_skillListReplyRows, _firstListReplySeed);
  testNothingReplyProperties(
    typeName: 'delete_skill_command',
    seed: _nothingReplySeed,
    buildCommand: findCommandShape('delete_skill').buildCommand,
  );
}

_SkillFields _randomSkillFields(Random random) {
  return (
    skillName: randomArgumentText(random),
    summary: randomHostileText(random),
    instructions: randomArgumentText(random),
    scopeJson: randomScopeJson(random),
    usageName: pickOne(random, nodeSkillUsages),
    improvementName: pickOne(random, nodeSkillImprovements),
  );
}

ModelledCommand _buildListSkills(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListSkillsCommand command = ListSkillsCommand(
    workspaceId: workspaceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildCreateSkill(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final _SkillFields fields = _randomSkillFields(random);
  final Scope scope = Scope.fromJson(fields.scopeJson);
  final SkillUsage usage = SkillUsage.decode(fields.usageName);
  final SkillImprovement improvement = SkillImprovement.decode(
    fields.improvementName,
  );
  final CreateSkillCommand command = CreateSkillCommand(
    workspaceId: workspaceId,
    skillName: fields.skillName,
    summary: fields.summary,
    instructions: fields.instructions,
    scope: scope,
    usage: usage,
    improvement: improvement,
  );
  return (
    command: command,
    givenFields: <Object?>[
      workspaceId,
      fields.skillName,
      fields.summary,
      fields.instructions,
      scope,
      usage,
      improvement,
    ],
    keptFields: <Object?>[
      command.workspaceId,
      command.skillName,
      command.summary,
      command.instructions,
      command.scope,
      command.usage,
      command.improvement,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'name': fields.skillName,
      'summary': fields.summary,
      'instructions': fields.instructions,
      'scope': fields.scopeJson,
      'usage': fields.usageName,
      'improvement': fields.improvementName,
    },
  );
}

ModelledCommand _buildUpdateSkill(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final SkillId skillId = SkillId(randomHostileText(random));
  final _SkillFields fields = _randomSkillFields(random);
  final Scope scope = Scope.fromJson(fields.scopeJson);
  final SkillUsage usage = SkillUsage.decode(fields.usageName);
  final SkillImprovement improvement = SkillImprovement.decode(
    fields.improvementName,
  );
  final UpdateSkillCommand command = UpdateSkillCommand(
    workspaceId: workspaceId,
    skillId: skillId,
    skillName: fields.skillName,
    summary: fields.summary,
    instructions: fields.instructions,
    scope: scope,
    usage: usage,
    improvement: improvement,
  );
  return (
    command: command,
    givenFields: <Object?>[
      workspaceId,
      skillId,
      fields.skillName,
      fields.summary,
      fields.instructions,
      scope,
      usage,
      improvement,
    ],
    keptFields: <Object?>[
      command.workspaceId,
      command.skillId,
      command.skillName,
      command.summary,
      command.instructions,
      command.scope,
      command.usage,
      command.improvement,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'skill_id': skillId.value,
      'name': fields.skillName,
      'summary': fields.summary,
      'instructions': fields.instructions,
      'scope': fields.scopeJson,
      'usage': fields.usageName,
      'improvement': fields.improvementName,
    },
  );
}

ModelledCommand _buildDeleteSkill(Random random) {
  final SkillId skillId = SkillId(randomHostileText(random));
  final DeleteSkillCommand command = DeleteSkillCommand(skillId: skillId);
  return (
    command: command,
    givenFields: <Object?>[skillId],
    keptFields: <Object?>[command.skillId],
    expectedArguments: <String, Object?>{'skill_id': skillId.value},
  );
}

ModelledCommand _buildUndoSkillChange(Random random) {
  final SkillId skillId = SkillId(randomHostileText(random));
  final UndoSkillChangeCommand command = UndoSkillChangeCommand(
    skillId: skillId,
  );
  return (
    command: command,
    givenFields: <Object?>[skillId],
    keptFields: <Object?>[command.skillId],
    expectedArguments: <String, Object?>{'skill_id': skillId.value},
  );
}
