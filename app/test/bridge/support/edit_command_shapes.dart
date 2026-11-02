import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/commands/live_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/project_commands.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_catalog_json.dart';
import 'random_live_json.dart';
import 'random_typed_values.dart';
import 'random_work_json.dart';

const Set<String> _runOnlyFields = <String>{'run_id'};

const List<CommandShape> editCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'update_task',
    argumentFields: <String>{'task_id', 'task'},
    buildCommand: _buildUpdateTask,
    buildReplyJson: randomTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'update_job',
    argumentFields: <String>{'task_id', 'task', 'schedule'},
    buildCommand: _buildUpdateJob,
    buildReplyJson: randomTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'remove_repository',
    argumentFields: <String>{'project_id', 'address'},
    buildCommand: _buildRemoveRepository,
    buildReplyJson: _randomRepositoriesJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'watch_run',
    argumentFields: _runOnlyFields,
    buildCommand: _buildWatchRun,
    buildReplyJson: randomWatchViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'stop_watching_run',
    argumentFields: _runOnlyFields,
    buildCommand: _buildStopWatchingRun,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
];

NodeCommand<Object?> _buildUpdateTask(Random random) {
  return UpdateTaskCommand(
    taskId: randomTaskId(random),
    task: randomTaskArguments(random),
  );
}

NodeCommand<Object?> _buildUpdateJob(Random random) {
  return UpdateJobCommand(
    taskId: randomTaskId(random),
    task: randomTaskArguments(random),
    schedule: Schedule.fromJson(randomScheduleJson(random)),
  );
}

NodeCommand<Object?> _buildRemoveRepository(Random random) {
  return RemoveRepositoryCommand(
    projectId: randomProjectId(random),
    address: randomText(random),
  );
}

NodeCommand<Object?> _buildWatchRun(Random random) {
  return WatchRunCommand(runId: randomRunId(random));
}

NodeCommand<Object?> _buildStopWatchingRun(Random random) {
  return StopWatchingRunCommand(runId: randomRunId(random));
}

List<Object?> _randomRepositoriesJson(Random random) {
  return randomListOf(random, randomRepositoryJson);
}
