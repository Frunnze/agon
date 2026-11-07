import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/workflow_repositories.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';
import 'support/workspace_work_picks.dart';
import 'support/workspace_work_rig.dart';

const String _typePrefix = 'test_fake_task_repository';
const int _iterations = 25;

List<TaskId> _expectVisible(WorkspaceWorkRig rig, {required bool isJob}) {
  final Set<ProjectId> current = listCurrentWorkProjectIds(rig).toSet();
  return <TaskId>[
    for (final Task task in rig.fakeTasks.listTasksAndJobs())
      if (current.contains(task.projectId) && (task.schedule != null) == isJob)
        task.id,
  ];
}

List<TaskId> _listIds(List<Task> tasks) {
  return <TaskId>[for (final Task task in tasks) task.id];
}

Future<WorkspaceWorkRig> _buildSwitchedRig(Random random) async {
  final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  return rig;
}

FakeTaskRepository _buildUnlinked(Random random) {
  final TaskSeed seed = randomTaskSeed(random);
  return buildTaskRepository(
    tasks: seed.tasks,
    runs: seed.runs,
    workflows: buildGalleryWorkflowRepository(),
  );
}

void main() {
  test('${_typePrefix}_link_places_property_workspace_switches_notify_'
      'once', () async {
    final Random random = seededRandom(77801);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final NotificationCounter counter = NotificationCounter();
      rig.fakeTasks.addListener(counter.record);
      rig.fakeTasks.linkPlaces((
        workspaceRepository: rig.workspaces,
        projectRepository: rig.fakeProjects,
      ));
      final int switches = 1 + random.nextInt(4);

      for (int step = 0; step < switches; step += 1) {
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
      }

      expect(counter.count, switches);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_link_places_property_unlinked_lists_every_'
      'record', () {
    final Random random = seededRandom(77802);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildUnlinked(random);

      expect(
        repository.listTasksAndJobsInCurrentWorkspace(),
        same(repository.listTasksAndJobs()),
      );
    }
  });

  test('${_typePrefix}_list_tasks_property_holds_plain_tasks_of_current_'
      'projects', () async {
    final Random random = seededRandom(77803);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);

      expect(
        _listIds(rig.fakeTasks.listTasks()),
        orderedEquals(_expectVisible(rig, isJob: false)),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_list_tasks_property_is_unmodifiable', () async {
    final Random random = seededRandom(77804);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);

      expect(rig.fakeTasks.listTasks().clear, throwsUnsupportedError);
      expect(
        rig.fakeTasks.listTasksAndJobsInCurrentWorkspace().clear,
        throwsUnsupportedError,
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_list_tasks_and_jobs_in_current_workspace_property_'
      'splits_into_tasks_and_jobs', () async {
    final Random random = seededRandom(77805);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      final List<TaskId> everything = _listIds(
        rig.fakeTasks.listTasksAndJobsInCurrentWorkspace(),
      );

      expect(
        everything,
        unorderedEquals(<TaskId>[
          ..._listIds(rig.fakeTasks.listTasks()),
          ..._listIds(rig.fakeJobs.listJobs()),
        ]),
      );
      expect(
        everything,
        unorderedEquals(<TaskId>[
          ..._expectVisible(rig, isJob: false),
          ..._expectVisible(rig, isJob: true),
        ]),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_refuse_draft_outside_current_workspace_property_'
      'names_the_missing_project', () async {
    final Random random = seededRandom(77806);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      final TaskDraft draft = randomWorkDraft(random, rig.projects);
      final Set<ProjectId> current = listCurrentWorkProjectIds(rig).toSet();

      if (current.contains(draft.projectId)) {
        rig.fakeTasks.refuseDraftOutsideCurrentWorkspace(draft);
      } else if (draft.projectId == missingWorkProjectId) {
        expect(
          () => rig.fakeTasks.refuseDraftOutsideCurrentWorkspace(draft),
          throwsRecordNotFoundFor(missingWorkProjectId.value),
        );
      } else {
        expect(
          () => rig.fakeTasks.refuseDraftOutsideCurrentWorkspace(draft),
          throwsStateError,
        );
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_refuse_draft_outside_current_workspace_property_'
      'unlinked_never_refuses', () {
    final Random random = seededRandom(77807);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildUnlinked(random);
      repository.refuseDraftOutsideCurrentWorkspace(randomTaskDraft(random));
    }
  });

  test(
    '${_typePrefix}_find_task_property_finds_every_visible_record',
    () async {
      final Random random = seededRandom(77808);
      for (int i = 0; i < _iterations; i += 1) {
        final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
        final List<Task> visible = rig.fakeTasks
            .listTasksAndJobsInCurrentWorkspace();

        for (final Task task in visible) {
          expect(rig.fakeTasks.findTask(task.id), same(task));
        }
        await closeWorkspaceWorkRig(rig);
      }
    },
  );

  test('${_typePrefix}_find_task_property_hidden_records_are_not_'
      'found', () async {
    final Random random = seededRandom(77809);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      final Set<TaskId> visible = _listIds(
        rig.fakeTasks.listTasksAndJobsInCurrentWorkspace(),
      ).toSet();

      for (final Task task in rig.fakeTasks.listTasksAndJobs()) {
        if (!visible.contains(task.id)) {
          expect(
            () => rig.fakeTasks.findTask(task.id),
            throwsA(isA<RecordNotFound>()),
          );
        }
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_dispose_property_stops_following_workspace_'
      'switches', () async {
    final Random random = seededRandom(77810);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final NotificationCounter counter = NotificationCounter();
      rig.workspaces.addListener(counter.record);
      await closeWorkspaceWorkRig(rig);

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));

      expect(counter.count, 1);
    }
  });

  test('${_typePrefix}_dispose_property_unlinked_disposes_cleanly', () {
    final Random random = seededRandom(77811);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildUnlinked(random);
      repository.dispose();
      expect(() => repository.addListener(_ignoreChange), throwsFlutterError);
    }
  });

  test('${_typePrefix}_dispose_property_relinked_repository_leaves_no_'
      'listener', () async {
    final Random random = seededRandom(77812);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      rig.fakeTasks.linkPlaces((
        workspaceRepository: rig.workspaces,
        projectRepository: rig.fakeProjects,
      ));
      await closeWorkspaceWorkRig(rig);

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
    }
  });

  test('${_typePrefix}_new_property_keeps_every_seeded_record', () {
    final Random random = seededRandom(77813);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildTaskRepository(
        tasks: seed.tasks,
        runs: seed.runs,
        workflows: buildGalleryWorkflowRepository(),
      );

      expect(repository.listTasksAndJobs(), orderedEquals(seed.tasks));
      for (final Run run in seed.runs) {
        expect(repository.findRun(run.id), same(run));
      }
    }
  });

  test('${_typePrefix}_new_property_copies_the_seeds', () {
    final Random random = seededRandom(77814);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final List<Task> tasks = List<Task>.of(seed.tasks);
      final FakeTaskRepository repository = buildTaskRepository(
        tasks: tasks,
        runs: seed.runs,
        workflows: buildGalleryWorkflowRepository(),
      );

      tasks.clear();

      expect(repository.listTasksAndJobs().length, seed.tasks.length);
    }
  });
}

void _ignoreChange() {}
