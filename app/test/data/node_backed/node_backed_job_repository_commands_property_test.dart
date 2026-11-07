import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart' show randomJobSchedule;
import 'support/job_repository_fixtures.dart';
import 'support/node_backed_harness.dart';

const String _typePrefix = 'test_node_backed_job_repository';
const int _iterations = 40;

void main() {
  test('${_typePrefix}_fetch_jobs_property_asks_for_the_current_'
      'workspace', () async {
    final Random random = seededRandom(77407);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
      await fixture.repository.load();

      final Map<String, Object?> asked = fixture.sentCommands.single;
      expect(asked['command'], 'list_jobs');
      expect(asked['workspace_id'], harnessWorkspaceId.value);
    }
  });

  test('${_typePrefix}_fetch_jobs_property_lists_node_jobs_in_local_'
      'time', () async {
    final Random random = seededRandom(77408);
    for (int i = 0; i < _iterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final JobFixture fixture = buildJobFixture(moment);
      final String jobId = fixture.node.addTaskFromElsewhere(random);
      final Schedule utcSchedule = randomJobSchedule(random);
      fixture.node.tasks[jobId]!['schedule'] = mapScheduleToNode(utcSchedule)
          .toJson();

      await fixture.repository.load();

      final Schedule expected = convertScheduleFromUtc(
        utcSchedule,
        utcOffset: moment.timeZoneOffset,
      );
      expect(
        describeSchedule(fixture.repository.findJob(TaskId(jobId)).schedule!),
        describeSchedule(expected),
      );
    }
  });

  test(
    '${_typePrefix}_create_job_property_translates_node_refusals',
    () async {
      final Random random = seededRandom(77409);
      for (int i = 0; i < _iterations; i += 1) {
        final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
        final int status = 400 + random.nextInt(100);
        final String identifier = 'missing-${random.nextInt(1000)}';
        final List<(String, TypeMatcher<Object>)> refusals =
            <(String, TypeMatcher<Object>)>[
              ('project $identifier was not found', isA<RecordNotFound>()),
              ('the app server answered $status: no', isA<AppServerRefusal>()),
              ('the task title cannot be empty', isA<StateError>()),
            ];
        final (String, TypeMatcher<Object>) refusal = pickOne(
          random,
          refusals,
        );
        fixture.node.refusal = refusal.$1;

        await expectLater(
          fixture.repository.createJob(randomSimulatedJobDraft(random)),
          throwsA(refusal.$2),
        );
        expect(fixture.repository.listJobs(), isEmpty);
      }
    },
  );

  test('${_typePrefix}_delete_job_property_removes_it_everywhere', () async {
    final Random random = seededRandom(77410);
    final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
    for (int i = 0; i < _iterations; i += 1) {
      final Task created = await fixture.repository.createJob(
        randomSimulatedJobDraft(random),
      );

      await fixture.repository.deleteJob(created.id);

      expect(fixture.node.tasks.containsKey(created.id.value), isFalse);
      expect(
        () => fixture.repository.findJob(created.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test(
    '${_typePrefix}_delete_job_property_unlisted_job_asks_nothing',
    () async {
      final Random random = seededRandom(77411);
      for (int i = 0; i < _iterations; i += 1) {
        final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
        final String jobId = fixture.node.addTaskFromElsewhere(random);

        await expectLater(
          fixture.repository.deleteJob(TaskId(jobId)),
          throwsA(isA<RecordNotFound>()),
        );
        expect(fixture.sentCommands, isEmpty);
        expect(fixture.node.tasks.containsKey(jobId), isTrue);
      }
    },
  );

  test('${_typePrefix}_delete_job_property_running_job_is_kept', () async {
    final Random random = seededRandom(77412);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = buildJobFixture(randomUtcMoment(random));
      final Task created = await fixture.repository.createJob(
        randomSimulatedJobDraft(random),
      );
      final String runId = fixture.node.addRunFromElsewhere(
        random,
        created.id.value,
      );
      fixture.node.runs[runId]!['status'] = pickOne(random, <String>[
        'queued',
        'running',
        'waiting_for_approval',
      ]);

      await expectLater(
        fixture.repository.deleteJob(created.id),
        throwsStateError,
      );
      expect(fixture.repository.findJob(created.id).id, created.id);
      expect(fixture.node.tasks.containsKey(created.id.value), isTrue);
    }
  });
}
