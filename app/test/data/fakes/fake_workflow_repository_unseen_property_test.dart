import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_usage_checks.dart';
import 'support/workflow_usage_inputs.dart';

const int _seedSpan = 1 << 30;

bool _isSeenInNoRemainingWorkspace(
  WorkspaceScope availability,
  Set<WorkspaceId> remainingWorkspaceIds,
) {
  if (availability is! OnlyWorkspaces) {
    return false;
  }
  for (final WorkspaceId workspaceId in availability.workspaces) {
    if (remainingWorkspaceIds.contains(workspaceId)) {
      return false;
    }
  }
  return true;
}

Set<WorkflowId> _listUnseenIds(
  WorkflowUsage usage,
  Set<WorkspaceId> remainingWorkspaceIds,
) {
  final Set<WorkflowId> unseen = <WorkflowId>{};
  for (final Workflow workflow in usage.workflows) {
    final bool isUnseen = _isSeenInNoRemainingWorkspace(
      workflow.availability,
      remainingWorkspaceIds,
    );
    if (isUnseen) {
      unseen.add(workflow.id);
    }
  }
  return unseen;
}

Set<WorkflowId> _listServerRemovedIds(
  WorkflowUsage usage,
  Set<WorkspaceId> remainingWorkspaceIds,
) {
  final Set<WorkflowId> unseen = _listUnseenIds(usage, remainingWorkspaceIds);
  final Set<WorkflowId> removed = <WorkflowId>{};
  for (final WorkflowId workflowId in unseen) {
    if (!isUsedByWork(usage.work, workflowId)) {
      removed.add(workflowId);
    }
  }
  return removed;
}

Set<WorkflowId> _listListedIds(WorkflowUsage usage) {
  return listWorkflowIds(usage.workflowRepository.listWorkflows()).toSet();
}

