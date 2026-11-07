import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/workflow_repositories.dart';
import 'support/task_inputs.dart';
import 'support/workflow_usage_checks.dart';
import 'support/workflow_usage_inputs.dart';

const int _largestOneAgentWorkCount = 6;
const List<WorkflowId> _candidateWorkflowIds = <WorkflowId>[
  ...sampleWorkflowIds,
  unlistedWorkflowId,
];

FakeTaskRepository _buildWorkRepository(List<Task> work) {
  return buildTaskRepository(
    tasks: work,
    runs: const <Run>[],
    workflows: buildGalleryWorkflowRepository(),
  );
}

List<WorkflowId> _listAskedWorkflowIds(Random random) {
  return <WorkflowId>[
    ..._candidateWorkflowIds,
    WorkflowId(randomText(random)),
  ];
}

Task _rescheduleWork(Task task, Schedule? schedule) {
  return Task.fromDraft(
    id: task.id,
    draft: task.toDraft(),
    schedule: schedule,
    status: task.status,
    createdAt: task.createdAt,
  );
}

List<Task> _listAsTasks(List<Task> work) {
  final List<Task> tasks = <Task>[];
  for (final Task task in work) {
    tasks.add(_rescheduleWork(task, null));
  }
  return tasks;
}

List<Task> _listAsJobs(Random random, List<Task> work) {
  final List<Task> jobs = <Task>[];
  for (final Task task in work) {
    jobs.add(_rescheduleWork(task, randomJobSchedule(random)));
  }
  return jobs;
}

void main() {
  test('test_is_workflow_in_use_property_matches_the_server_rule', () {
    final Random random = seededRandom(95131);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> work = randomWorkUsing(random, sampleWorkflowIds);
      final FakeTaskWork taskWork = buildTaskWorkOver(
        _buildWorkRepository(work),
      );

      for (final WorkflowId workflowId in _listAskedWorkflowIds(random)) {
        expect(
          taskWork.isWorkflowInUse(workflowId),
          isUsedByWork(work, workflowId),
          reason: workflowId.value,
        );
      }
    }
  });

  test('test_is_workflow_in_use_property_one_agent_work_uses_none', () {
    final Random random = seededRandom(95132);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int workCount = random.nextInt(_largestOneAgentWorkCount);
      final List<Task> work = <Task>[
        for (int index = 0; index < workCount; index += 1)
          buildWorkWithDoer(
            random,
            identifier: 'one-agent-$index',
            doer: OneAgentDoer(pickOne(random, AgentKind.values)),
            schedule: random.nextBool() ? randomJobSchedule(random) : null,
          ),
      ];
      final FakeTaskWork taskWork = buildTaskWorkOver(
        _buildWorkRepository(work),
      );

      for (final WorkflowId workflowId in _listAskedWorkflowIds(random)) {
        expect(taskWork.isWorkflowInUse(workflowId), isFalse);
      }
    }
  });

  test('test_is_workflow_in_use_property_tasks_and_jobs_count_'
      'alike', () {
    final Random random = seededRandom(95133);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> work = randomWorkUsing(random, sampleWorkflowIds);
      final FakeTaskWork asTasks = buildTaskWorkOver(
        _buildWorkRepository(_listAsTasks(work)),
      );
      final FakeTaskWork asJobs = buildTaskWorkOver(
        _buildWorkRepository(_listAsJobs(random, work)),
      );

      for (final WorkflowId workflowId in _listAskedWorkflowIds(random)) {
        expect(
          asJobs.isWorkflowInUse(workflowId),
          asTasks.isWorkflowInUse(workflowId),
        );
      }
    }
  });

  test('test_is_workflow_in_use_property_follows_deleted_work', () async {
    final Random random = seededRandom(95134);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> work = randomWorkUsing(random, sampleWorkflowIds);
      final FakeTaskRepository taskRepository = _buildWorkRepository(work);
      final FakeTaskWork taskWork = buildTaskWorkOver(taskRepository);
      final List<Task> shuffled = List<Task>.of(work);
      shuffled.shuffle(random);

      for (int index = 0; index < shuffled.length; index += 1) {
        await taskRepository.deleteTask(shuffled[index].id);
        final List<Task> remaining = shuffled.sublist(index + 1);
        for (final WorkflowId workflowId in _candidateWorkflowIds) {
          expect(
            taskWork.isWorkflowInUse(workflowId),
            isUsedByWork(remaining, workflowId),
          );
        }
      }
    }
  });
}
