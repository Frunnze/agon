import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/project_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/hostile_texts.dart';
import '../support/random_catalog_json.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';
import 'support/project_command_wire_models.dart';

const int _firstMemberSeed = 6060000;
const int _firstObjectReplySeed = 6061000;
const int _firstListReplySeed = 6062000;

const List<String> _repositoryFields = <String>[
  'address',
  'default_branch',
  'agent_access',
];

const List<ModelledCommandRow> _projectCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_projects_command',
    commandName: 'list_projects',
    build: _buildListProjects,
  ),
  ModelledCommandRow(
    typeName: 'create_project_command',
    commandName: 'create_project',
    build: _buildCreateProject,
  ),
  ModelledCommandRow(
    typeName: 'list_repositories_command',
    commandName: 'list_repositories',
    build: _buildListRepositories,
  ),
  ModelledCommandRow(
    typeName: 'create_repository_command',
    commandName: 'create_repository',
    build: _buildCreateRepository,
  ),
  ModelledCommandRow(
    typeName: 'remove_repository_command',
    commandName: 'remove_repository',
    build: _buildRemoveRepository,
  ),
];

const List<ReplyRow> _objectReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'create_project_command',
    commandName: 'create_project',
    buildObjectJson: randomProjectJson,
    requiredFields: <String>['id', 'workspace_id', 'name', 'repositories'],
  ),
  ReplyRow(
    typeName: 'create_repository_command',
    commandName: 'create_repository',
    buildObjectJson: randomRepositoryJson,
    requiredFields: _repositoryFields,
  ),
];

const List<ReplyRow> _listReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_projects_command',
    commandName: 'list_projects',
    buildObjectJson: randomProjectViewJson,
    requiredFields: <String>['project', 'task_count', 'running_task_count'],
  ),
  ReplyRow(
    typeName: 'list_repositories_command',
    commandName: 'list_repositories',
    buildObjectJson: randomRepositoryJson,
    requiredFields: _repositoryFields,
  ),
  ReplyRow(
    typeName: 'remove_repository_command',
    commandName: 'remove_repository',
    buildObjectJson: randomRepositoryJson,
    requiredFields: _repositoryFields,
  ),
];

void main() {
  testModelledCommandRows(_projectCommandRows, _firstMemberSeed);
  testObjectReplyRows(_objectReplyRows, _firstObjectReplySeed);
  testListReplyRows(_listReplyRows, _firstListReplySeed);
}

ModelledCommand _buildListProjects(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListProjectsCommand command = ListProjectsCommand(
    workspaceId: workspaceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildCreateProject(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final String projectName = randomHostileText(random);
  final List<Repository> repositories = randomHostileRepositories(random);
  final ApprovalPolicy? approvalPolicy = randomChosenApprovalPolicy(random);
  final CreateProjectCommand command = CreateProjectCommand(
    workspaceId: workspaceId,
    projectName: projectName,
    repositories: repositories,
    approvalPolicy: approvalPolicy,
  );
  return (
    command: command,
    givenFields: <Object?>[
      workspaceId,
      projectName,
      approvalPolicy,
      repositories,
    ],
    keptFields: <Object?>[
      command.workspaceId,
      command.projectName,
      command.approvalPolicy,
      command.repositories,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'name': projectName,
      'repositories': expectedRepositoriesJson(repositories),
      'approval_policy': expectedApprovalPolicyName(approvalPolicy),
    },
  );
}

ModelledCommand _buildListRepositories(Random random) {
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final ListRepositoriesCommand command = ListRepositoriesCommand(
    projectId: projectId,
  );
  return (
    command: command,
    givenFields: <Object?>[projectId],
    keptFields: <Object?>[command.projectId],
    expectedArguments: <String, Object?>{'project_id': projectId.value},
  );
}

ModelledCommand _buildCreateRepository(Random random) {
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final Repository repository = randomHostileRepository(random);
  final CreateRepositoryCommand command = CreateRepositoryCommand(
    projectId: projectId,
    repository: repository,
  );
  return (
    command: command,
    givenFields: <Object?>[projectId, repository],
    keptFields: <Object?>[command.projectId, command.repository],
    expectedArguments: <String, Object?>{
      'project_id': projectId.value,
      'repository': expectedRepositoryJson(repository),
    },
  );
}

ModelledCommand _buildRemoveRepository(Random random) {
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final String address = randomHostileText(random);
  final RemoveRepositoryCommand command = RemoveRepositoryCommand(
    projectId: projectId,
    address: address,
  );
  return (
    command: command,
    givenFields: <Object?>[projectId, address],
    keptFields: <Object?>[command.projectId, command.address],
    expectedArguments: <String, Object?>{
      'project_id': projectId.value,
      'address': address,
    },
  );
}
