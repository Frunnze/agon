import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/random_work_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const int _sequenceIterations = 25;
const int _stepsPerSequence = 12;
const String _deviceId = 'this-device';

enum _TaskStep {
  createTask,
  startTask,
  cancelRun,
  retryRun,
  taskFromElsewhere,
  runFromElsewhere,
  runChangedElsewhere,
}

typedef _Fixture = ({
  SimulatedWorkNode node,
  NodeBackedTaskRepository repository,
  NodeBackedJobRepository jobs,
});

_Fixture _buildFixture() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(
    thisDeviceId: _deviceId,
  );
  final NodeBackedJobRepository jobs = NodeBackedJobRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
    clock: const SystemClock(),
  );
  final NodeBackedTaskRepository repository = NodeBackedTaskRepository(
    clock: const SystemClock(),
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
    livePollInterval: Duration.zero,
    jobRepository: jobs,
  );
  return (node: simulated, repository: repository, jobs: jobs);
}

List<String> _oneTimeTaskIds(SimulatedWorkNode simulated) {
  return <String>[
    for (final WireRecord task in simulated.tasks.values)
      if (!isJob(task)) task['id']! as String,
  ];
}

void _expectMirrorsNode(_Fixture fixture) {
  final List<Task> tasks = fixture.repository.listTasks();
  expect(
    tasks.map((Task task) => task.id.value),
    _oneTimeTaskIds(fixture.node),
  );

  for (final Task task in tasks) {
    final WireRecord wireTask = fixture.node.tasks[task.id.value]!;
    expect(task.status.name, node.TaskStatus.decode(wireTask['status']).name);

    final List<Run> runs = fixture.repository.listRuns(task.id);
    final Set<String> wireRunIds = <String>{
      for (final WireRecord run in fixture.node.runs.values)
        if (run['task_id'] == task.id.value) run['id']! as String,
    };
    expect(runs.map((Run run) => run.id.value).toSet(), wireRunIds);
    for (int index = 1; index < runs.length; index += 1) {
      expect(runs[index - 1].number, greaterThanOrEqualTo(runs[index].number));
    }
    for (final Run run in runs) {
      final WireRecord wireRun = fixture.node.runs[run.id.value]!;
      expect(fixture.repository.findRun(run.id).taskId, task.id);
      expect(run.chat.length, (wireRun['chat']! as List<Object?>).length);
    }
  }
}

List<Run> _allRuns(NodeBackedTaskRepository repository) {
  return <Run>[
    for (final Task task in repository.listTasks())
      ...repository.listRuns(task.id),
  ];
}

Future<void> _takeStep(Random random, _Fixture fixture, _TaskStep step) async {
  final NodeBackedTaskRepository repository = fixture.repository;
  final List<Task> tasks = repository.listTasks();
  final List<Run> runs = _allRuns(repository);

  switch (step) {
    case _TaskStep.createTask:
      await repository.createTask(randomTaskDraft(random));
    case _TaskStep.startTask:
      if (tasks.isNotEmpty) {
        await repository.startTask(pickOne(random, tasks).id);
      }
    case _TaskStep.cancelRun:
      if (runs.isNotEmpty) {
        await repository.cancelRun(pickOne(random, runs).id);
      }
    case _TaskStep.retryRun:
      if (runs.isNotEmpty) {
        await repository.retryRun(pickOne(random, runs).id);
      }
    case _TaskStep.taskFromElsewhere:
      fixture.node.addTaskFromElsewhere(random);
      await repository.applyChange(
        const node.AreaChanged(area: node.ChangeArea.tasks),
      );
    case _TaskStep.runFromElsewhere:
      if (tasks.isNotEmpty) {
        final String taskId = pickOne(random, tasks).id.value;
        final String runId = fixture.node.addRunFromElsewhere(random, taskId);
        await repository.applyChange(node.RunChanged(runId: RunId(runId)));
      }
    case _TaskStep.runChangedElsewhere:
      if (runs.isNotEmpty) {
        final RunId runId = pickOne(random, runs).id;
        fixture.node.changeRunFromElsewhere(random, runId.value);
        await repository.applyChange(node.RunChanged(runId: runId));
      }
  }
}

