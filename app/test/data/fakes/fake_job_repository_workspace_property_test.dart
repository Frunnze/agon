import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/job_inputs.dart';
import 'support/workspace_work_picks.dart';
import 'support/workspace_work_rig.dart';
import 'support/workspace_work_steps.dart';

const String _typePrefix = 'test_fake_job_repository';
const int _iterations = 25;
const List<WorkRigStep> _jobSteps = <WorkRigStep>[
  createJobInBoth,
  updateJobInBoth,
  deleteJobInBoth,
];

JobDraft _draftIn(Random random, WorkspaceWorkRig rig, ProjectId projectId) {
  return JobDraft(
    task: randomWorkDraftIn(random, rig, projectId),
    schedule: randomWorkJobDraft(random, rig.projects).schedule,
  );
}

List<String> _describeStored(WorkspaceWorkRig rig) {
  return describeTaskIds(rig.fakeTasks.listTasksAndJobs());
}

void main() {
  test('${_typePrefix}_list_jobs_property_agrees_with_the_node_across_'
      'workspaces', () {
    return runWorkTwinSequences(
      seed: 77701,
      iterations: _iterations,
      focus: switchWorkRigWorkspace,
      others: _jobSteps,
    );
  });

  test('${_typePrefix}_list_jobs_property_holds_the_jobs_of_current_'
      'projects', () async {
    final Random random = seededRandom(77702);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      final Set<ProjectId> current = listCurrentWorkProjectIds(rig).toSet();

      final List<TaskId> expected = <TaskId>[
        for (final Task task in rig.fakeTasks.listTasksAndJobs())
          if (task.schedule != null && current.contains(task.projectId))
            task.id,
      ];
      expect(
        rig.fakeJobs.listJobs().map((Task job) => job.id),
        orderedEquals(expected),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_list_jobs_property_never_lists_plain_tasks', () async {
    final Random random = seededRandom(77703);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      for (final WorkspaceId workspaceId in rig.workspaceIds) {
        await rig.workspaces.switchWorkspace(workspaceId);
        for (final Task job in rig.fakeJobs.listJobs()) {
          expect(job.schedule, isNotNull);
        }
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_create_job_property_agrees_with_the_node', () {
    return runWorkTwinSequences(
      seed: 77704,
      iterations: _iterations,
      focus: createJobInBoth,
      others: _jobSteps,
    );
  });

  test('${_typePrefix}_create_job_property_refuses_outside_projects_and_'
      'stores_nothing', () async {
    final Random random = seededRandom(77705);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final ProjectId? outside = pickOutsideWorkProjectId(random, rig);
      final List<String> before = _describeStored(rig);

      if (outside != null) {
        await expectLater(
          rig.fakeJobs.createJob(_draftIn(random, rig, outside)),
          throwsStateError,
        );
      }
      await expectLater(
        rig.fakeJobs.createJob(_draftIn(random, rig, missingWorkProjectId)),
        throwsA(isA<RecordNotFound>()),
      );

      expect(_describeStored(rig), before);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test(
    '${_typePrefix}_create_job_property_current_projects_are_listed',
    () async {
      final Random random = seededRandom(77706);
      for (int i = 0; i < _iterations; i += 1) {
        final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
        final List<ProjectId> current = listCurrentWorkProjectIds(rig);
        if (current.isEmpty) {
          await closeWorkspaceWorkRig(rig);
          continue;
        }

        final Task created = await rig.fakeJobs.createJob(
          _draftIn(random, rig, pickOne(random, current)),
        );

        expect(rig.fakeJobs.findJob(created.id), same(created));
        await closeWorkspaceWorkRig(rig);
      }
    },
  );

  test('${_typePrefix}_update_job_property_agrees_with_the_node', () {
    return runWorkTwinSequences(
      seed: 77707,
      iterations: _iterations,
      focus: updateJobInBoth,
      others: _jobSteps,
    );
  });

  test('${_typePrefix}_update_job_property_moves_work_from_any_workspace_'
      'into_the_current_one', () async {
    final Random random = seededRandom(77708);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<ProjectId> current = listCurrentWorkProjectIds(rig);
      final List<Task> stored = rig.fakeTasks.listTasksAndJobs();
      if (current.isEmpty || stored.isEmpty) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }
      final Task target = pickOne(random, stored);

      final Task updated = await rig.fakeJobs.updateJob(
        target.id,
        _draftIn(random, rig, pickOne(random, current)),
      );

      expect(updated.id, target.id);
      expect(updated.createdAt, target.createdAt);
      expect(rig.fakeJobs.findJob(target.id), same(updated));
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_update_job_property_refusals_change_nothing', () async {
    final Random random = seededRandom(77709);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final ProjectId? outside = pickOutsideWorkProjectId(random, rig);
      final List<Task> stored = rig.fakeTasks.listTasksAndJobs();
      if (outside == null || stored.isEmpty) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }

      await expectLater(
        rig.fakeJobs.updateJob(
          pickOne(random, stored).id,
          _draftIn(random, rig, outside),
        ),
        throwsStateError,
      );

      expect(identical(rig.fakeTasks.listTasksAndJobs(), stored), isTrue);
      await closeWorkspaceWorkRig(rig);
    }
  });
}
