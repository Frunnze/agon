import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/approval_inputs.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';

const String _typePrefix = 'test_fake_task_repository';
const int _largestApprovalCount = 6;

typedef _LinkedTasks = ({
  TaskSeed seed,
  FakeTaskRepository tasks,
  FakeApprovalRepository approvals,
  List<ApprovalRequest> seededApprovals,
});

List<RunId?> _runChoices(TaskSeed seed) {
  return <RunId?>[
    null,
    const RunId('run-of-nobody'),
    for (final Run run in seed.runs) run.id,
  ];
}

_LinkedTasks _buildLinkedTasks(Random random) {
  final TaskSeed seed = randomTaskSeed(random);
  final List<RunId?> runChoices = _runChoices(seed);
  final int approvalCount = random.nextInt(_largestApprovalCount);
  final List<ApprovalRequest> seededApprovals = <ApprovalRequest>[
    for (int index = 0; index < approvalCount; index += 1)
      _approvalFor(random, index, pickOne(random, runChoices)),
  ];
  final FakeTaskRepository tasks = buildSeededTaskRepository(seed);
  final FakeApprovalRepository approvals = buildApprovalRepository(
    random,
    seededApprovals,
  );
  tasks.linkApprovals(approvals);
  return (
    seed: seed,
    tasks: tasks,
    approvals: approvals,
    seededApprovals: seededApprovals,
  );
}

ApprovalRequest _approvalFor(Random random, int index, RunId? runId) {
  final ApprovalRequest base = randomApprovalWithId(random, 'approval-$index');
  return ApprovalRequest(
    id: base.id,
    runId: runId,
    action: base.action,
    requestedBy: base.requestedBy,
    requestedAt: base.requestedAt,
    decision: base.decision,
  );
}

List<ApprovalId> _approvalIds(List<ApprovalRequest> approvals) {
  return <ApprovalId>[
    for (final ApprovalRequest approval in approvals) approval.id,
  ];
}

Set<RunId> _runIdsOf(TaskSeed seed, TaskId taskId) {
  return <RunId>{
    for (final Run run in seed.runs)
      if (run.taskId == taskId) run.id,
  };
}

bool _isRunning(TaskSeed seed, TaskId taskId) {
  return seed.runs.any((Run run) => run.taskId == taskId && isRunActive(run));
}

Set<SkillId> _randomSkillIds(Random random) {
  return <SkillId>{
    for (final SkillId skillId in sampleSkillIds)
      if (random.nextBool()) skillId,
  };
}

void main() {
  test('${_typePrefix}_delete_task_property_drops_the_approvals_of_its_'
      'runs_only', () async {
    final Random random = seededRandom(91501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedTasks linked = _buildLinkedTasks(random);
      if (linked.seed.tasks.isEmpty) {
        continue;
      }
      final Task doomed = pickOne(random, linked.seed.tasks);
      final bool isRunning = _isRunning(linked.seed, doomed.id);
      final Set<RunId> removedRunIds = isRunning
          ? <RunId>{}
          : _runIdsOf(linked.seed, doomed.id);

      if (isRunning) {
        await expectLater(
          linked.tasks.deleteTask(doomed.id),
          throwsStateError,
        );
      } else {
        await linked.tasks.deleteTask(doomed.id);
      }

      expect(_approvalIds(linked.approvals.listApprovals()), <ApprovalId>[
        for (final ApprovalRequest approval in linked.seededApprovals)
          if (!removedRunIds.contains(approval.runId)) approval.id,
      ]);
    }
  });

  test('${_typePrefix}_link_approvals_property_the_latest_link_receives_'
      'the_removals', () async {
    final Random random = seededRandom(91502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedTasks linked = _buildLinkedTasks(random);
      final FakeApprovalRepository replaced = linked.approvals;
      final FakeApprovalRepository latest = buildApprovalRepository(
        random,
        linked.seededApprovals,
      );
      linked.tasks.linkApprovals(latest);

      for (final Task task in linked.seed.tasks) {
        if (!_isRunning(linked.seed, task.id)) {
          await linked.tasks.deleteTask(task.id);
        }
      }

      final Set<RunId> removedRunIds = <RunId>{
        for (final Run run in linked.seed.runs)
          if (!_isRunning(linked.seed, run.taskId)) run.id,
      };
      expect(
        _approvalIds(replaced.listApprovals()),
        _approvalIds(linked.seededApprovals),
      );
      expect(_approvalIds(latest.listApprovals()), <ApprovalId>[
        for (final ApprovalRequest approval in linked.seededApprovals)
          if (!removedRunIds.contains(approval.runId)) approval.id,
      ]);
    }
  });

  test('${_typePrefix}_forget_skills_property_drops_the_skills_from_every_'
      'task_and_job_and_notifies', () {
    final Random random = seededRandom(91503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository tasks = buildSeededTaskRepository(seed);
      final NotificationCounter notifications = NotificationCounter();
      tasks.addListener(notifications.record);
      final Set<SkillId> removed = _randomSkillIds(random);

      tasks.forgetSkills(removed);

      final List<Task> stored = tasks.listTasksAndJobs();
      expect(stored, hasLength(seed.tasks.length));
      for (int index = 0; index < stored.length; index += 1) {
        expect(stored[index].id, seed.tasks[index].id);
        expect(stored[index].skills, <SkillId>[
          for (final SkillId skillId in seed.tasks[index].skills)
            if (!removed.contains(skillId)) skillId,
        ]);
      }
      expect(notifications.count, 1);
    }
  });

  test('${_typePrefix}_forget_skills_property_keeps_untouched_tasks_'
      'identical_and_is_idempotent', () {
    final Random random = seededRandom(91504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository tasks = buildSeededTaskRepository(seed);
      final Set<SkillId> removed = _randomSkillIds(random);

      tasks.forgetSkills(removed);
      final List<Task> once = tasks.listTasksAndJobs();
      tasks.forgetSkills(removed);

      final List<Task> twice = tasks.listTasksAndJobs();
      for (int index = 0; index < seed.tasks.length; index += 1) {
        expect(twice[index], same(once[index]));
        if (!seed.tasks[index].skills.any(removed.contains)) {
          expect(once[index], same(seed.tasks[index]));
        }
      }
    }
  });

  test('${_typePrefix}_forget_skills_property_keeps_runs_and_the_split_'
      'between_tasks_and_jobs', () {
    final Random random = seededRandom(91505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository tasks = buildSeededTaskRepository(seed);
      final List<String> tasksBefore = describeTasks(tasks.listTasks());

      tasks.forgetSkills(_randomSkillIds(random));

      expect(tasks.listTasks(), hasLength(tasksBefore.length));
      for (final Task task in seed.tasks) {
        expect(
          describeRuns(tasks.listRuns(task.id)),
          describeRuns(buildSeededTaskRepository(seed).listRuns(task.id)),
        );
      }
    }
  });

  test('${_typePrefix}_delete_task_property_unlinked_repository_still_'
      'deletes_the_task_with_its_runs', () async {
    final Random random = seededRandom(91506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository tasks = buildSeededTaskRepository(seed);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final Task doomed = pickOne(random, seed.tasks);
      if (_isRunning(seed, doomed.id)) {
        continue;
      }

      await tasks.deleteTask(doomed.id);

      expect(
        tasks.listTasksAndJobs().any((Task task) => task.id == doomed.id),
        isFalse,
      );
      expect(tasks.listRuns(doomed.id), isEmpty);
    }
  });
}
