import 'package:agent_orchestration/bridge/commands/deletion_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/command_shape.dart';
import '../support/deletion_command_shapes.dart';
import '../support/simple_command_properties.dart';

const int _firstArgumentSeed = 85500;
const int _firstReplySeed = 85600;
const int _seedStep = 10;

void main() {
  testTextArgumentProperties(
    typeName: 'delete_project_command',
    seed: _firstArgumentSeed,
    field: 'project_id',
    buildCommand: _deleteProjectWithId,
  );
  testTextArgumentProperties(
    typeName: 'delete_workflow_command',
    seed: _firstArgumentSeed + _seedStep,
    field: 'workflow_id',
    buildCommand: _deleteWorkflowWithId,
  );
  testTextArgumentProperties(
    typeName: 'delete_task_command',
    seed: _firstArgumentSeed + 2 * _seedStep,
    field: 'task_id',
    buildCommand: _deleteTaskWithId,
  );
  testTextArgumentProperties(
    typeName: 'delete_workspace_command',
    seed: _firstArgumentSeed + 3 * _seedStep,
    field: 'workspace_id',
    buildCommand: _deleteWorkspaceWithId,
  );

  for (int index = 0; index < deletionCommandShapes.length; index += 1) {
    final CommandShape shape = deletionCommandShapes[index];
    testNothingReplyProperties(
      typeName: '${shape.commandName}_command',
      seed: _firstReplySeed + index * _seedStep,
      buildCommand: shape.buildCommand,
    );
  }
}

NodeCommand<Object?> _deleteProjectWithId(String idText) {
  return DeleteProjectCommand(projectId: ProjectId(idText));
}

NodeCommand<Object?> _deleteWorkflowWithId(String idText) {
  return DeleteWorkflowCommand(workflowId: WorkflowId(idText));
}

NodeCommand<Object?> _deleteTaskWithId(String idText) {
  return DeleteTaskCommand(taskId: TaskId(idText));
}

NodeCommand<Object?> _deleteWorkspaceWithId(String idText) {
  return DeleteWorkspaceCommand(workspaceId: WorkspaceId(idText));
}
