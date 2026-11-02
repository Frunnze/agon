import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

sealed class TaskDoer {
  const TaskDoer();
}

final class OneAgentDoer extends TaskDoer {
  const OneAgentDoer(this.agent);

  final AgentKind agent;

  @override
  bool operator ==(Object other) {
    return other is OneAgentDoer && other.agent == agent;
  }

  @override
  int get hashCode => agent.hashCode;
}

final class WorkflowDoer extends TaskDoer {
  const WorkflowDoer(this.workflowId);

  final WorkflowId workflowId;

  @override
  bool operator ==(Object other) {
    return other is WorkflowDoer && other.workflowId == workflowId;
  }

  @override
  int get hashCode => workflowId.hashCode;
}

enum TaskStatus { toDo, running, waitingForApproval, failed, done }

final class TaskDraft {
  TaskDraft({
    required this.title,
    required this.details,
    required this.projectId,
    required this.doer,
    required this.runsOn,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
  }) : skills = List<SkillId>.unmodifiable(skills);

  final String title;
  final String details;
  final ProjectId projectId;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy approvalPolicy;
}

final class JobDraft {
  const JobDraft({required this.task, required this.schedule});

  final TaskDraft task;
  final Schedule schedule;
}

final class Task {
  Task({
    required this.id,
    required this.title,
    required this.details,
    required this.projectId,
    required this.doer,
    required this.runsOn,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
    required this.schedule,
    required this.status,
    required this.createdAt,
  }) : skills = List<SkillId>.unmodifiable(skills);

  Task.fromDraft({
    required this.id,
    required TaskDraft draft,
    required this.schedule,
    required this.status,
    required this.createdAt,
  }) : title = draft.title,
       details = draft.details,
       projectId = draft.projectId,
       doer = draft.doer,
       runsOn = draft.runsOn,
       skills = draft.skills,
       usesAutomaticSkills = draft.usesAutomaticSkills,
       approvalPolicy = draft.approvalPolicy;

  final TaskId id;
  final String title;
  final String details;
  final ProjectId projectId;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy approvalPolicy;
  final Schedule? schedule;
  final TaskStatus status;
  final DateTime createdAt;

  TaskDraft toDraft() {
    return TaskDraft(
      title: title,
      details: details,
      projectId: projectId,
      doer: doer,
      runsOn: runsOn,
      skills: skills,
      usesAutomaticSkills: usesAutomaticSkills,
      approvalPolicy: approvalPolicy,
    );
  }

  Task withStatus(TaskStatus nextStatus) {
    return Task.fromDraft(
      id: id,
      draft: toDraft(),
      schedule: schedule,
      status: nextStatus,
      createdAt: createdAt,
    );
  }
}
