import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/random_work_json.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/task_argument_models.dart';

const int _firstMemberSeed = 7362000;

const Map<TaskStart, String> _rustTaskStartNames = <TaskStart, String>{
  TaskStart.now: 'now',
  TaskStart.later: 'later',
};

const List<ModelledCommandRow> _taskCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_tasks_command',
    commandName: 'list_tasks',
    build: _buildListTasks,
  ),
  ModelledCommandRow(
    typeName: 'create_task_command',
    commandName: 'create_task',
    build: _buildCreateTask,
  ),
  ModelledCommandRow(
    typeName: 'update_task_command',
    commandName: 'update_task',
    build: _buildUpdateTask,
  ),
  ModelledCommandRow(
    typeName: 'list_jobs_command',
    commandName: 'list_jobs',
    build: _buildListJobs,
  ),
  ModelledCommandRow(
    typeName: 'create_job_command',
    commandName: 'create_job',
    build: _buildCreateJob,
  ),
  ModelledCommandRow(
    typeName: 'update_job_command',
    commandName: 'update_job',
    build: _buildUpdateJob,
  ),
  ModelledCommandRow(
    typeName: 'start_task_command',
    commandName: 'start_task',
    build: _buildStartTask,
  ),
];

void main() {
  testModelledCommandRows(_taskCommandRows, _firstMemberSeed);
}

ModelledCommand _buildListTasks(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListTasksCommand command = ListTasksCommand(workspaceId: workspaceId);
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildCreateTask(Random random) {
  final ModelledTaskArguments task = randomModelledTaskArguments(random);
  final TaskStart start = pickOne(random, TaskStart.values);
  final CreateTaskCommand command = CreateTaskCommand(
    task: task.arguments,
    start: start,
  );
  return (
    command: command,
    givenFields: <Object?>[task.arguments, start],
    keptFields: <Object?>[command.task, command.start],
    expectedArguments: <String, Object?>{
      'task': task.expectedJson,
      'start': _rustTaskStartNames[start],
    },
  );
}

ModelledCommand _buildUpdateTask(Random random) {
  final TaskId taskId = TaskId(randomHostileText(random));
  final ModelledTaskArguments task = randomModelledTaskArguments(random);
  final UpdateTaskCommand command = UpdateTaskCommand(
    taskId: taskId,
    task: task.arguments,
  );
  return (
    command: command,
    givenFields: <Object?>[taskId, task.arguments],
    keptFields: <Object?>[command.taskId, command.task],
    expectedArguments: <String, Object?>{
      'task_id': taskId.value,
      'task': task.expectedJson,
    },
  );
}

ModelledCommand _buildListJobs(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListJobsCommand command = ListJobsCommand(workspaceId: workspaceId);
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildCreateJob(Random random) {
  final ModelledTaskArguments task = randomModelledTaskArguments(random);
  final JsonObject scheduleJson = randomScheduleJson(random);
  final Schedule schedule = Schedule.fromJson(scheduleJson);
  final CreateJobCommand command = CreateJobCommand(
    task: task.arguments,
    schedule: schedule,
  );
  return (
    command: command,
    givenFields: <Object?>[task.arguments, schedule],
    keptFields: <Object?>[command.task, command.schedule],
    expectedArguments: <String, Object?>{
      'task': task.expectedJson,
      'schedule': scheduleJson,
    },
  );
}

ModelledCommand _buildUpdateJob(Random random) {
  final TaskId taskId = TaskId(randomHostileText(random));
  final ModelledTaskArguments task = randomModelledTaskArguments(random);
  final JsonObject scheduleJson = randomScheduleJson(random);
  final Schedule schedule = Schedule.fromJson(scheduleJson);
  final UpdateJobCommand command = UpdateJobCommand(
    taskId: taskId,
    task: task.arguments,
    schedule: schedule,
  );
  return (
    command: command,
    givenFields: <Object?>[taskId, task.arguments, schedule],
    keptFields: <Object?>[command.taskId, command.task, command.schedule],
    expectedArguments: <String, Object?>{
      'task_id': taskId.value,
      'task': task.expectedJson,
      'schedule': scheduleJson,
    },
  );
}

ModelledCommand _buildStartTask(Random random) {
  final TaskId taskId = TaskId(randomHostileText(random));
  final StartTaskCommand command = StartTaskCommand(taskId: taskId);
  return (
    command: command,
    givenFields: <Object?>[taskId],
    keptFields: <Object?>[command.taskId],
    expectedArguments: <String, Object?>{'task_id': taskId.value},
  );
}