void main() {
  test('test_forget_unseen_workflows_property_matches_the_server_'
      'rule', () {
    final Random random = seededRandom(95121);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final Set<WorkspaceId> remaining = randomWorkspaceSubset(random);

      usage.workflowRepository.forgetUnseenWorkflows(remaining);

      expectOnlyWorkflowsRemoved(
        usage,
        _listServerRemovedIds(usage, remaining),
      );
    }
  });

  test('test_forget_unseen_workflows_property_is_idempotent', () {
    final Random random = seededRandom(95122);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final Set<WorkspaceId> remaining = randomWorkspaceSubset(random);

      usage.workflowRepository.forgetUnseenWorkflows(remaining);
      final List<Workflow> onceWorkflows = usage.workflowRepository
          .listWorkflows();
      final List<ApprovalRequest> onceApprovals = usage.approvalRepository
          .listApprovals();
      usage.workflowRepository.forgetUnseenWorkflows(remaining);

      expect(
        usage.workflowRepository.listWorkflows(),
        orderedEquals(onceWorkflows),
      );
      expect(
        usage.approvalRepository.listApprovals(),
        orderedEquals(onceApprovals),
      );
    }
  });

  test('test_forget_unseen_workflows_property_fewer_workspaces_keep_'
      'fewer', () {
    final Random random = seededRandom(95123);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int usageSeed = random.nextInt(_seedSpan);
      final WorkflowUsage wider = seedLinkedWorkflowUsage(
        seededRandom(usageSeed),
      );
      final WorkflowUsage narrower = seedLinkedWorkflowUsage(
        seededRandom(usageSeed),
      );
      final Set<WorkspaceId> widerRemaining = randomWorkspaceSubset(random);
      final Set<WorkspaceId> narrowerRemaining = <WorkspaceId>{
        for (final WorkspaceId workspaceId in widerRemaining)
          if (random.nextBool()) workspaceId,
      };

      wider.workflowRepository.forgetUnseenWorkflows(widerRemaining);
      narrower.workflowRepository.forgetUnseenWorkflows(narrowerRemaining);

      expect(
        _listListedIds(wider).containsAll(_listListedIds(narrower)),
        isTrue,
      );
    }
  });

  test('test_forget_unseen_workflows_property_no_workspace_left_keeps_'
      'only_everywhere_or_used', () {
    final Random random = seededRandom(95124);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);

      usage.workflowRepository.forgetUnseenWorkflows(const <WorkspaceId>{});

      for (final Workflow listed in usage.workflowRepository.listWorkflows()) {
        final bool isEverywhere = listed.availability is AllWorkspaces;
        final bool isUsed = isUsedByWork(usage.work, listed.id);
        expect(isEverywhere || isUsed, isTrue, reason: listed.id.value);
      }
    }
  });

  test('test_is_in_use_property_unlinked_forgets_used_unseen_ones', () {
    final Random random = seededRandom(95125);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedWorkflowUsage(random);
      final Set<WorkspaceId> remaining = randomWorkspaceSubset(random);
      final Set<WorkflowId> unseen = _listUnseenIds(usage, remaining);

      usage.workflowRepository.forgetUnseenWorkflows(remaining);

      final List<Workflow> kept = <Workflow>[
        for (final Workflow workflow in usage.workflows)
          if (!unseen.contains(workflow.id)) workflow,
      ];
      expect(usage.workflowRepository.listWorkflows(), orderedEquals(kept));
      expect(
        usage.approvalRepository.listApprovals(),
        orderedEquals(usage.approvals),
      );
    }
  });

  test('test_remove_workflows_property_notifies_workflow_listeners_'
      'once', () async {
    final Random random = seededRandom(95126);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final Set<WorkspaceId> remaining = randomWorkspaceSubset(random);
      final Set<WorkflowId> removed = _listServerRemovedIds(usage, remaining);
      final NotificationCounter notifications = NotificationCounter();
      usage.workflowRepository.addListener(notifications.record);

      usage.workflowRepository.forgetUnseenWorkflows(remaining);

      expect(notifications.count, lessThanOrEqualTo(1));
      if (removed.isNotEmpty) {
        expect(notifications.count, 1);
      }
    }
  });

  test('test_remove_workflows_property_removed_ones_are_not_found', () async {
    final Random random = seededRandom(95127);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final Set<WorkspaceId> remaining = randomWorkspaceSubset(random);
      final Set<WorkflowId> removed = _listServerRemovedIds(usage, remaining);

      usage.workflowRepository.forgetUnseenWorkflows(remaining);

      for (final WorkflowId workflowId in removed) {
        expect(
          () => usage.workflowRepository.findWorkflow(workflowId),
          throwsA(isA<RecordNotFound>()),
        );
        await expectLater(
          usage.workflowRepository.deleteWorkflow(workflowId),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
  });

  test('test_remove_workflows_property_listing_cannot_be_changed', () {
    final Random random = seededRandom(95128);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);

      usage.workflowRepository.forgetUnseenWorkflows(
        randomWorkspaceSubset(random),
      );

      final List<Workflow> listed = usage.workflowRepository.listWorkflows();
      final List<ApprovalRequest> approvals = usage.approvalRepository
          .listApprovals();
      expect(() => listed.add(usage.workflows.first), throwsUnsupportedError);
      expect(approvals.clear, throwsUnsupportedError);
    }
  });

  test('test_remove_workflows_property_unlisted_signing_survives', () async {
    final Random random = seededRandom(95129);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final List<Workflow> free = listWorkflowsFreeOfWork(usage);
      if (free.isEmpty) {
        continue;
      }

      await usage.workflowRepository.deleteWorkflow(pickOne(random, free).id);
      usage.workflowRepository.forgetUnseenWorkflows(
        randomWorkspaceSubset(random),
      );

      final Set<WorkflowId> unlisted = <WorkflowId>{unlistedWorkflowId};
      for (final ApprovalRequest approval in usage.approvals) {
        if (asksToSignAny(approval, unlisted)) {
          final ApprovalRequest found = usage.approvalRepository.findApproval(
            approval.id,
          );
          expect(found, same(approval));
        }
      }
    }
  });
}
