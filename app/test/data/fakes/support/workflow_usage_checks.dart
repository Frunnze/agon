import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import 'workflow_usage_inputs.dart';
import 'workspace_scope_inputs.dart';

bool isUsedByWork(List<Task> work, WorkflowId workflowId) {
  for (final Task task in work) {
    final TaskDoer doer = task.doer;
    if (doer is WorkflowDoer && doer.workflowId == workflowId) {
      return true;
    }
  }
  return false;
}

List<Workflow> listWorkflowsUsedByWork(WorkflowUsage usage) {
  final List<Workflow> used = <Workflow>[];
  for (final Workflow workflow in usage.workflows) {
    if (isUsedByWork(usage.work, workflow.id)) {
      used.add(workflow);
    }
  }
  return used;
}

List<Workflow> listWorkflowsFreeOfWork(WorkflowUsage usage) {
  final List<Workflow> free = <Workflow>[];
  for (final Workflow workflow in usage.workflows) {
    if (!isUsedByWork(usage.work, workflow.id)) {
      free.add(workflow);
    }
  }
  return free;
}

bool asksToSignAny(ApprovalRequest approval, Set<WorkflowId> workflowIds) {
  final ApprovalAction action = approval.action;
  return action is SignWorkflowAction &&
      workflowIds.contains(action.workflowId);
}

List<ApprovalRequest> keepApprovalsSigningNone(
  List<ApprovalRequest> approvals,
  Set<WorkflowId> workflowIds,
) {
  final List<ApprovalRequest> kept = <ApprovalRequest>[];
  for (final ApprovalRequest approval in approvals) {
    if (!asksToSignAny(approval, workflowIds)) {
      kept.add(approval);
    }
  }
  return kept;
}

void expectOnlyWorkflowsRemoved(
  WorkflowUsage usage,
  Set<WorkflowId> removedWorkflowIds,
) {
  final List<Workflow> keptWorkflows = <Workflow>[
    for (final Workflow workflow in usage.workflows)
      if (!removedWorkflowIds.contains(workflow.id)) workflow,
  ];
  final List<ApprovalRequest> keptApprovals = keepApprovalsSigningNone(
    usage.approvals,
    removedWorkflowIds,
  );
  expectStoredWorkflows(usage, keptWorkflows);
  expect(
    usage.approvalRepository.listApprovals(),
    orderedEquals(keptApprovals),
  );

  for (final WorkflowChange change in usage.changes) {
    final WorkflowChange? found = usage.workflowRepository
        .findPendingChangeInAnyWorkspace(change.workflowId);
    final bool isRemoved = removedWorkflowIds.contains(change.workflowId);
    expect(found, isRemoved ? isNull : same(change));
  }
}

void expectWorkflowUsageUntouched(WorkflowUsage usage) {
  expectOnlyWorkflowsRemoved(usage, const <WorkflowId>{});
}

void expectStoredWorkflows(WorkflowUsage usage, List<Workflow> kept) {
  final List<Workflow> listedHere = <Workflow>[
    for (final Workflow workflow in kept)
      if (isModelUsableInWorkspace(
        workflow.availability,
        usage.currentWorkspaceId,
      ))
        workflow,
  ];
  expect(usage.workflowRepository.listWorkflows(), orderedEquals(listedHere));
  for (final Workflow workflow in usage.workflows) {
    if (kept.contains(workflow)) {
      expect(
        usage.workflowRepository.findWorkflowInAnyWorkspace(workflow.id),
        same(workflow),
      );
      continue;
    }
    expect(
      () => usage.workflowRepository.findWorkflowInAnyWorkspace(workflow.id),
      throwsA(isA<RecordNotFound>()),
    );
  }
}
