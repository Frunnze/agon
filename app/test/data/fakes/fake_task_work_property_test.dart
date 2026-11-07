import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import 'support/project_work_inputs.dart';

typedef _WorkRig = ({
  ProjectWorkSeed seed,
  FakeTaskRepository repository,
  FakeTaskWork work,
});

_WorkRig _buildRig(Random random) {
  final ProjectWorkSeed seed = randomProjectWork(random);
  final FakeTaskRepository repository = buildProjectWorkRepository(seed);
  return (
    seed: seed,
    repository: repository,
    work: buildTaskWorkOver(repository),
  );
}

bool _usesWorkflowLikeServer(ProjectWorkSeed seed, WorkflowId workflowId) {
  for (final Task task in seed.tasks) {
    final TaskDoer doer = task.doer;
    if (doer is WorkflowDoer && doer.workflowId == workflowId) {
      return true;
    }
  }
  return false;
}

List<TaskId> _listKeptWork(ProjectWorkSeed seed, Set<ProjectId> removed) {
  return <TaskId>[
    for (final Task task in seed.tasks)
      if (!removed.contains(task.projectId)) task.id,
  ];
}

Set<ProjectId> _pickIdleProjects(Random random, ProjectWorkSeed seed) {
  final Set<ProjectId> idle = <ProjectId>{};
  for (final ProjectId projectId in randomProjectSubset(random)) {
    if (!isRunningLikeServer(seed, <ProjectId>{projectId})) {
      idle.add(projectId);
    }
  }
  return idle;
}

void main() {
  test('test_has_active_run_in_projects_property_matches_the_server_'
      'rule', () {
    final Random random = seededRandom(72101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> projectIds = randomProjectSubset(random);

      expect(
        rig.work.hasActiveRunInProjects(projectIds),
        isRunningLikeServer(rig.seed, projectIds),
      );
    }
  });

  test('test_has_active_run_in_projects_property_no_projects_never_'
      'run', () {
    final Random random = seededRandom(72102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);

      expect(rig.work.hasActiveRunInProjects(<ProjectId>{}), isFalse);
    }
  });

  test('test_has_active_run_in_projects_property_grows_with_the_'
      'projects', () {
    final Random random = seededRandom(72103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> smaller = randomProjectSubset(random);
      final Set<ProjectId> larger = <ProjectId>{
        ...smaller,
        ...randomProjectSubset(random),
      };

      if (rig.work.hasActiveRunInProjects(smaller)) {
        expect(rig.work.hasActiveRunInProjects(larger), isTrue);
      }
    }
  });

  test('test_remove_work_in_projects_property_removes_exactly_that_'
      'work', () async {
    final Random random = seededRandom(72104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> removed = _pickIdleProjects(random, rig.seed);

      await rig.work.removeWorkInProjects(removed);

      expect(listWorkIds(rig.repository), _listKeptWork(rig.seed, removed));
    }
  });

  test('test_remove_work_in_projects_property_keeps_runs_of_other_'
      'projects', () async {
    final Random random = seededRandom(72105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> removed = _pickIdleProjects(random, rig.seed);

      await rig.work.removeWorkInProjects(removed);

      for (final Task task in rig.seed.tasks) {
        final List<Run> runs = rig.repository.listRuns(task.id);
        final int seededCount = rig.seed.runs
            .where((Run run) => run.taskId == task.id)
            .length;
        final bool isRemoved = removed.contains(task.projectId);
        expect(runs.length, isRemoved ? 0 : seededCount);
      }
    }
  });

  test('test_remove_work_in_projects_property_is_idempotent', () async {
    final Random random = seededRandom(72106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> removed = _pickIdleProjects(random, rig.seed);

      await rig.work.removeWorkInProjects(removed);
      final List<TaskId> afterFirst = listWorkIds(rig.repository);
      await rig.work.removeWorkInProjects(removed);

      expect(listWorkIds(rig.repository), afterFirst);
    }
  });

  test('test_is_workflow_in_use_property_matches_the_server_rule', () {
    final Random random = seededRandom(72107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final WorkflowId workflowId = pickOne(random, workWorkflowIds);

      expect(
        rig.work.isWorkflowInUse(workflowId),
        _usesWorkflowLikeServer(rig.seed, workflowId),
      );
    }
  });

  test('test_is_workflow_in_use_property_unknown_workflows_are_unused', () {
    final Random random = seededRandom(72108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final WorkflowId unknownId = WorkflowId('unknown-${randomText(random)}');

      expect(rig.work.isWorkflowInUse(unknownId), isFalse);
    }
  });

  test('test_is_workflow_in_use_property_follows_removed_work', () async {
    final Random random = seededRandom(72109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> removed = _pickIdleProjects(random, rig.seed);

      await rig.work.removeWorkInProjects(removed);

      final ProjectWorkSeed remaining = (
        tasks: rig.repository.listTasksAndJobs(),
        runs: rig.seed.runs,
      );
      for (final WorkflowId workflowId in workWorkflowIds) {
        expect(
          rig.work.isWorkflowInUse(workflowId),
          _usesWorkflowLikeServer(remaining, workflowId),
        );
      }
    }
  });

  test('test_list_tasks_and_jobs_property_jobs_count_as_workflow_'
      'users', () {
    final Random random = seededRandom(72110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      for (final Task job in rig.seed.tasks) {
        final TaskDoer doer = job.doer;
        if (job.schedule != null && doer is WorkflowDoer) {
          expect(rig.work.isWorkflowInUse(doer.workflowId), isTrue);
        }
      }
    }
  });

  test('test_list_tasks_and_jobs_property_running_jobs_count', () {
    final Random random = seededRandom(72111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      for (final Task job in rig.seed.tasks) {
        final bool isRunningJob =
            job.schedule != null &&
            rig.repository.listRuns(job.id).any(isRunActive);
        if (isRunningJob) {
          expect(
            rig.work.hasActiveRunInProjects(<ProjectId>{job.projectId}),
            isTrue,
          );
        }
      }
    }
  });

  test('test_list_tasks_and_jobs_property_jobs_leave_with_their_'
      'project', () async {
    final Random random = seededRandom(72112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkRig rig = _buildRig(random);
      final Set<ProjectId> removed = _pickIdleProjects(random, rig.seed);

      await rig.work.removeWorkInProjects(removed);

      for (final Task job in rig.repository.listTasksAndJobs()) {
        if (job.schedule != null) {
          expect(removed, isNot(contains(job.projectId)));
        }
      }
    }
  });
}
