import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

TaskDoer mapTaskDoerFromNode(node.TaskDoer doer) {
  return switch (doer) {
    node.OneAgent(:final node.AgentKind agent) => OneAgentDoer(
      mapAgentKindFromNode(agent),
    ),
    node.WorkflowDoer(:final WorkflowId workflowId) => WorkflowDoer(
      workflowId,
    ),
  };
}

node.TaskDoer mapTaskDoerToNode(TaskDoer doer) {
  return switch (doer) {
    OneAgentDoer(:final AgentKind agent) => node.OneAgent(
      agent: mapAgentKindToNode(agent),
    ),
    WorkflowDoer(:final WorkflowId workflowId) => node.WorkflowDoer(
      workflowId: workflowId,
    ),
  };
}

TaskStatus mapTaskStatusFromNode(node.TaskStatus status) {
  return switch (status) {
    node.TaskStatus.toDo => TaskStatus.toDo,
    node.TaskStatus.running => TaskStatus.running,
    node.TaskStatus.waitingForApproval => TaskStatus.waitingForApproval,
    node.TaskStatus.failed => TaskStatus.failed,
    node.TaskStatus.done => TaskStatus.done,
  };
}

Task mapTaskFromNode(node.Task task) {
  final node.Schedule? wireSchedule = task.schedule;
  final Schedule? schedule = wireSchedule == null
      ? null
      : mapScheduleFromNode(wireSchedule);

  return Task(
    id: task.id,
    title: task.title,
    details: task.details,
    projectId: task.projectId,
    doer: mapTaskDoerFromNode(task.doer),
    runsOn: mapRunnerTargetFromNode(task.runsOn),
    skills: task.skills,
    usesAutomaticSkills: task.usesAutomaticSkills,
    approvalPolicy: mapApprovalPolicyFromNode(task.approvalPolicy),
    schedule: schedule,
    status: mapTaskStatusFromNode(task.status),
    createdAt: task.createdAt,
  );
}

node.TaskArguments mapTaskDraftToNode({
  required TaskDraft draft,
  required WorkspaceId workspaceId,
}) {
  return node.TaskArguments(
    workspaceId: workspaceId,
    projectId: draft.projectId,
    title: draft.title,
    details: draft.details,
    doer: mapTaskDoerToNode(draft.doer),
    runsOn: mapRunnerTargetToNode(draft.runsOn),
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: mapApprovalPolicyToNode(draft.approvalPolicy),
  );
}
