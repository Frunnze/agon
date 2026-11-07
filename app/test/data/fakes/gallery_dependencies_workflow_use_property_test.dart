import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_usage_checks.dart';
import 'support/workflow_usage_inputs.dart';

const int _galleryIterations = 20;

List<Task> _listGalleryWork(AppDependencies dependencies) {
  return <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
}

List<Workflow> _listGalleryWorkflowsUsed(AppDependencies dependencies) {
  final List<Task> work = _listGalleryWork(dependencies);
  final List<Workflow> used = <Workflow>[];
  for (final Workflow workflow
      in dependencies.workflowRepository.listWorkflows()) {
    if (isUsedByWork(work, workflow.id)) {
      used.add(workflow);
    }
  }
  return used;
}

List<Task> _listWorkUsing(AppDependencies dependencies, WorkflowId id) {
  final List<Task> users = <Task>[];
  for (final Task task in _listGalleryWork(dependencies)) {
    if (isUsedByWork(<Task>[task], id)) {
      users.add(task);
    }
  }
  return users;
}

bool _isAnyRunning(AppDependencies dependencies, List<Task> work) {
  for (final Task task in work) {
    final bool isRunning = dependencies.taskRepository
        .listRuns(task.id)
        .any(isRunActive);
    if (isRunning) {
      return true;
    }
  }
  return false;
}

Future<void> _deleteWork(AppDependencies dependencies, List<Task> work) async {
  for (final Task task in work) {
    if (task.schedule == null) {
      await dependencies.taskRepository.deleteTask(task.id);
    } else {
      await dependencies.jobRepository.deleteJob(task.id);
    }
  }
}

void main() {
  test('test_build_gallery_dependencies_property_used_workflows_cannot_'
      'be_deleted', () async {
    final Random random = seededRandom(95141);

    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Workflow> before = dependencies.workflowRepository
          .listWorkflows();
      final List<ApprovalRequest> approvals = dependencies.approvalRepository
          .listApprovals();
      final List<Workflow> used = _listGalleryWorkflowsUsed(dependencies);
      final Workflow refused = pickOne(random, used);

      await expectLater(
        dependencies.workflowRepository.deleteWorkflow(refused.id),
        throwsA(isA<StateError>()),
      );

      expect(
        dependencies.workflowRepository.listWorkflows(),
        orderedEquals(before),
      );
      expect(
        dependencies.approvalRepository.listApprovals(),
        orderedEquals(approvals),
      );
    }
  });

  test('test_build_gallery_dependencies_property_free_workflows_delete_'
      'with_their_signing', () async {
    final Random random = seededRandom(95142);

    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workflow picked = pickOne(
        random,
        dependencies.workflowRepository.listWorkflows(),
      );
      final List<Task> users = _listWorkUsing(dependencies, picked.id);
      if (_isAnyRunning(dependencies, users)) {
        continue;
      }
      final List<ApprovalRequest> approvals = dependencies.approvalRepository
          .listApprovals();

      await _deleteWork(dependencies, users);
      await dependencies.workflowRepository.deleteWorkflow(picked.id);

      final Set<WorkflowId> deleted = <WorkflowId>{picked.id};
      expect(
        dependencies.approvalRepository.listApprovals(),
        orderedEquals(keepApprovalsSigningNone(approvals, deleted)),
      );
      expect(
        listWorkflowIds(dependencies.workflowRepository.listWorkflows()),
        isNot(contains(picked.id)),
      );
    }
  });

  test('test_build_gallery_dependencies_property_each_build_has_its_own_'
      'links', () async {
    final Random random = seededRandom(95143);

    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies first = buildGalleryDependencies();
      final AppDependencies second = buildGalleryDependencies();
      final Workflow picked = pickOne(
        random,
        first.workflowRepository.listWorkflows(),
      );
      final List<Task> users = _listWorkUsing(first, picked.id);
      if (_isAnyRunning(first, users)) {
        continue;
      }
      final List<ApprovalRequest> approvals = second.approvalRepository
          .listApprovals();

      await _deleteWork(first, users);
      await first.workflowRepository.deleteWorkflow(picked.id);

      expect(second.workflowRepository.findWorkflow(picked.id).id, picked.id);
      expect(
        second.approvalRepository.listApprovals(),
        orderedEquals(approvals),
      );
      await expectLater(
        second.workflowRepository.deleteWorkflow(picked.id),
        users.isEmpty ? completes : throwsA(isA<StateError>()),
      );
    }
  });
}
