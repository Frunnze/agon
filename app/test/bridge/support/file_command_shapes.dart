import 'dart:math';

import 'package:agent_orchestration/bridge/commands/file_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'random_file_json.dart';
import 'random_typed_values.dart';

const List<CommandShape> fileCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'list_repository_branches',
    argumentFields: <String>{'project_id', 'repository_address'},
    buildCommand: _buildListRepositoryBranches,
    buildReplyJson: randomRepositoryBranchesJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_repository_files',
    argumentFields: <String>{
      'project_id',
      'repository_address',
      'runner_id',
      'branch',
      'folder',
    },
    buildCommand: _buildListRepositoryFiles,
    buildReplyJson: randomRepositoryFolderJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'read_repository_file',
    argumentFields: <String>{
      'project_id',
      'repository_address',
      'runner_id',
      'branch',
      'path',
    },
    buildCommand: _buildReadRepositoryFile,
    buildReplyJson: randomRepositoryFileJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildListRepositoryBranches(Random random) {
  return ListRepositoryBranchesCommand(
    projectId: randomProjectId(random),
    repositoryAddress: randomText(random),
  );
}

NodeCommand<Object?> _buildListRepositoryFiles(Random random) {
  return ListRepositoryFilesCommand(
    projectId: randomProjectId(random),
    repositoryAddress: randomText(random),
    runnerId: randomDeviceId(random),
    branch: randomText(random),
    folder: randomText(random),
  );
}

NodeCommand<Object?> _buildReadRepositoryFile(Random random) {
  return ReadRepositoryFileCommand(
    projectId: randomProjectId(random),
    repositoryAddress: randomText(random),
    runnerId: randomDeviceId(random),
    branch: randomText(random),
    path: randomText(random),
  );
}
