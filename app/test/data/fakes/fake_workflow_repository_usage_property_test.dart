import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';
import 'support/workflow_usage_checks.dart';
import 'support/workflow_usage_inputs.dart';

Matcher _throwsStillUsed(Workflow workflow) {
  return throwsA(
    isA<StateError>().having(
      (StateError error) => error.message,
      'message',
      'workflow ${workflow.name} is still used by a task or job',
    ),
  );
}

Future<void> _deleteWorkUsing(
  FakeTaskRepository taskRepository,
  WorkflowId workflowId,
) async {
  for (final Task task in taskRepository.listTasksAndJobs()) {
    if (isUsedByWork(<Task>[task], workflowId)) {
      await taskRepository.deleteTask(task.id);
    }
  }
}

FakeApprovalRepository _copyApprovals(Random random, WorkflowUsage usage) {
  return FakeApprovalRepository(
    approvals: usage.approvals,
    clock: FixedClock(randomUtcMoment(random)),
    currentDeviceId: const DeviceId('copy-device'),
  );
}

void main() {
  test('test_delete_workflow_property_refuses_used_and_changes_'
      'nothing', () async {
    final Random random = seededRandom(95101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final List<Workflow> used = listWorkflowsUsedByWork(usage);
      if (used.isEmpty) {
        continue;
      }
      final Workflow refused = pickOne(random, used);
      final NotificationCounter workflowNotifications = NotificationCounter();
      final NotificationCounter approvalNotifications = NotificationCounter();
      usage.workflowRepository.addListener(workflowNotifications.record);
      usage.approvalRepository.addListener(approvalNotifications.record);

      await expectLater(
        usage.workflowRepository.deleteWorkflow(refused.id),
        _throwsStillUsed(refused),
      );

      expectWorkflowUsageUntouched(usage);
      expect(workflowNotifications.count, 0);
      expect(approvalNotifications.count, 0);
    }
  });

  test('test_delete_workflow_property_unused_goes_with_change_and_'
      'signing_approvals', () async {
    final Random random = seededRandom(95102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final List<Workflow> free = listWorkflowsFreeOfWork(usage);
      if (free.isEmpty) {
        continue;
      }
      final Workflow deleted = pickOne(random, free);

      await usage.workflowRepository.deleteWorkflow(deleted.id);

      expectOnlyWorkflowsRemoved(usage, <WorkflowId>{deleted.id});
    }
  });

  test('test_delete_workflow_property_unlinked_deletes_used_ones', () async {
    final Random random = seededRandom(95103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedWorkflowUsage(random);
      final Workflow deleted = pickOne(random, usage.workflows);

      await usage.workflowRepository.deleteWorkflow(deleted.id);

      final List<Workflow> kept = <Workflow>[
        for (final Workflow workflow in usage.workflows)
          if (workflow.id != deleted.id) workflow,
      ];
      expectStoredWorkflows(usage, kept);
      expect(usage.workflowRepository.findPendingChange(deleted.id), isNull);
      expect(
        usage.approvalRepository.listApprovals(),
        orderedEquals(usage.approvals),
      );
    }
  });

  test('test_delete_workflow_property_freed_once_its_work_is_gone', () async {
    final Random random = seededRandom(95104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final List<Workflow> used = listWorkflowsUsedByWork(usage);
      if (used.isEmpty) {
        continue;
      }
      final Workflow freed = pickOne(random, used);

      await _deleteWorkUsing(usage.taskRepository, freed.id);
      await usage.workflowRepository.deleteWorkflow(freed.id);

      expectOnlyWorkflowsRemoved(usage, <WorkflowId>{freed.id});
    }
  });

  test('test_link_work_property_changes_nothing_by_itself', () {
    final Random random = seededRandom(95105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedWorkflowUsage(random);
      final NotificationCounter workflowNotifications = NotificationCounter();
      final NotificationCounter approvalNotifications = NotificationCounter();
      usage.workflowRepository.addListener(workflowNotifications.record);
      usage.approvalRepository.addListener(approvalNotifications.record);

      usage.workflowRepository.linkWork(
        taskWork: usage.taskWork,
        approvalRepository: usage.approvalRepository,
      );

      expectWorkflowUsageUntouched(usage);
      expect(workflowNotifications.count, 0);
      expect(approvalNotifications.count, 0);
    }
  });

  test('test_link_work_property_latest_link_wins', () async {
    final Random random = seededRandom(95106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final Workflow deleted = pickOne(random, usage.workflows);
      final FakeApprovalRepository relinkedApprovals = _copyApprovals(
        random,
        usage,
      );

      usage.workflowRepository.linkWork(
        taskWork: buildEmptyTaskWork(),
        approvalRepository: relinkedApprovals,
      );
      await usage.workflowRepository.deleteWorkflow(deleted.id);

      expect(
        usage.approvalRepository.listApprovals(),
        orderedEquals(usage.approvals),
      );
      expect(
        relinkedApprovals.listApprovals(),
        orderedEquals(
          keepApprovalsSigningNone(usage.approvals, <WorkflowId>{deleted.id}),
        ),
      );
    }
  });

  test('test_link_work_property_sees_work_added_after_linking', () async {
    final Random random = seededRandom(95107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final List<Workflow> free = listWorkflowsFreeOfWork(usage);
      if (free.isEmpty) {
        continue;
      }
      final Workflow claimed = pickOne(random, free);
      final Task template = buildWorkWithDoer(
        random,
        identifier: 'template',
        doer: WorkflowDoer(claimed.id),
        schedule: null,
      );

      await usage.taskRepository.createTask(template.toDraft());

      await expectLater(
        usage.workflowRepository.deleteWorkflow(claimed.id),
        _throwsStillUsed(claimed),
      );
      expectWorkflowUsageUntouched(usage);
    }
  });

  test('test_is_in_use_property_refusal_matches_task_work', () async {
    final Random random = seededRandom(95108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedLinkedWorkflowUsage(random);
      final Workflow picked = pickOne(random, usage.workflows);
      final bool isInUse = usage.taskWork.isWorkflowInUse(picked.id);

      expect(isInUse, isUsedByWork(usage.work, picked.id));
      await expectLater(
        usage.workflowRepository.deleteWorkflow(picked.id),
        isInUse ? _throwsStillUsed(picked) : completes,
      );
    }
  });

  test('test_is_in_use_property_a_lone_job_blocks_deleting', () async {
    final Random random = seededRandom(95109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedWorkflowUsage(random);
      final Workflow picked = pickOne(random, usage.workflows);
      final Task job = buildWorkWithDoer(
        random,
        identifier: 'lone-job',
        doer: WorkflowDoer(picked.id),
        schedule: randomJobSchedule(random),
      );
      final FakeTaskRepository taskRepository = buildTaskRepository(
        tasks: <Task>[job],
        runs: const <Run>[],
        workflows: usage.workflowRepository,
      );
      usage.workflowRepository.linkWork(
        taskWork: buildTaskWorkOver(taskRepository),
        approvalRepository: usage.approvalRepository,
      );

      await expectLater(
        usage.workflowRepository.deleteWorkflow(picked.id),
        _throwsStillUsed(picked),
      );
      expect(taskRepository.listTasks(), isEmpty);
      expectWorkflowUsageUntouched(usage);
    }
  });

  test('test_is_in_use_property_one_agent_work_never_blocks', () async {
    final Random random = seededRandom(95110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowUsage usage = seedWorkflowUsage(random);
      final Workflow deleted = pickOne(random, usage.workflows);
      final Task oneAgentTask = buildWorkWithDoer(
        random,
        identifier: 'one-agent-task',
        doer: OneAgentDoer(pickOne(random, AgentKind.values)),
        schedule: random.nextBool() ? randomJobSchedule(random) : null,
      );
      final FakeTaskRepository taskRepository = buildTaskRepository(
        tasks: <Task>[oneAgentTask],
        runs: const <Run>[],
        workflows: usage.workflowRepository,
      );
      usage.workflowRepository.linkWork(
        taskWork: buildTaskWorkOver(taskRepository),
        approvalRepository: usage.approvalRepository,
      );

      await usage.workflowRepository.deleteWorkflow(deleted.id);

      expectOnlyWorkflowsRemoved(usage, <WorkflowId>{deleted.id});
    }
  });
}
