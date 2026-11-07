import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

import '../../bridge/support/random_work_json.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/job_repository_fixtures.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const String _typePrefix = 'test_node_backed_job_repository';
const int _iterations = 40;

final class _ScheduleLessNode {
  _ScheduleLessNode(this.task);

  final Map<String, Object?> task;

  String answer(String inputJson) {
    return encodeSuccessReply(<Object?>[
      <String, Object?>{
        'task': task,
        'project_name': simulatedProjectName,
        'schedule_description': '',
        'next_run_at': simulatedMoment,
        'latest_run': null,
      },
    ]);
  }
}

String _describeSchedule(Schedule schedule) {
  return jsonEncode(mapScheduleToNode(schedule).toJson());
}

void _expectValidWireSchedule(Object? wire) {
  final node.Schedule schedule = node.Schedule.fromJson(wire);
  final Schedule mapped = mapScheduleFromNode(schedule);
  expect(_describeSchedule(mapped), jsonEncode(schedule.toJson()));
}

void main() {
  test('${_typePrefix}_map_schedule_to_node_property_utc_clock_keeps_the_'
      'schedule', () async {
    final Random random = seededRandom(77401);
    final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
    for (int i = 0; i < _iterations; i += 1) {
      final JobDraft draft = randomSimulatedJobDraft(random);

      final Task created = await fixture.repository.createJob(draft);

      expect(
        jsonEncode(fixture.node.tasks[created.id.value]!['schedule']),
        _describeSchedule(draft.schedule),
      );
    }
  });

  test('${_typePrefix}_map_schedule_to_node_property_sends_valid_times_for_'
      'any_local_clock', () async {
    final Random random = seededRandom(77402);
    for (int i = 0; i < _iterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final JobFixture fixture = buildJobFixture(moment);
      final JobDraft draft = randomSimulatedJobDraft(random);

      final Task created = await fixture.repository.createJob(draft);

      final Object? wire = fixture.node.tasks[created.id.value]!['schedule'];
      _expectValidWireSchedule(wire);
      final Schedule expected = convertScheduleToUtc(
        draft.schedule,
        utcOffset: moment.timeZoneOffset,
      );
      expect(jsonEncode(wire), _describeSchedule(expected));
    }
  });

  test('${_typePrefix}_map_schedule_to_node_property_updates_send_utc_'
      'schedules', () async {
    final Random random = seededRandom(77413);
    for (int i = 0; i < _iterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final JobFixture fixture = buildJobFixture(moment);
      final Task created = await fixture.repository.createJob(
        randomSimulatedJobDraft(random),
      );
      final JobDraft changes = randomSimulatedJobDraft(random);

      await fixture.repository.updateJob(created.id, changes);

      final Schedule expected = convertScheduleToUtc(
        changes.schedule,
        utcOffset: moment.timeZoneOffset,
      );
      expect(
        jsonEncode(fixture.node.tasks[created.id.value]!['schedule']),
        _describeSchedule(expected),
      );
    }
  });

  test('${_typePrefix}_map_job_from_node_property_local_schedule_round_'
      'trips', () async {
    final Random random = seededRandom(77403);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomLocalMoment(random));
      final JobDraft draft = randomSimulatedJobDraft(random);

      final Task created = await fixture.repository.createJob(draft);
      final Task listed = fixture.repository.findJob(created.id);

      expect(
        _describeSchedule(created.schedule!),
        _describeSchedule(draft.schedule),
      );
      expect(
        _describeSchedule(listed.schedule!),
        _describeSchedule(draft.schedule),
      );
    }
  });

  test('${_typePrefix}_map_job_from_node_property_job_without_schedule_is_'
      'refused', () async {
    final Random random = seededRandom(77404);
    for (int i = 0; i < _iterations; i += 1) {
      final Map<String, Object?> task = randomTaskJson(random);
      task['schedule'] = null;
      final _ScheduleLessNode simulated = _ScheduleLessNode(task);
      final NodeBackedJobRepository repository = NodeBackedJobRepository(
        channel: buildSimulatedChannel(simulated.answer),
        workspaceRepository: buildSingleWorkspaceRepository(),
        clock: FixedClock(randomLocalMoment(random)),
      );

      await expectLater(
        repository.load(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains(task['id']! as String),
          ),
        ),
      );
      expect(repository.listJobs(), isEmpty);
    }
  });

  test('${_typePrefix}_map_job_from_node_property_out_of_range_times_are_'
      'refused', () async {
    final Random random = seededRandom(77405);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
      final String jobId = fixture.node.addTaskFromElsewhere(random);
      final int hour = Duration.hoursPerDay + random.nextInt(50);
      fixture.node.tasks[jobId]!['schedule'] = <String, Object?>{
        'every': 'day',
        'at': <String, Object?>{'hour': hour, 'minute': 0},
      };

      await expectLater(
        fixture.repository.load(),
        throwsA(isA<FormatException>()),
      );
      expect(fixture.repository.listJobs(), isEmpty);
    }
  });

  test('${_typePrefix}_map_job_from_node_property_keeps_every_task_'
      'field', () async {
    final Random random = seededRandom(77406);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
      final JobDraft draft = randomSimulatedJobDraft(random);

      final Task created = await fixture.repository.createJob(draft);

      expect(created.title, draft.task.title);
      expect(created.details, draft.task.details);
      expect(created.projectId, draft.task.projectId);
      expect(created.doer, draft.task.doer);
      expect(created.skills, draft.task.skills);
      expect(created.approvalPolicy, draft.task.approvalPolicy);
      expect(created.status, TaskStatus.toDo);
    }
  });
}
