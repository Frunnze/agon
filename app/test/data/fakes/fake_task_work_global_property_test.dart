import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import 'support/job_inputs.dart';
import 'support/notification_counter.dart';
import 'support/startable_drafts.dart';
import 'support/workspace_work_picks.dart';
import 'support/workspace_work_rig.dart';

const String _typePrefix = 'test_fake_task_work';
const int _iterations = 25;
const WorkflowId _usedWorkflowId = WorkflowId('workflow-used-elsewhere');

Task _storeWorkflowTaskLike(HiddenWorkRig built) {
  final Task task = Task.fromDraft(
    id: TaskId('${built.hidden.id.value}-workflow'),
    draft: replaceDraftDoer(
      built.hidden.toDraft(),
      const WorkflowDoer(_usedWorkflowId),
    ),
    schedule: built.hidden.schedule,
    status: TaskStatus.toDo,
    createdAt: built.hidden.createdAt,
  );
  built.rig.fakeTasks.storeTask(task);
  return task;
}

FakeTaskWork _buildWork(WorkspaceWorkRig rig) {
  return FakeTaskWork(taskRepository: rig.fakeTasks);
}

void main() {
  test('${_typePrefix}_new_property_changes_nothing', () async {
    final Random random = seededRandom(78101);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<Task> before = rig.fakeTasks.listTasksAndJobs();
      final NotificationCounter counter = NotificationCounter();
      rig.fakeTasks.addListener(counter.record);

      _buildWork(rig);

      expect(identical(rig.fakeTasks.listTasksAndJobs(), before), isTrue);
      expect(counter.count, 0);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test(
    '${_typePrefix}_new_property_two_views_of_one_repository_agree',
    () async {
      final Random random = seededRandom(78102);
      for (int i = 0; i < _iterations; i += 1) {
        final HiddenWorkRig? built = await buildHiddenWorkRig(random);
        if (built == null) {
          continue;
        }
        await built.rig.fakeTasks.startTask(built.hidden.id);
        final Set<ProjectId> projects = <ProjectId>{built.hidden.projectId};

        expect(
          _buildWork(built.rig).hasActiveRunInProjects(projects),
          _buildWork(built.rig).hasActiveRunInProjects(projects),
        );
        await closeWorkspaceWorkRig(built.rig);
      }
    },
  );

  test('${_typePrefix}_new_property_sees_work_stored_after_it', () async {
    final Random random = seededRandom(78103);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final FakeTaskWork work = _buildWork(built.rig);
      expect(work.isWorkflowInUse(_usedWorkflowId), isFalse);

      _storeWorkflowTaskLike(built);

      expect(work.isWorkflowInUse(_usedWorkflowId), isTrue);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_is_workflow_in_use_property_counts_work_of_every_'
      'workspace', () async {
    final Random random = seededRandom(78104);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Task stored = _storeWorkflowTaskLike(built);

      expect(listHiddenWork(built.rig), contains(stored));
      expect(_buildWork(built.rig).isWorkflowInUse(_usedWorkflowId), isTrue);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_is_workflow_in_use_property_one_agent_work_never_'
      'counts', () async {
    final Random random = seededRandom(78105);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);

      expect(_buildWork(rig).isWorkflowInUse(_usedWorkflowId), isFalse);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_is_workflow_in_use_property_frees_after_the_user_'
      'is_deleted', () async {
    final Random random = seededRandom(78106);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Task stored = _storeWorkflowTaskLike(built);

      await built.rig.fakeTasks.deleteTask(stored.id);

      expect(_buildWork(built.rig).isWorkflowInUse(_usedWorkflowId), isFalse);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_has_active_run_in_projects_property_sees_hidden_'
      'runs', () async {
    final Random random = seededRandom(78107);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      await built.rig.fakeTasks.startTask(built.hidden.id);

      expect(
        _buildWork(built.rig)
            .hasActiveRunInProjects(<ProjectId>{built.hidden.projectId}),
        isTrue,
      );
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_has_active_run_in_projects_property_no_projects_'
      'no_runs', () async {
    final Random random = seededRandom(78108);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      await built.rig.fakeTasks.startTask(built.hidden.id);

      expect(
        _buildWork(built.rig).hasActiveRunInProjects(const <ProjectId>{}),
        isFalse,
      );
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_has_active_run_in_projects_property_finished_runs_'
      'do_not_count', () async {
    final Random random = seededRandom(78109);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Run run = await built.rig.fakeTasks.startTask(built.hidden.id);
      await built.rig.fakeTasks.cancelRun(run.id);

      expect(
        _buildWork(built.rig)
            .hasActiveRunInProjects(<ProjectId>{built.hidden.projectId}),
        isFalse,
      );
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_remove_work_in_projects_property_removes_hidden_'
      'tasks_and_jobs', () async {
    final Random random = seededRandom(78110);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final ProjectId projectId = built.hidden.projectId;

      await _buildWork(built.rig).removeWorkInProjects(<ProjectId>{projectId});

      for (final Task task in built.rig.fakeTasks.listTasksAndJobs()) {
        expect(task.projectId, isNot(projectId));
      }
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_remove_work_in_projects_property_keeps_other_'
      'projects', () async {
    final Random random = seededRandom(78111);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final ProjectId projectId = built.hidden.projectId;
      final List<String> kept = describeTaskIds(<Task>[
        for (final Task task in built.rig.fakeTasks.listTasksAndJobs())
          if (task.projectId != projectId) task,
      ]);

      await _buildWork(built.rig).removeWorkInProjects(<ProjectId>{projectId});

      expect(describeTaskIds(built.rig.fakeTasks.listTasksAndJobs()), kept);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test(
    '${_typePrefix}_remove_work_in_projects_property_is_idempotent',
    () async {
      final Random random = seededRandom(78112);
      for (int i = 0; i < _iterations; i += 1) {
        final HiddenWorkRig? built = await buildHiddenWorkRig(random);
        if (built == null) {
          continue;
        }
        final Set<ProjectId> projects = <ProjectId>{built.hidden.projectId};
        final FakeTaskWork work = _buildWork(built.rig);
        await work.removeWorkInProjects(projects);
        final List<Task> after = built.rig.fakeTasks.listTasksAndJobs();

        await work.removeWorkInProjects(projects);

        expect(
          identical(built.rig.fakeTasks.listTasksAndJobs(), after),
          isTrue,
        );
        await closeWorkspaceWorkRig(built.rig);
      }
    },
  );
}
