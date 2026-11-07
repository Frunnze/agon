import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';

const String _typePrefix = 'test_build_gallery_dependencies';
const int _iterations = 12;

Set<ProjectId> _listProjectIdsIn(AppDependencies dependencies) {
  final WorkspaceId current = dependencies.workspaceRepository
      .currentWorkspace()
      .id;
  return <ProjectId>{
    for (final Project project in dependencies.projectRepository.listProjects(
      current,
    ))
      project.id,
  };
}

Future<WorkspaceId> _switchRandomly(
  Random random,
  AppDependencies dependencies,
) async {
  final List<Workspace> workspaces = dependencies.workspaceRepository
      .listWorkspaces();
  final WorkspaceId target = pickOne(random, workspaces).id;
  await dependencies.workspaceRepository.switchWorkspace(target);
  return target;
}

void main() {
  test('${_typePrefix}_property_tasks_follow_the_current_workspace', () async {
    final Random random = seededRandom(78601);
    for (int i = 0; i < _iterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final FakeTaskRepository tasks =
          dependencies.taskRepository as FakeTaskRepository;

      await _switchRandomly(random, dependencies);

      final Set<ProjectId> current = _listProjectIdsIn(dependencies);
      expect(
        dependencies.taskRepository.listTasks(),
        orderedEquals(<Task>[
          for (final Task task in tasks.listTasksAndJobs())
            if (task.schedule == null && current.contains(task.projectId))
              task,
        ]),
      );
    }
  });

  test('${_typePrefix}_property_jobs_follow_the_current_workspace', () async {
    final Random random = seededRandom(78602);
    for (int i = 0; i < _iterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();

      await _switchRandomly(random, dependencies);

      final Set<ProjectId> current = _listProjectIdsIn(dependencies);
      for (final Task job in dependencies.jobRepository.listJobs()) {
        expect(current, contains(job.projectId));
        expect(job.schedule, isNotNull);
      }
    }
  });

  test(
    '${_typePrefix}_property_task_listeners_hear_workspace_switches',
    () async {
      final Random random = seededRandom(78603);
      for (int i = 0; i < _iterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final NotificationCounter counter = NotificationCounter();
        dependencies.taskRepository.addListener(counter.record);
        final int switches = 1 + random.nextInt(3);

        for (int step = 0; step < switches; step += 1) {
          await _switchRandomly(random, dependencies);
        }

        expect(counter.count, switches);
      }
    },
  );
}
