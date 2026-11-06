import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_views.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/random_run_json.dart';
import '../support/random_work_json.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';

const List<WireCodec> _taskViewCodecs = <WireCodec>[
  WireCodec(
    typeName: 'task_view',
    seed: 53400,
    buildJson: randomTaskViewJson,
    decode: TaskView.fromJson,
    requiredFields: <String>{'task', 'project_name'},
    optionalFields: <String>{'latest_run'},
  ),
  WireCodec(
    typeName: 'tasks_view',
    seed: 53410,
    buildJson: randomTasksViewJson,
    decode: TasksView.fromJson,
    requiredFields: <String>{'summary', 'summary_text', 'tasks'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'job_view',
    seed: 53420,
    buildJson: randomJobViewJson,
    decode: JobView.fromJson,
    requiredFields: <String>{
      'task',
      'project_name',
      'schedule_description',
      'next_run_at',
    },
    optionalFields: <String>{'latest_run'},
  ),
];

TaskView _buildTaskView(Random random) {
  return TaskView.fromJson(randomTaskViewJson(random));
}

TasksView _buildTasksView(Random random, List<TaskView> tasks) {
  return TasksView(
    summary: TaskSummary.fromJson(randomTaskSummaryJson(random)),
    summaryText: randomHostileText(random),
    tasks: tasks,
  );
}

List<TaskView> _readTasks(TasksView view) => view.tasks;

JobView _buildJobView(Random random, DateTime nextRunAt) {
  final JobView template = JobView.fromJson(randomJobViewJson(random));
  return JobView(
    task: template.task,
    projectName: template.projectName,
    scheduleDescription: template.scheduleDescription,
    nextRunAt: nextRunAt,
    latestRun: template.latestRun,
  );
}

void main() {
  for (final WireCodec codec in _taskViewCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<TasksView, TaskView>(
      testNamePrefix: 'test_tasks_view_constructor_property_tasks',
      seed: 53430,
      buildElement: _buildTaskView,
      construct: _buildTasksView,
      readList: _readTasks,
    ),
  );

  test('test_task_view_to_json_property_keeps_the_hostile_project_name', () {
    final Random random = seededRandom(53440);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskView template = _buildTaskView(random);
      final TaskView view = TaskView(
        task: template.task,
        projectName: randomHostileText(random),
        latestRun: null,
      );

      final TaskView decodedAgain = TaskView.fromJson(
        reencodeAsJsonText(view),
      );

      expect(decodedAgain.projectName, view.projectName);
      expect(decodedAgain.task.id, view.task.id);
      expect(decodedAgain.latestRun, isNull);
    }
  });

  test('test_tasks_view_to_json_property_keeps_the_task_order', () {
    final Random random = seededRandom(53441);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<TaskView> tasks = <TaskView>[
        _buildTaskView(random),
        _buildTaskView(random),
        _buildTaskView(random),
      ];
      final TasksView view = _buildTasksView(random, tasks.reversed.toList());

      final TasksView decodedAgain = TasksView.fromJson(
        reencodeAsJsonText(view),
      );

      final List<TaskId> expectedIds = <TaskId>[];
      for (final TaskView task in tasks.reversed) {
        expectedIds.add(task.task.id);
      }
      final List<TaskId> decodedIds = <TaskId>[];
      for (final TaskView task in decodedAgain.tasks) {
        decodedIds.add(task.task.id);
      }
      expect(decodedIds, orderedEquals(expectedIds));
      expect(decodedAgain.summaryText, view.summaryText);
    }
  });

  test('test_job_view_to_json_property_writes_next_run_at_as_utc_text', () {
    final Random random = seededRandom(53442);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime nextRunAt = randomMicrosecondMoment(random);

      final JobView view = _buildJobView(random, nextRunAt);

      expectUtcMomentText(view.toJson()['next_run_at'], nextRunAt);
    }
  });

  test('test_job_view_from_json_property_'
      'reads_offset_next_run_at_as_the_same_utc_instant', () {
    final Random random = seededRandom(53443);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime nextRunAt = randomMicrosecondMoment(random).toUtc();
      final JsonObject wireJson = replaceWireField(
        randomJobViewJson(random),
        'next_run_at',
        writeMomentAtRandomOffset(random, nextRunAt),
      );

      final JobView view = JobView.fromJson(wireJson);

      expect(view.nextRunAt.isUtc, isTrue);
      expect(view.nextRunAt, equals(nextRunAt));
    }
  });
}