void main() {
  test('test_apply_change_property_repository_mirrors_the_node', () async {
    final Random random = seededRandom(9901);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      fixture.node.addTaskFromElsewhere(random);
      await fixture.repository.load();
      _expectMirrorsNode(fixture);

      for (int step = 0; step < _stepsPerSequence; step += 1) {
        await _takeStep(random, fixture, pickOne(random, _TaskStep.values));
        _expectMirrorsNode(fixture);
      }
    }
  });

  test('test_create_task_property_created_task_is_listed', () async {
    final Random random = seededRandom(9902);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);
      final Task created = await fixture.repository.createTask(draft);

      expect(fixture.repository.findTask(created.id).title, draft.title);
      expect(created.status, TaskStatus.toDo);
      expect(created.schedule, isNull);
    }
  });

  test('test_start_task_property_new_run_is_found', () async {
    final Random random = seededRandom(9903);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final Task task = await fixture.repository.createTask(
        randomTaskDraft(random),
      );
      final Run run = await fixture.repository.startTask(task.id);

      expect(fixture.repository.findRun(run.id).taskId, task.id);
      expect(fixture.repository.listRuns(task.id).first.id, run.id);
      expect(fixture.repository.findTask(task.id).status, TaskStatus.running);
    }
  });

  test('test_find_task_property_finds_each_job_and_its_runs', () async {
    final Random random = seededRandom(9909);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final node.Schedule schedule = node.Schedule.fromJson(
        randomScheduleJson(random),
      );
      final JobDraft draft = JobDraft(
        task: randomTaskDraft(random),
        schedule: mapScheduleFromNode(schedule),
      );
      final Task job = await fixture.jobs.createJob(draft);

      final Run run = await fixture.repository.startTask(job.id);

      final TaskId runTaskId = fixture.repository.findRun(run.id).taskId;
      expect(fixture.repository.findTask(runTaskId).id, job.id);
      expect(fixture.repository.findTask(job.id).schedule, isNotNull);
    }
  });

  test('test_update_task_property_keeps_id_and_takes_the_draft', () async {
    final Random random = seededRandom(9904);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final Task created = await fixture.repository.createTask(
        randomTaskDraft(random),
      );
      final TaskDraft changes = randomTaskDraft(random);

      final Task updated = await fixture.repository.updateTask(
        created.id,
        changes,
      );

      expect(updated.id, created.id);
      expect(updated.title, changes.title);
      expect(updated.details, changes.details);
      expect(updated.doer, changes.doer);
      expect(updated.runsOn, changes.runsOn);
      expect(fixture.repository.findTask(created.id).title, changes.title);
      expect(fixture.repository.listTasks().length, i + 1);
    }
  });

  test('test_create_task_property_node_refusal_is_state_error', () async {
    final Random random = seededRandom(9905);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String refusal = 'refused ${randomText(random)}';
      fixture.node.refusal = refusal;
      await expectLater(
        fixture.repository.createTask(randomTaskDraft(random)),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            refusal,
          ),
        ),
      );
      expect(fixture.repository.listTasks(), isEmpty);
    }
  });

  test('test_apply_change_property_other_areas_send_nothing', () async {
    final _Fixture fixture = _buildFixture();
    for (final node.ChangeArea area in node.ChangeArea.values) {
      if (area == node.ChangeArea.tasks) {
        continue;
      }
      await fixture.repository.applyChange(node.AreaChanged(area: area));
    }
    expect(fixture.node.receivedCommands, isEmpty);
  });

  test('test_find_run_property_unknown_run_is_record_not_found', () {
    final Random random = seededRandom(9906);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => fixture.repository.findRun(RunId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        () => fixture.repository.findTask(TaskId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_load_property_notifies_listeners_once', () async {
    final Random random = seededRandom(9907);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      fixture.node.addTaskFromElsewhere(random);
      int notifications = 0;
      fixture.repository.addListener(() => notifications += 1);

      await fixture.repository.load();

      expect(notifications, 1);
    }
  });
}
