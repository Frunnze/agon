import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

import '../../bridge/support/random_work_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const int _sequenceIterations = 25;
const int _stepsPerSequence = 10;
final DateTime _localSummerNoon = DateTime(2026, 7, 1, 12);

typedef _Fixture = ({
  SimulatedWorkNode node,
  NodeBackedJobRepository repository,
});

_Fixture _buildFixture() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(thisDeviceId: 'me');
  final NodeBackedJobRepository repository = NodeBackedJobRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
    clock: FixedClock(_localSummerNoon),
  );
  return (node: simulated, repository: repository);
}

JobDraft _randomJobDraft(Random random) {
  final node.Schedule schedule = node.Schedule.fromJson(
    randomScheduleJson(random),
  );
  return JobDraft(
    task: randomTaskDraft(random),
    schedule: mapScheduleFromNode(schedule),
  );
}

List<String> _jobIds(SimulatedWorkNode simulated) {
  return <String>[
    for (final WireRecord task in simulated.tasks.values)
      if (isJob(task)) task['id']! as String,
  ];
}

void main() {
  test('test_apply_change_property_jobs_mirror_the_node', () async {
    final Random random = seededRandom(9911);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      await fixture.repository.load();

      for (int step = 0; step < _stepsPerSequence; step += 1) {
        if (random.nextBool()) {
          await fixture.repository.createJob(_randomJobDraft(random));
        } else {
          fixture.node.addTaskFromElsewhere(random);
          await fixture.repository.applyChange(
            const node.AreaChanged(area: node.ChangeArea.tasks),
          );
        }

        final List<Task> jobs = fixture.repository.listJobs();
        expect(jobs.map((Task job) => job.id.value), _jobIds(fixture.node));
        for (final Task job in jobs) {
          expect(job.schedule, isNotNull);
        }
      }
    }
  });

  test('test_create_job_property_schedule_round_trips', () async {
    final Random random = seededRandom(9912);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final JobDraft draft = _randomJobDraft(random);
      final Task created = await fixture.repository.createJob(draft);
      final Schedule schedule = fixture.repository
          .findJob(created.id)
          .schedule!;

      expect(
        mapScheduleToNode(schedule).toJson(),
        mapScheduleToNode(draft.schedule).toJson(),
      );
      expect(created.title, draft.task.title);
    }
  });

  test('test_create_job_property_node_keeps_the_schedule_in_utc', () async {
    final Random random = seededRandom(9916);
    final _Fixture fixture = _buildFixture();
    final Duration utcOffset = _localSummerNoon.timeZoneOffset;
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final JobDraft draft = _randomJobDraft(random);

      final Task created = await fixture.repository.createJob(draft);

      final Schedule utcSchedule = convertScheduleToUtc(
        draft.schedule,
        utcOffset: utcOffset,
      );
      expect(
        fixture.node.tasks[created.id.value]!['schedule'],
        mapScheduleToNode(utcSchedule).toJson(),
      );
    }
  });

  test('test_update_job_property_keeps_id_and_takes_the_schedule', () async {
    final Random random = seededRandom(9913);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final Task created = await fixture.repository.createJob(
        _randomJobDraft(random),
      );
      final JobDraft changes = _randomJobDraft(random);

      final Task updated = await fixture.repository.updateJob(
        created.id,
        changes,
      );

      expect(updated.id, created.id);
      expect(updated.title, changes.task.title);
      expect(
        mapScheduleToNode(updated.schedule!).toJson(),
        mapScheduleToNode(changes.schedule).toJson(),
      );
      expect(fixture.repository.findJob(created.id).title, changes.task.title);
      expect(fixture.repository.listJobs().length, i + 1);
    }
  });

  test('test_update_job_property_turns_a_plain_task_into_that_job', () async {
    final Random random = seededRandom(9917);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String taskId = fixture.node.addTaskFromElsewhere(random);
      fixture.node.tasks[taskId]!['schedule'] = null;
      final JobDraft draft = _randomJobDraft(random);

      final Task job = await fixture.repository.updateJob(
        TaskId(taskId),
        draft,
      );

      expect(job.id.value, taskId);
      expect(isJob(fixture.node.tasks[taskId]!), isTrue);
      expect(fixture.repository.findJob(job.id).title, draft.task.title);
      expect(
        fixture.repository.listJobs().map((Task listed) => listed.id.value),
        _jobIds(fixture.node),
      );
    }
  });

  test('test_apply_change_property_run_changes_reload_jobs', () async {
    final Random random = seededRandom(9914);
    final _Fixture fixture = _buildFixture();
    await fixture.repository.load();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      fixture.node.addTaskFromElsewhere(random);
      await fixture.repository.applyChange(
        node.RunChanged(runId: RunId(randomText(random))),
      );
      expect(
        fixture.repository.listJobs().map((Task job) => job.id.value),
        _jobIds(fixture.node),
      );
    }
  });

  test('test_find_job_property_unknown_job_is_record_not_found', () {
    final Random random = seededRandom(9915);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => fixture.repository.findJob(TaskId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
