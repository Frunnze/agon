import 'dart:math';

import 'package:agent_orchestration/bridge/commands/deletion_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import 'command_shape.dart';
import 'random_typed_values.dart';

const List<CommandShape> deletionCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'delete_project',
    argumentFields: <String>{'project_id'},
    buildCommand: _buildDeleteProject,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'delete_workflow',
    argumentFields: <String>{'workflow_id'},
    buildCommand: _buildDeleteWorkflow,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'delete_task',
    argumentFields: <String>{'task_id'},
    buildCommand: _buildDeleteTask,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'delete_workspace',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildDeleteWorkspace,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
];

NodeCommand<Object?> _buildDeleteProject(Random random) {
  return DeleteProjectCommand(projectId: randomProjectId(random));
}

NodeCommand<Object?> _buildDeleteWorkflow(Random random) {
  return DeleteWorkflowCommand(workflowId: randomWorkflowId(random));
}

NodeCommand<Object?> _buildDeleteTask(Random random) {
  return DeleteTaskCommand(taskId: randomTaskId(random));
}

NodeCommand<Object?> _buildDeleteWorkspace(Random random) {
  return DeleteWorkspaceCommand(workspaceId: randomWorkspaceId(random));
}
