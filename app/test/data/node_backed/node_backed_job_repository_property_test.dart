import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/notification_counter.dart';
import '../fakes/support/workspace_work_checks.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/job_repository_fixtures.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';

const String _typePrefix = 'test_node_backed_job_repository';
const int _iterations = 25;

JobFixture _buildFixture() => buildJobFixture(DateTime.utc(2026, 7, 1, 12));

Task _buildPlainTask() {
  return Task.fromDraft(
    id: const TaskId('any-task'),
    draft: randomTaskDraft(seededRandom(77399)),
    schedule: null,
    status: TaskStatus.toDo,
    createdAt: DateTime.utc(2026),
  );
}

void main() {
  test('${_typePrefix}_new_property_starts_empty_without_asking_the_'
      'node', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      expect(fixture.repository.listJobs(), isEmpty);
      expect(fixture.sentCommands, isEmpty);
      fixture.repository.dispose();
    }
  });

  test('${_typePrefix}_new_property_reloads_by_itself_after_a_workspace_'
      'switch', () async {
    final Random random = seededRandom(77301);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(describeNodeJobs(rig), unorderedEquals(describeFakeJobs(rig)));
      await closeWorkspaceWorkRig(rig);
    }
  });

  test(
    '${_typePrefix}_new_property_keeps_other_workspace_listeners',
    () async {
      final Random random = seededRandom(77302);
      for (int i = 0; i < _iterations; i += 1) {
        final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
        final NotificationCounter counter = NotificationCounter();
        rig.workspaces.addListener(counter.record);
        final int switches = 1 + random.nextInt(4);

        for (int step = 0; step < switches; step += 1) {
          await rig.workspaces.switchWorkspace(
            pickOne(random, rig.workspaceIds),
          );
        }

        expect(counter.count, switches);
        await closeWorkspaceWorkRig(rig);
      }
    },
  );

  test('${_typePrefix}_list_jobs_property_is_unmodifiable', () async {
    final Random random = seededRandom(77303);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      addOutsideWork(random, fixture.node);
      await fixture.repository.load();
      final List<Task> jobs = fixture.repository.listJobs();

      expect(() => jobs.add(_buildPlainTask()), throwsUnsupportedError);
      expect(jobs.clear, throwsUnsupportedError);
    }
  });

  test('${_typePrefix}_list_jobs_property_holds_exactly_the_scheduled_'
      'records', () async {
    final Random random = seededRandom(77304);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      addOutsideWork(random, fixture.node);
      await fixture.repository.load();

      expect(
        listRepositoryJobIds(fixture.repository),
        listSimulatedJobIds(fixture.node),
      );
      for (final Task job in fixture.repository.listJobs()) {
        expect(job.schedule, isNotNull);
      }
    }
  });

  test('${_typePrefix}_list_jobs_property_reads_without_asking_the_'
      'node', () async {
    final Random random = seededRandom(77305);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      addOutsideWork(random, fixture.node);
      await fixture.repository.load();
      final int asked = fixture.sentCommands.length;

      final List<Task> first = fixture.repository.listJobs();
      final List<Task> second = fixture.repository.listJobs();

      expect(identical(first, second), isTrue);
      expect(fixture.sentCommands.length, asked);
    }
  });

  test('${_typePrefix}_find_job_property_finds_every_listed_job', () async {
    final Random random = seededRandom(77306);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      addOutsideWork(random, fixture.node);
      await fixture.repository.load();

      for (final Task job in fixture.repository.listJobs()) {
        expect(identical(fixture.repository.findJob(job.id), job), isTrue);
      }
    }
  });

  test('${_typePrefix}_find_job_property_plain_tasks_are_not_jobs', () async {
    final Random random = seededRandom(77307);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      addOutsideWork(random, fixture.node);
      await fixture.repository.load();

      for (final WireRecord task in fixture.node.tasks.values) {
        if (!isJob(task)) {
          final TaskId taskId = TaskId(task['id']! as String);
          expect(
            () => fixture.repository.findJob(taskId),
            throwsA(isA<RecordNotFound>()),
          );
        }
      }
    }
  });

  test('${_typePrefix}_load_property_notifies_once_per_answer', () async {
    final Random random = seededRandom(77308);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      final NotificationCounter counter = NotificationCounter();
      fixture.repository.addListener(counter.record);
      final int loads = 1 + random.nextInt(4);

      for (int load = 0; load < loads; load += 1) {
        addOutsideWork(random, fixture.node);
        await fixture.repository.load();
      }

      expect(counter.count, loads);
      expect(
        listRepositoryJobIds(fixture.repository),
        listSimulatedJobIds(fixture.node),
      );
    }
  });

  test('${_typePrefix}_load_property_overlapping_loads_settle_on_the_'
      'current_workspace', () async {
    final Random random = seededRandom(77309);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final Future<void> earlier = rig.nodeJobs.load();
      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      final Future<void> later = rig.nodeJobs.load();

      await Future.wait(<Future<void>>[earlier, later]);
      await pumpEventQueue();

      expect(describeNodeJobs(rig), unorderedEquals(describeFakeJobs(rig)));
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_load_property_refusal_keeps_the_listing', () async {
    final Random random = seededRandom(77310);
    for (int i = 0; i < _iterations; i += 1) {
      final JobFixture fixture = _buildFixture();
      addOutsideWork(random, fixture.node);
      await fixture.repository.load();
      final Set<String> listed = listRepositoryJobIds(fixture.repository);
      addOutsideWork(random, fixture.node);
      fixture.node.refusal = 'the node is busy ${randomText(random)}';

      await expectLater(fixture.repository.load(), throwsStateError);
      expect(listRepositoryJobIds(fixture.repository), listed);
    }
  });
}
