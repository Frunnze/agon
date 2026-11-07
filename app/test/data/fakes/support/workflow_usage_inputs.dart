import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import 'approval_inputs.dart';
import 'task_inputs.dart';
import 'workflow_inputs.dart';

const List<WorkspaceId> usageWorkspaceIds = <WorkspaceId>[
  WorkspaceId('usage-workspace-0'),
  WorkspaceId('usage-workspace-1'),
  WorkspaceId('usage-workspace-2'),
];
const WorkflowId unlistedWorkflowId = WorkflowId('unlisted-workflow');
const String _workIdentifierPrefix = 'usage-work-';
const String _approvalIdentifierPrefix = 'usage-approval-';
const int _largestWorkflowCount = 5;
const int _largestWorkCount = 6;
const int _largestApprovalCount = 7;

typedef WorkflowUsage = ({
  FakeWorkflowRepository workflowRepository,
  FakeApprovalRepository approvalRepository,
  FakeTaskRepository taskRepository,
  FakeTaskWork taskWork,
  List<Workflow> workflows,
  List<WorkflowChange> changes,
  List<ApprovalRequest> approvals,
  List<Task> work,
});

WorkspaceScope randomAvailability(Random random) {
  if (random.nextInt(4) == 0) {
    return const AllWorkspaces();
  }
  return OnlyWorkspaces(randomWorkspaceSubset(random).toList());
}

Set<WorkspaceId> randomWorkspaceSubset(Random random) {
  final Set<WorkspaceId> picked = <WorkspaceId>{};
  for (final WorkspaceId workspaceId in usageWorkspaceIds) {
    if (random.nextBool()) {
      picked.add(workspaceId);
    }
  }
  return picked;
}

List<WorkflowId> listWorkflowIds(List<Workflow> workflows) {
  final List<WorkflowId> workflowIds = <WorkflowId>[];
  for (final Workflow workflow in workflows) {
    workflowIds.add(workflow.id);
  }
  return workflowIds;
}

Task buildWorkWithDoer(
  Random random, {
  required String identifier,
  required TaskDoer doer,
  required Schedule? schedule,
}) {
  final TaskDraft base = randomTaskDraft(random);
  final TaskDraft draft = TaskDraft(
    title: base.title,
    details: base.details,
    projectId: base.projectId,
    doer: doer,
    runsOn: base.runsOn,
    agentPlace: base.agentPlace,
    skills: base.skills,
    usesAutomaticSkills: base.usesAutomaticSkills,
    approvalPolicy: base.approvalPolicy,
  );
  return Task.fromDraft(
    id: TaskId(identifier),
    draft: draft,
    schedule: schedule,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
}

TaskDoer randomDoerAmong(Random random, List<WorkflowId> workflowIds) {
  if (random.nextInt(3) == 0) {
    return OneAgentDoer(pickOne(random, AgentKind.values));
  }
  final List<WorkflowId> candidates = <WorkflowId>[
    ...workflowIds,
    unlistedWorkflowId,
  ];
  return WorkflowDoer(pickOne(random, candidates));
}

List<Task> randomWorkUsing(Random random, List<WorkflowId> workflowIds) {
  final int count = random.nextInt(_largestWorkCount + 1);
  final List<Task> work = <Task>[];
  for (int index = 0; index < count; index += 1) {
    final Schedule? schedule = random.nextBool()
        ? randomJobSchedule(random)
        : null;
    work.add(
      buildWorkWithDoer(
        random,
        identifier: '$_workIdentifierPrefix$index',
        doer: randomDoerAmong(random, workflowIds),
        schedule: schedule,
      ),
    );
  }
  return work;
}

List<ApprovalRequest> randomApprovalsSigning(
  Random random,
  List<WorkflowId> workflowIds,
) {
  final int count = random.nextInt(_largestApprovalCount + 1);
  final List<WorkflowId> candidates = <WorkflowId>[
    ...workflowIds,
    unlistedWorkflowId,
  ];
  final List<ApprovalRequest> approvals = <ApprovalRequest>[];
  for (int index = 0; index < count; index += 1) {
    final ApprovalRequest base = randomApprovalWithId(
      random,
      '$_approvalIdentifierPrefix$index',
    );
    final ApprovalAction action = random.nextBool()
        ? SignWorkflowAction(workflowId: pickOne(random, candidates))
        : base.action;
    approvals.add(
      ApprovalRequest(
        id: base.id,
        runId: base.runId,
        action: action,
        requestedBy: base.requestedBy,
        requestedAt: base.requestedAt,
        decision: base.decision,
      ),
    );
  }
  return approvals;
}

List<Workflow> _randomUsageWorkflows(Random random) {
  final int count = 1 + random.nextInt(_largestWorkflowCount);
  final List<Workflow> workflows = <Workflow>[];
  for (int index = 0; index < count; index += 1) {
    final WorkflowSignature? signature = random.nextBool()
        ? buildSampleSignature()
        : null;
    final Workflow graph = randomValidWorkflow(
      random,
      index: index,
      signature: signature,
    );
    workflows.add(
      Workflow(
        id: graph.id,
        name: graph.name,
        availability: randomAvailability(random),
        agents: graph.agents,
        connections: graph.connections,
        signature: graph.signature,
      ),
    );
  }
  return workflows;
}

WorkflowUsage seedWorkflowUsage(Random random) {
  final List<Workflow> workflows = _randomUsageWorkflows(random);
  final List<WorkflowId> workflowIds = listWorkflowIds(workflows);
  final List<WorkflowChange> changes = randomChangesFor(random, workflows);
  final List<ApprovalRequest> approvals = randomApprovalsSigning(
    random,
    workflowIds,
  );
  final List<Task> work = randomWorkUsing(random, workflowIds);

  final FakeWorkflowRepository workflowRepository = buildWorkflowRepository(
    workflows: workflows,
    changes: changes,
  );
  final FakeTaskRepository taskRepository = buildTaskRepository(
    tasks: work,
    runs: const <Run>[],
    workflows: workflowRepository,
  );

  return (
    workflowRepository: workflowRepository,
    approvalRepository: buildApprovalRepository(random, approvals),
    taskRepository: taskRepository,
    taskWork: buildTaskWorkOver(taskRepository),
    workflows: workflows,
    changes: changes,
    approvals: approvals,
    work: work,
  );
}

WorkflowUsage seedLinkedWorkflowUsage(Random random) {
  final WorkflowUsage usage = seedWorkflowUsage(random);
  usage.workflowRepository.linkWork(
    taskWork: usage.taskWork,
    approvalRepository: usage.approvalRepository,
  );
  return usage;
}
