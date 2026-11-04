import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/library_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/project_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';

const List<CommandShape> catalogCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'list_projects',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListProjects,
    buildReplyJson: _randomProjectViewsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_project',
    argumentFields: <String>{
      'workspace_id',
      'name',
      'repositories',
      'approval_policy',
    },
    buildCommand: _buildCreateProject,
    buildReplyJson: randomProjectJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_repositories',
    argumentFields: <String>{'project_id'},
    buildCommand: _buildListRepositories,
    buildReplyJson: _randomRepositoriesJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_repository',
    argumentFields: <String>{'project_id', 'repository'},
    buildCommand: _buildCreateRepository,
    buildReplyJson: randomRepositoryJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_skills',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListSkills,
    buildReplyJson: _randomSkillsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_skill',
    argumentFields: <String>{
      'workspace_id',
      'name',
      'summary',
      'instructions',
      'scope',
      'usage',
      'improvement',
    },
    buildCommand: _buildCreateSkill,
    buildReplyJson: randomSkillJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_rules',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListRules,
    buildReplyJson: _randomRulesJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_rule',
    argumentFields: <String>{'workspace_id', 'title', 'details', 'scope'},
    buildCommand: _buildCreateRule,
    buildReplyJson: randomRuleJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'set_rule_enabled',
    argumentFields: <String>{'rule_id', 'enabled'},
    buildCommand: _buildSetRuleEnabled,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'show_agents_markdown',
    argumentFields: <String>{'workspace_id', 'project_id'},
    buildCommand: _buildShowAgentsMarkdown,
    buildReplyJson: randomAgentsMarkdownJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildListProjects(Random random) {
  return ListProjectsCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildCreateProject(Random random) {
  final List<Repository> repositories = <Repository>[];
  for (final Object? repositoryJson in _randomRepositoriesJson(random)) {
    repositories.add(Repository.fromJson(repositoryJson));
  }
  return CreateProjectCommand(
    workspaceId: randomWorkspaceId(random),
    projectName: randomText(random),
    repositories: repositories,
    approvalPolicy: randomOptionalApprovalPolicy(random),
  );
}

NodeCommand<Object?> _buildListRepositories(Random random) {
  return ListRepositoriesCommand(projectId: randomProjectId(random));
}

NodeCommand<Object?> _buildCreateRepository(Random random) {
  return CreateRepositoryCommand(
    projectId: randomProjectId(random),
    repository: Repository.fromJson(randomRepositoryJson(random)),
  );
}

NodeCommand<Object?> _buildListSkills(Random random) {
  return ListSkillsCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildCreateSkill(Random random) {
  return CreateSkillCommand(
    workspaceId: randomWorkspaceId(random),
    skillName: randomText(random),
    summary: randomText(random),
    instructions: randomText(random),
    scope: Scope.fromJson(randomScopeJson(random)),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

NodeCommand<Object?> _buildListRules(Random random) {
  return ListRulesCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildCreateRule(Random random) {
  return CreateRuleCommand(
    workspaceId: randomWorkspaceId(random),
    title: randomText(random),
    details: randomText(random),
    scope: Scope.fromJson(randomScopeJson(random)),
  );
}

NodeCommand<Object?> _buildSetRuleEnabled(Random random) {
  return SetRuleEnabledCommand(
    ruleId: RuleId(randomUuidText(random)),
    enabled: random.nextBool(),
  );
}

NodeCommand<Object?> _buildShowAgentsMarkdown(Random random) {
  return ShowAgentsMarkdownCommand(
    workspaceId: randomWorkspaceId(random),
    projectId: randomProjectId(random),
  );
}

List<Object?> _randomProjectViewsJson(Random random) {
  return randomListOf(random, randomProjectViewJson);
}

List<Object?> _randomRepositoriesJson(Random random) {
  return randomListOf(random, randomRepositoryJson);
}

List<Object?> _randomSkillsJson(Random random) {
  return randomListOf(random, randomSkillJson);
}

List<Object?> _randomRulesJson(Random random) {
  return randomListOf(random, randomRuleJson);
}
