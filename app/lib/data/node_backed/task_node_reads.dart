import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/run_commands.dart' as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

Future<List<Task>> fetchCurrentWorkspaceTasks({
  required NodeCommandChannel channel,
  required WorkspaceRepository workspaceRepository,
}) async {
  final WorkspaceId? workspaceId = findCurrentWorkspaceId(workspaceRepository);
  if (workspaceId == null) {
    return const <Task>[];
  }

  final node.TasksView view = await executeNodeCommand(
    channel,
    node.ListTasksCommand(workspaceId: workspaceId),
  );
  final List<Task> tasks = <Task>[
    for (final node.TaskView taskView in view.tasks)
      mapTaskFromNode(taskView.task),
  ];
  return List<Task>.unmodifiable(tasks);
}

Future<List<Run>> fetchTaskRuns({
  required NodeCommandChannel channel,
  required TaskId taskId,
}) async {
  final List<node.Run> runs = await executeNodeCommand(
    channel,
    node.ListRunsCommand(taskId: taskId),
  );
  return <Run>[for (final node.Run run in runs) mapRunFromNode(run)];
}
