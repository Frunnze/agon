import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/task_summary.dart';

import '../../support/random_inputs.dart';

final RegExp _summaryPartPattern = RegExp(
  r'^(\d+) (running|waiting for approval|failed|to do)$',
);

Task buildTaskWithStatus(int index, TaskStatus status) {
  return Task(
    id: TaskId('task-$index'),
    title: 'Task $index',
    details: '',
    projectId: const ProjectId('project'),
    doer: const OneAgentDoer(AgentKind.codex),
    runsOn: const AnyFreeRunner(),
    skills: const <SkillId>[],
    usesAutomaticSkills: true,
    approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
    schedule: null,
    status: status,
    createdAt: DateTime.utc(2026),
  );
}

void main() {
  test('test_describe_task_summary_property_counts_unfinished_tasks', () {
    final Random random = seededRandom(21);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int taskCount = random.nextInt(12);
      final List<Task> tasks = <Task>[];
      for (int index = 0; index < taskCount; index += 1) {
        tasks.add(
          buildTaskWithStatus(index, pickOne(random, TaskStatus.values)),
        );
      }

      final String summary = describeTaskSummary(tasks);
      final int unfinishedCount = tasks
          .where((Task task) => task.status != TaskStatus.done)
          .length;
      int countedTotal = 0;
      if (summary.isNotEmpty) {
        for (final String part in summary.split(' · ')) {
          final RegExpMatch? match = _summaryPartPattern.firstMatch(part);
          expect(match, isNotNull);
          countedTotal += int.parse(match!.group(1)!);
        }
      }

      expect(countedTotal, unfinishedCount);
    }
  });

  test('describe_task_summary matches the gallery tasks page', () {
    final List<Task> tasks = <Task>[
      buildTaskWithStatus(1, TaskStatus.running),
      buildTaskWithStatus(2, TaskStatus.toDo),
      buildTaskWithStatus(3, TaskStatus.failed),
      buildTaskWithStatus(4, TaskStatus.done),
    ];

    expect(describeTaskSummary(tasks), '1 running · 1 failed · 1 to do');
  });
}
