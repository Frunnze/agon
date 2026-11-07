import 'dart:math';

import 'package:agent_orchestration/bridge/commands/file_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/hostile_texts.dart';
import 'support/drafting_and_file_command_properties.dart';

const int _firstMemberSeed = 9812000;
const int _firstReplySeed = 9813000;

const List<ModelledCommandRow> _fileCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_repository_branches_command',
    commandName: 'list_repository_branches',
    build: _buildListRepositoryBranches,
  ),
  ModelledCommandRow(
    typeName: 'list_repository_files_command',
    commandName: 'list_repository_files',
    build: _buildListRepositoryFiles,
  ),
  ModelledCommandRow(
    typeName: 'read_repository_file_command',
    commandName: 'read_repository_file',
    build: _buildReadRepositoryFile,
  ),
];

void main() {
  testModelledCommandRows(_fileCommandRows, _firstMemberSeed);
  testCommandReplyRows(_fileCommandRows, _firstReplySeed);
}

ModelledCommand _buildListRepositoryBranches(Random random) {
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final String repositoryAddress = randomHostileText(random);
  final DeviceId? preferredRunnerId = random.nextBool()
      ? null
      : DeviceId(randomHostileText(random));
  final ListRepositoryBranchesCommand command = ListRepositoryBranchesCommand(
    projectId: projectId,
    repositoryAddress: repositoryAddress,
    preferredRunnerId: preferredRunnerId,
  );
  return (
    command: command,
    givenFields: <Object?>[projectId, repositoryAddress, preferredRunnerId],
    keptFields: <Object?>[
      command.projectId,
      command.repositoryAddress,
      command.preferredRunnerId,
    ],
    expectedArguments: <String, Object?>{
      'project_id': projectId.value,
      'repository_address': repositoryAddress,
      'preferred_runner_id': preferredRunnerId?.value,
    },
  );
}

ModelledCommand _buildListRepositoryFiles(Random random) {
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final String repositoryAddress = randomHostileText(random);
  final DeviceId runnerId = DeviceId(randomHostileText(random));
  final String branch = randomHostileText(random);
  final String folder = randomHostileText(random);
  final ListRepositoryFilesCommand command = ListRepositoryFilesCommand(
    projectId: projectId,
    repositoryAddress: repositoryAddress,
    runnerId: runnerId,
    branch: branch,
    folder: folder,
  );
  return (
    command: command,
    givenFields: <Object?>[
      projectId,
      repositoryAddress,
      runnerId,
      branch,
      folder,
    ],
    keptFields: <Object?>[
      command.projectId,
      command.repositoryAddress,
      command.runnerId,
      command.branch,
      command.folder,
    ],
    expectedArguments: <String, Object?>{
      'project_id': projectId.value,
      'repository_address': repositoryAddress,
      'runner_id': runnerId.value,
      'branch': branch,
      'folder': folder,
    },
  );
}

ModelledCommand _buildReadRepositoryFile(Random random) {
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final String repositoryAddress = randomHostileText(random);
  final DeviceId runnerId = DeviceId(randomHostileText(random));
  final String branch = randomHostileText(random);
  final String path = randomHostileText(random);
  final ReadRepositoryFileCommand command = ReadRepositoryFileCommand(
    projectId: projectId,
    repositoryAddress: repositoryAddress,
    runnerId: runnerId,
    branch: branch,
    path: path,
  );
  return (
    command: command,
    givenFields: <Object?>[
      projectId,
      repositoryAddress,
      runnerId,
      branch,
      path,
    ],
    keptFields: <Object?>[
      command.projectId,
      command.repositoryAddress,
      command.runnerId,
      command.branch,
      command.path,
    ],
    expectedArguments: <String, Object?>{
      'project_id': projectId.value,
      'repository_address': repositoryAddress,
      'runner_id': runnerId.value,
      'branch': branch,
      'path': path,
    },
  );
}
