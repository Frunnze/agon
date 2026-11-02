import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/commands/approval_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/run_commands.dart';
import 'package:agent_orchestration/bridge/commands/runner_commands.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_catalog_json.dart';
import 'random_run_json.dart';
import 'random_typed_values.dart';
import 'random_work_json.dart';

const Set<String> _runOnlyFields = <String>{'run_id'};

const List<CommandShape> workCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'list_tasks',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListTasks,
    buildReplyJson: randomTasksViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'create_task',
    argumentFields: <String>{'task', 'start'},
    buildCommand: _buildCreateTask,
    buildReplyJson: randomTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_jobs',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListJobs,
    buildReplyJson: _randomJobViewsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_job',
    argumentFields: <String>{'task', 'schedule'},
    buildCommand: _buildCreateJob,
    buildReplyJson: randomTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'start_task',
    argumentFields: <String>{'task_id'},
    buildCommand: _buildStartTask,
    buildReplyJson: randomRunJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_runs',
    argumentFields: <String>{'task_id'},
    buildCommand: _buildListRuns,
    buildReplyJson: _randomRunsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'show_run',
    argumentFields: _runOnlyFields,
    buildCommand: _buildShowRun,
    buildReplyJson: randomRunViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'cancel_run',
    argumentFields: _runOnlyFields,
    buildCommand: _buildCancelRun,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'retry_run',
    argumentFields: _runOnlyFields,
    buildCommand: _buildRetryRun,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'send_chat_message',
    argumentFields: <String>{'workspace_id', 'run_id', 'text'},
    buildCommand: _buildSendChatMessage,
    buildReplyJson: randomChatMessageJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'list_approvals',
    argumentFields: <String>{},
    buildCommand: _buildListApprovals,
    buildReplyJson: randomApprovalsViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'create_approval',
    argumentFields: <String>{'run_id', 'action'},
    buildCommand: _buildCreateApproval,
    buildReplyJson: randomApprovalRequestJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'decide_approval',
    argumentFields: <String>{'approval_id', 'decision'},
    buildCommand: _buildDecideApproval,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'list_runners',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListRunners,
    buildReplyJson: randomRunnersViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'pause_runner',
    argumentFields: <String>{'device_id'},
    buildCommand: _buildPauseRunner,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'choose_agent_place',
    argumentFields: <String>{'place'},
    buildCommand: _buildChooseAgentPlace,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
  CommandShape(
    commandName: 'resume_runner',
    argumentFields: <String>{'device_id'},
    buildCommand: _buildResumeRunner,
    buildReplyJson: buildNoReply,
    encodeReply: encodeNoReply,
  ),
];

NodeCommand<Object?> _buildListTasks(Random random) {
  return ListTasksCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildCreateTask(Random random) {
  return CreateTaskCommand(
    task: randomTaskArguments(random),
    start: pickOne(random, TaskStart.values),
  );
}

NodeCommand<Object?> _buildListJobs(Random random) {
  return ListJobsCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildCreateJob(Random random) {
  return CreateJobCommand(
    task: randomTaskArguments(random),
    schedule: Schedule.fromJson(randomScheduleJson(random)),
  );
}

NodeCommand<Object?> _buildStartTask(Random random) {
  return StartTaskCommand(taskId: randomTaskId(random));
}

NodeCommand<Object?> _buildListRuns(Random random) {
  return ListRunsCommand(taskId: randomTaskId(random));
}

NodeCommand<Object?> _buildShowRun(Random random) {
  return ShowRunCommand(runId: randomRunId(random));
}

NodeCommand<Object?> _buildCancelRun(Random random) {
  return CancelRunCommand(runId: randomRunId(random));
}

NodeCommand<Object?> _buildRetryRun(Random random) {
  return RetryRunCommand(runId: randomRunId(random));
}

NodeCommand<Object?> _buildSendChatMessage(Random random) {
  return SendChatMessageCommand(
    workspaceId: randomWorkspaceId(random),
    runId: randomRunId(random),
    text: randomText(random),
  );
}

NodeCommand<Object?> _buildListApprovals(Random random) {
  return const ListApprovalsCommand();
}

NodeCommand<Object?> _buildCreateApproval(Random random) {
  final Object? runIdText = randomOptional(random, randomUuidText);
  return CreateApprovalCommand(
    runId: runIdText == null ? null : RunId(runIdText as String),
    action: ApprovalAction.fromJson(randomApprovalActionJson(random)),
  );
}

NodeCommand<Object?> _buildDecideApproval(Random random) {
  return DecideApprovalCommand(
    approvalId: ApprovalId(randomUuidText(random)),
    decision: pickOne(random, ApprovalDecision.values),
  );
}

NodeCommand<Object?> _buildListRunners(Random random) {
  return ListRunnersCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildPauseRunner(Random random) {
  return PauseRunnerCommand(deviceId: randomDeviceId(random));
}

NodeCommand<Object?> _buildChooseAgentPlace(Random random) {
  return ChooseAgentPlaceCommand(place: pickOne(random, AgentPlace.values));
}

NodeCommand<Object?> _buildResumeRunner(Random random) {
  return ResumeRunnerCommand(deviceId: randomDeviceId(random));
}

List<Object?> _randomJobViewsJson(Random random) {
  return randomListOf(random, randomJobViewJson);
}

List<Object?> _randomRunsJson(Random random) {
  return randomListOf(random, randomRunJson);
}
