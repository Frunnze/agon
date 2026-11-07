import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import '../../../support/workflow_repositories.dart';

const String seededTaskIdPrefix = 'seeded-task-';
const String seededRunIdPrefix = 'seeded-run-';
const String createdTaskIdPrefix = 'created-task-';
const String createdRunIdPrefix = 'created-run-';
const DeviceId taskClockDevice = GalleryDeviceIds.airLaptop;
const int _largestSeededTaskCount = 5;
const int _largestRunsPerTask = 3;
const List<String> _finishedRunStatuses = <String>[
  'done',
  'failed',
  'cancelled',
];
const List<String> _activeRunStatuses = <String>[
  'queued',
  'running',
  'waiting_for_approval',
];

final DateTime taskClockMoment = galleryNow;

typedef TaskSeed = ({List<Task> tasks, List<Run> runs});

TaskSeed randomTaskSeed(Random random) {
  final List<Task> tasks = randomSeededTasks(random);
  return (tasks: tasks, runs: randomSeededRuns(random, tasks));
}

FakeTaskRepository buildSeededTaskRepository(TaskSeed seed) {
  return buildTaskRepository(
    tasks: seed.tasks,
    runs: seed.runs,
    workflows: buildGalleryWorkflowRepository(),
  );
}

Matcher throwsRecordNotFoundFor(String identifier) {
  return throwsA(
    isA<RecordNotFound>().having(
      (RecordNotFound error) => error.identifier,
      'identifier',
      identifier,
    ),
  );
}

bool canStartDoer(WorkflowRepository workflows, TaskDoer doer) {
  if (doer is! WorkflowDoer) {
    return true;
  }
  final WorkflowId workflowId = doer.workflowId;
  final bool isSigned = workflows.findWorkflow(workflowId).signature != null;
  final WorkflowChange? unsignedChange = workflows.findPendingChange(
    workflowId,
  );
  return isSigned && unsignedChange == null;
}

Task randomSeededTask(Random random, int index) {
  return Task.fromDraft(
    id: TaskId('$seededTaskIdPrefix$index'),
    draft: randomTaskDraft(random),
    schedule: random.nextInt(3) == 0 ? randomJobSchedule(random) : null,
    status: pickOne(random, TaskStatus.values),
    createdAt: randomUtcMoment(random),
  );
}

List<Task> randomSeededTasks(Random random) {
  final int count = random.nextInt(_largestSeededTaskCount);
  return <Task>[
    for (int index = 0; index < count; index += 1)
      randomSeededTask(random, index),
  ];
}

Run buildSeededRun(
  Random random, {
  required String runId,
  required TaskId taskId,
  required int number,
  required String status,
}) {
  final Map<String, Object?> runJson = randomRunJson(random);
  runJson['id'] = runId;
  runJson['task_id'] = taskId.value;
  runJson['number'] = number;
  runJson['status'] = status;
  return mapRunFromNode(node.Run.fromJson(runJson));
}

List<Run> randomSeededRuns(Random random, List<Task> tasks) {
  final List<Run> runs = <Run>[];

  for (final Task task in tasks) {
    final int count = random.nextInt(_largestRunsPerTask + 1);
    for (int number = 1; number <= count; number += 1) {
      final bool isLatest = number == count;
      final bool isActive = isLatest && random.nextInt(3) == 0;
      final String status = isActive
          ? pickOne(random, _activeRunStatuses)
          : pickOne(random, _finishedRunStatuses);
      runs.add(
        buildSeededRun(
          random,
          runId: '$seededRunIdPrefix${task.id.value}-$number',
          taskId: task.id,
          number: number,
          status: status,
        ),
      );
    }
  }

  return runs;
}

FakeTaskRepository buildTaskRepository({
  required List<Task> tasks,
  required List<Run> runs,
  required FakeWorkflowRepository workflows,
}) {
  return FakeTaskRepository(
    tasks: tasks,
    runs: runs,
    clock: FixedClock(taskClockMoment),
    currentDeviceId: taskClockDevice,
    workflowRepository: workflows,
  );
}

String describeTask(Task task) {
  final List<String> fields = <String>[
    task.id.value,
    task.title,
    task.details,
    task.projectId.value,
    '${task.doer.hashCode}',
    task.agentPlace.name,
    '${task.skills.length}',
    '${task.usesAutomaticSkills}',
    '${task.approvalPolicy?.name}',
    '${task.schedule != null}',
    task.status.name,
    task.createdAt.toIso8601String(),
  ];
  return fields.join('|');
}

List<String> describeTasks(List<Task> tasks) {
  final List<String> descriptions = <String>[];
  for (final Task task in tasks) {
    descriptions.add(describeTask(task));
  }
  return descriptions;
}

String describeRun(Run run) {
  final List<String> fields = <String>[
    run.id.value,
    run.taskId.value,
    '${run.number}',
    run.status.name,
    '${run.steps.length}',
    '${run.finishedAt?.toIso8601String()}',
  ];
  return fields.join('|');
}

List<String> describeRuns(List<Run> runs) {
  final List<String> descriptions = <String>[];
  for (final Run run in runs) {
    descriptions.add(describeRun(run));
  }
  return descriptions;
}
