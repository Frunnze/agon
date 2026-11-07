import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/project_inputs.dart';
import 'support/project_work_inputs.dart';
import 'support/refusals.dart';

const WorkspaceId _workWorkspaceId = WorkspaceId('work-workspace');

typedef _ProjectRig = ({
  ProjectWorkSeed seed,
  FakeTaskRepository tasks,
  FakeProjectRepository projects,
  NotificationCounter notifications,
});

_ProjectRig _buildRig(Random random) {
  final ProjectWorkSeed seed = randomProjectWork(random);
  final FakeTaskRepository tasks = buildProjectWorkRepository(seed);
  final FakeProjectRepository projects = FakeProjectRepository(
    projects: <Project>[
      for (final ProjectId projectId in workProjectIds)
        Project(
          id: projectId,
          workspaceId: _workWorkspaceId,
          name: 'name-${projectId.value}',
          repositories: randomDistinctRepositories(random),
          approvalPolicy: null,
        ),
    ],
    taskWork: buildTaskWorkOver(tasks),
  );
  final NotificationCounter notifications = NotificationCounter();
  projects.addListener(notifications.record);
  return (
    seed: seed,
    tasks: tasks,
    projects: projects,
    notifications: notifications,
  );
}

List<ProjectId> _listProjectIds(FakeProjectRepository repository) {
  return <ProjectId>[
    for (final Project project in repository.listProjects(_workWorkspaceId))
      project.id,
  ];
}

void main() {
  test('test_delete_project_property_refuses_a_project_with_a_running_'
      'task', () async {
    final Random random = seededRandom(72201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ProjectRig rig = _buildRig(random);
      final ProjectId doomedId = pickOne(random, workProjectIds);
      final bool isRunning = isRunningLikeServer(rig.seed, <ProjectId>{
        doomedId,
      });
      if (!isRunning) {
        continue;
      }
      final List<TaskId> workBefore = listWorkIds(rig.tasks);

      await expectLater(
        rig.projects.deleteProject(doomedId),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('name-${doomedId.value}'),
          ),
        ),
      );

      expect(_listProjectIds(rig.projects), workProjectIds);
      expect(listWorkIds(rig.tasks), workBefore);
      expect(rig.notifications.count, 0);
    }
  });

  test('test_delete_project_property_removes_the_project_and_its_'
      'work', () async {
    final Random random = seededRandom(72202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ProjectRig rig = _buildRig(random);
      final ProjectId doomedId = pickOne(random, workProjectIds);
      if (isRunningLikeServer(rig.seed, <ProjectId>{doomedId})) {
        continue;
      }

      await rig.projects.deleteProject(doomedId);

      expect(_listProjectIds(rig.projects), <ProjectId>[
        for (final ProjectId projectId in workProjectIds)
          if (projectId != doomedId) projectId,
      ]);
      final List<TaskId> expectedWork = <TaskId>[
        for (final Task task in rig.seed.tasks)
          if (task.projectId != doomedId) task.id,
      ];
      expect(listWorkIds(rig.tasks), expectedWork);
      expect(rig.notifications.count, 1);
    }
  });

  test('test_delete_project_property_outcome_follows_only_that_'
      'project', () async {
    final Random random = seededRandom(72203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ProjectRig rig = _buildRig(random);
      final ProjectId doomedId = pickOne(random, workProjectIds);
      final bool isRunning = isRunningLikeServer(rig.seed, <ProjectId>{
        doomedId,
      });

      final bool isRefusedDeletion = await isRefused(
        () => rig.projects.deleteProject(doomedId),
        isRefusal: refusesWithStateError,
      );

      final bool keepsDoomedWork = rig.tasks.listTasksAndJobs().any(
        (Task task) => task.projectId == doomedId,
      );
      expect(isRefusedDeletion, isRunning);
      expect(keepsDoomedWork, isRunning);
    }
  });
}
