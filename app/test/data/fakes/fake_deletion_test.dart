import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';

const int _deletionIterations = 40;

List<ProjectId> _listEveryProjectId(AppDependencies dependencies) {
  final List<ProjectId> projectIds = <ProjectId>[];
  for (final Workspace workspace in galleryWorkspaces) {
    final List<Project> projects = dependencies.projectRepository.listProjects(
      workspace.id,
    );
    for (final Project project in projects) {
      projectIds.add(project.id);
    }
  }
  return projectIds;
}

List<Task> _listTasksAndJobs(AppDependencies dependencies) {
  return <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
}

bool _hasActiveRun(AppDependencies dependencies, Task task) {
  return dependencies.taskRepository.listRuns(task.id).any(isRunActive);
}

void main() {
  test('test_delete_project_property_removes_exactly_that_project', () async {
    final Random random = seededRandom(7101);

    for (int i = 0; i < _deletionIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<ProjectId> before = _listEveryProjectId(dependencies);
      final ProjectId doomedId = pickOne(random, before);

      await dependencies.projectRepository.deleteProject(doomedId);

      final List<ProjectId> expected = <ProjectId>[
        for (final ProjectId projectId in before)
          if (projectId != doomedId) projectId,
      ];
      expect(_listEveryProjectId(dependencies), expected);
      expect(
        () => dependencies.projectRepository.findProject(doomedId),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_delete_project_property_unknown_projects_are_not_found', () {
    final Random random = seededRandom(7102);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectId unknownId = ProjectId('unknown-${randomText(random)}');

      expect(
        dependencies.projectRepository.deleteProject(unknownId),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test(
    'test_delete_task_property_removes_runs_unless_one_is_active',
    () async {
      final Random random = seededRandom(7103);

      for (int i = 0; i < _deletionIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final Task task = pickOne(random, _listTasksAndJobs(dependencies));
        final bool isRunning = _hasActiveRun(dependencies, task);

        if (isRunning) {
          await expectLater(
            dependencies.taskRepository.deleteTask(task.id),
            throwsA(isA<StateError>()),
          );
          expect(dependencies.taskRepository.findTask(task.id), task);
          continue;
        }

        await dependencies.taskRepository.deleteTask(task.id);
        expect(_listTasksAndJobs(dependencies), isNot(contains(task)));
        expect(dependencies.taskRepository.listRuns(task.id), isEmpty);
      }
    },
  );

  test('test_delete_job_property_deletes_only_jobs', () async {
    final Random random = seededRandom(7104);

    for (int i = 0; i < _deletionIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Task task = pickOne(random, _listTasksAndJobs(dependencies));
      final bool isJob = task.schedule != null;

      if (!isJob) {
        await expectLater(
          dependencies.jobRepository.deleteJob(task.id),
          throwsA(isA<RecordNotFound>()),
        );
        continue;
      }
      if (_hasActiveRun(dependencies, task)) {
        continue;
      }

      await dependencies.jobRepository.deleteJob(task.id);
      expect(dependencies.jobRepository.listJobs(), isNot(contains(task)));
    }
  });

  test('test_delete_workflow_property_removes_exactly_that_one', () async {
    final Random random = seededRandom(7105);

    for (int i = 0; i < _deletionIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workflow doomed = pickOne(random, galleryWorkflows);

      await dependencies.workflowRepository.deleteWorkflow(doomed.id);

      final List<WorkflowId> remaining = <WorkflowId>[
        for (final Workflow workflow
            in dependencies.workflowRepository.listWorkflows())
          workflow.id,
      ];
      expect(remaining, isNot(contains(doomed.id)));
      expect(remaining.length, galleryWorkflows.length - 1);
    }
  });

  test('test_delete_workspace_property_never_deletes_the_last', () async {
    final Random random = seededRandom(7106);

    for (int i = 0; i < _deletionIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Workspace> shuffled = <Workspace>[...galleryWorkspaces]
        ..shuffle(random);

      for (final Workspace doomed in shuffled.skip(1)) {
        await dependencies.workspaceRepository.deleteWorkspace(doomed.id);
        final Workspace current = dependencies.workspaceRepository
            .currentWorkspace();
        expect(current.id, isNot(doomed.id));
      }

      final Workspace last = shuffled.first;
      await expectLater(
        dependencies.workspaceRepository.deleteWorkspace(last.id),
        throwsA(isA<StateError>()),
      );
      expect(dependencies.workspaceRepository.listWorkspaces(), <Workspace>[
        last,
      ]);
    }
  });

  test('test_delete_task_property_active_runs_are_never_dropped', () async {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final Task task in _listTasksAndJobs(dependencies)) {
      final List<Run> runsBefore = dependencies.taskRepository.listRuns(
        task.id,
      );
      if (!runsBefore.any(isRunActive)) {
        continue;
      }

      await expectLater(
        dependencies.taskRepository.deleteTask(task.id),
        throwsA(isA<StateError>()),
      );
      expect(dependencies.taskRepository.listRuns(task.id), runsBefore);
    }
  });
}
