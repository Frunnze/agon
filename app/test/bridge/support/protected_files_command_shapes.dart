import 'dart:math';

import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';

const int _largestPatternCount = 5;

const List<CommandShape> protectedFilesCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'set_protected_files',
    argumentFields: <String>{'workspace_id', 'patterns'},
    buildCommand: _buildSetProtectedFiles,
    buildReplyJson: randomWorkspaceJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'reset_protected_files',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildResetProtectedFiles,
    buildReplyJson: randomWorkspaceJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildSetProtectedFiles(Random random) {
  final int patternCount = random.nextInt(_largestPatternCount);
  final List<String> patterns = <String>[
    for (int i = 0; i < patternCount; i += 1) randomText(random),
  ];

  return SetProtectedFilesCommand(
    workspaceId: randomWorkspaceId(random),
    patterns: patterns,
  );
}

NodeCommand<Object?> _buildResetProtectedFiles(Random random) {
  return ResetProtectedFilesCommand(workspaceId: randomWorkspaceId(random));
}
