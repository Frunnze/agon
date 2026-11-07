import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/library_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/hostile_texts.dart';
import '../support/random_catalog_json.dart';
import '../support/simple_command_properties.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';

const int _firstMemberSeed = 8620000;
const int _firstReplySeed = 8621000;
const int _firstListReplySeed = 8621500;
const int _firstNothingReplySeed = 8622000;
const int _seedsPerNothingReply = 3;

const ModelledCommandRow _listRulesRow = ModelledCommandRow(
  typeName: 'list_rules_command',
  commandName: 'list_rules',
  build: _buildListRules,
);

const ModelledCommandRow _createRuleRow = ModelledCommandRow(
  typeName: 'create_rule_command',
  commandName: 'create_rule',
  build: _buildCreateRule,
);

const ModelledCommandRow _updateRuleRow = ModelledCommandRow(
  typeName: 'update_rule_command',
  commandName: 'update_rule',
  build: _buildUpdateRule,
);

const ModelledCommandRow _deleteRuleRow = ModelledCommandRow(
  typeName: 'delete_rule_command',
  commandName: 'delete_rule',
  build: _buildDeleteRule,
);

const ModelledCommandRow _setRuleEnabledRow = ModelledCommandRow(
  typeName: 'set_rule_enabled_command',
  commandName: 'set_rule_enabled',
  build: _buildSetRuleEnabled,
);

const ModelledCommandRow _showAgentsMarkdownRow = ModelledCommandRow(
  typeName: 'show_agents_markdown_command',
  commandName: 'show_agents_markdown',
  build: _buildShowAgentsMarkdown,
);

const List<ModelledCommandRow> _ruleCommandRows = <ModelledCommandRow>[
  _listRulesRow,
  _createRuleRow,
  _updateRuleRow,
  _deleteRuleRow,
  _setRuleEnabledRow,
  _showAgentsMarkdownRow,
];

const List<ModelledCommandRow> _objectReplyRows = <ModelledCommandRow>[
  _createRuleRow,
  _updateRuleRow,
  _showAgentsMarkdownRow,
];

const List<ModelledCommandRow> _nothingReplyRows = <ModelledCommandRow>[
  _deleteRuleRow,
  _setRuleEnabledRow,
];

const List<ReplyRow> _ruleListReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_rules_command',
    commandName: 'list_rules',
    buildObjectJson: randomRuleJson,
    requiredFields: <String>[
      'id',
      'title',
      'details',
      'scope',
      'enabled',
      'added_at',
    ],
  ),
];

void main() {
  testModelledCommandRows(_ruleCommandRows, _firstMemberSeed);
  testCommandReplyRows(_objectReplyRows, _firstReplySeed);
  testListReplyRows(_ruleListReplyRows, _firstListReplySeed);
  for (int i = 0; i < _nothingReplyRows.length; i += 1) {
    final ModelledCommandRow row = _nothingReplyRows[i];
    testNothingReplyProperties(
      typeName: row.typeName,
      seed: _firstNothingReplySeed + i * _seedsPerNothingReply,
      buildCommand: findCommandShape(row.commandName).buildCommand,
    );
  }
}

ModelledCommand _buildListRules(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListRulesCommand command = ListRulesCommand(workspaceId: workspaceId);
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildCreateRule(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final String title = randomArgumentText(random);
  final String details = randomArgumentText(random);
  final JsonObject scopeJson = randomScopeJson(random);
  final Scope scope = Scope.fromJson(scopeJson);
  final CreateRuleCommand command = CreateRuleCommand(
    workspaceId: workspaceId,
    title: title,
    details: details,
    scope: scope,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, title, details, scope],
    keptFields: <Object?>[
      command.workspaceId,
      command.title,
      command.details,
      command.scope,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'title': title,
      'details': details,
      'scope': scopeJson,
    },
  );
}

ModelledCommand _buildUpdateRule(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final RuleId ruleId = RuleId(randomHostileText(random));
  final String title = randomArgumentText(random);
  final String details = randomArgumentText(random);
  final JsonObject scopeJson = randomScopeJson(random);
  final Scope scope = Scope.fromJson(scopeJson);
  final UpdateRuleCommand command = UpdateRuleCommand(
    workspaceId: workspaceId,
    ruleId: ruleId,
    title: title,
    details: details,
    scope: scope,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, ruleId, title, details, scope],
    keptFields: <Object?>[
      command.workspaceId,
      command.ruleId,
      command.title,
      command.details,
      command.scope,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'rule_id': ruleId.value,
      'title': title,
      'details': details,
      'scope': scopeJson,
    },
  );
}

ModelledCommand _buildDeleteRule(Random random) {
  final RuleId ruleId = RuleId(randomHostileText(random));
  final DeleteRuleCommand command = DeleteRuleCommand(ruleId: ruleId);
  return (
    command: command,
    givenFields: <Object?>[ruleId],
    keptFields: <Object?>[command.ruleId],
    expectedArguments: <String, Object?>{'rule_id': ruleId.value},
  );
}

ModelledCommand _buildSetRuleEnabled(Random random) {
  final RuleId ruleId = RuleId(randomHostileText(random));
  final bool enabled = random.nextBool();
  final SetRuleEnabledCommand command = SetRuleEnabledCommand(
    ruleId: ruleId,
    enabled: enabled,
  );
  return (
    command: command,
    givenFields: <Object?>[ruleId, enabled],
    keptFields: <Object?>[command.ruleId, command.enabled],
    expectedArguments: <String, Object?>{
      'rule_id': ruleId.value,
      'enabled': enabled,
    },
  );
}

ModelledCommand _buildShowAgentsMarkdown(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final ShowAgentsMarkdownCommand command = ShowAgentsMarkdownCommand(
    workspaceId: workspaceId,
    projectId: projectId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, projectId],
    keptFields: <Object?>[command.workspaceId, command.projectId],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'project_id': projectId.value,
    },
  );
}
