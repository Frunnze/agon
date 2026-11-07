import 'dart:math';

import 'package:agent_orchestration/bridge/commands/run_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/hostile_texts.dart';
import '../support/random_run_json.dart';
import '../support/simple_command_properties.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';

const int _firstMemberSeed = 6066000;
const int _firstObjectReplySeed = 6067000;
const int _firstListReplySeed = 6068000;
const int _cancelReplySeed = 6069000;
const int _retryReplySeed = 6069100;

const List<ModelledCommandRow> _runCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_runs_command',
    commandName: 'list_runs',
    build: _buildListRuns,
  ),
  ModelledCommandRow(
    typeName: 'show_run_command',
    commandName: 'show_run',
    build: _buildShowRun,
  ),
  ModelledCommandRow(
    typeName: 'cancel_run_command',
    commandName: 'cancel_run',
    build: _buildCancelRun,
  ),
  ModelledCommandRow(
    typeName: 'retry_run_command',
    commandName: 'retry_run',
    build: _buildRetryRun,
  ),
  ModelledCommandRow(
    typeName: 'send_chat_message_command',
    commandName: 'send_chat_message',
    build: _buildSendChatMessage,
  ),
];

const List<ReplyRow> _objectReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'show_run_command',
    commandName: 'show_run',
    buildObjectJson: randomRunViewJson,
    requiredFields: <String>['run', 'progress', 'link'],
  ),
  ReplyRow(
    typeName: 'send_chat_message_command',
    commandName: 'send_chat_message',
    buildObjectJson: randomChatMessageJson,
    requiredFields: <String>[
      'at',
      'author',
      'text',
      'is_error',
      'waiting_to_send',
    ],
  ),
];

const List<ReplyRow> _listReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_runs_command',
    commandName: 'list_runs',
    buildObjectJson: randomRunJson,
    requiredFields: <String>[
      'id',
      'task_id',
      'number',
      'status',
      'link',
      'started_by',
      'started_at',
    ],
  ),
];

void main() {
  testModelledCommandRows(_runCommandRows, _firstMemberSeed);
  testObjectReplyRows(_objectReplyRows, _firstObjectReplySeed);
  testListReplyRows(_listReplyRows, _firstListReplySeed);
  testNothingReplyProperties(
    typeName: 'cancel_run_command',
    seed: _cancelReplySeed,
    buildCommand: findCommandShape('cancel_run').buildCommand,
  );
  testNothingReplyProperties(
    typeName: 'retry_run_command',
    seed: _retryReplySeed,
    buildCommand: findCommandShape('retry_run').buildCommand,
  );
}

ModelledCommand _buildListRuns(Random random) {
  final TaskId taskId = TaskId(randomHostileText(random));
  final ListRunsCommand command = ListRunsCommand(taskId: taskId);
  return (
    command: command,
    givenFields: <Object?>[taskId],
    keptFields: <Object?>[command.taskId],
    expectedArguments: <String, Object?>{'task_id': taskId.value},
  );
}

ModelledCommand _buildShowRun(Random random) {
  final RunId runId = RunId(randomHostileText(random));
  final ShowRunCommand command = ShowRunCommand(runId: runId);
  return (
    command: command,
    givenFields: <Object?>[runId],
    keptFields: <Object?>[command.runId],
    expectedArguments: <String, Object?>{'run_id': runId.value},
  );
}

ModelledCommand _buildCancelRun(Random random) {
  final RunId runId = RunId(randomHostileText(random));
  final CancelRunCommand command = CancelRunCommand(runId: runId);
  return (
    command: command,
    givenFields: <Object?>[runId],
    keptFields: <Object?>[command.runId],
    expectedArguments: <String, Object?>{'run_id': runId.value},
  );
}

ModelledCommand _buildRetryRun(Random random) {
  final RunId runId = RunId(randomHostileText(random));
  final RetryRunCommand command = RetryRunCommand(runId: runId);
  return (
    command: command,
    givenFields: <Object?>[runId],
    keptFields: <Object?>[command.runId],
    expectedArguments: <String, Object?>{'run_id': runId.value},
  );
}

ModelledCommand _buildSendChatMessage(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final RunId runId = RunId(randomHostileText(random));
  final String text = randomArgumentText(random);
  final SendChatMessageCommand command = SendChatMessageCommand(
    workspaceId: workspaceId,
    runId: runId,
    text: text,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, runId, text],
    keptFields: <Object?>[command.workspaceId, command.runId, command.text],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'run_id': runId.value,
      'text': text,
    },
  );
}
