import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import 'workflow_repositories.dart';

FakeTaskWork buildTaskWorkOf(AppDependencies dependencies) {
  return FakeTaskWork(
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
  );
}

FakeTaskWork buildTaskWorkOver(FakeTaskRepository taskRepository) {
  return FakeTaskWork(
    taskRepository: taskRepository,
    jobRepository: FakeJobRepository(
      taskRepository: taskRepository,
      clock: FixedClock(galleryNow),
    ),
  );
}

FakeTaskRepository buildEmptyTaskRepository() {
  return FakeTaskRepository(
    tasks: const <Task>[],
    runs: const <Run>[],
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: buildGalleryWorkflowRepository(),
  );
}

FakeTaskWork buildEmptyTaskWork() {
  return buildTaskWorkOver(buildEmptyTaskRepository());
}

FakeProjectRepository buildProjectRepositoryOver(
  AppDependencies dependencies,
  List<Project> projects,
) {
  return FakeProjectRepository(
    projects: projects,
    taskWork: buildTaskWorkOf(dependencies),
  );
}

FakeWorkspaceRepository buildAcmeWorkspaceRepository() {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
}
