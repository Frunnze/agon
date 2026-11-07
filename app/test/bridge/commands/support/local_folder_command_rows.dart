import 'dart:math';

import 'package:agent_orchestration/bridge/commands/project_commands.dart';

import '../../support/hostile_texts.dart';
import 'drafting_and_file_command_properties.dart';

const List<ModelledCommandRow> localFolderCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'check_local_folder_command',
    commandName: 'check_local_folder',
    build: _buildCheckLocalFolder,
  ),
  ModelledCommandRow(
    typeName: 'create_local_folder_command',
    commandName: 'create_local_folder',
    build: _buildCreateLocalFolder,
  ),
];

ModelledCommand _buildCheckLocalFolder(Random random) {
  final String path = randomHostileText(random);
  final CheckLocalFolderCommand command = CheckLocalFolderCommand(path: path);
  return (
    command: command,
    givenFields: <Object?>[path],
    keptFields: <Object?>[command.path],
    expectedArguments: <String, Object?>{'path': path},
  );
}

ModelledCommand _buildCreateLocalFolder(Random random) {
  final String parent = randomHostileText(random);
  final String folderName = randomHostileText(random);
  final CreateLocalFolderCommand command = CreateLocalFolderCommand(
    parent: parent,
    folderName: folderName,
  );
  return (
    command: command,
    givenFields: <Object?>[parent, folderName],
    keptFields: <Object?>[command.parent, command.folderName],
    expectedArguments: <String, Object?>{
      'parent': parent,
      'name': folderName,
    },
  );
}
