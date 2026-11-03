import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/screens/files/project_files_screen.dart';
import 'package:agent_orchestration/screens/files/repository_file_screen.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

Widget buildProjectsScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return ProjectsScreen(
    projectRepository: dependencies.projectRepository,
    workspaceRepository: dependencies.workspaceRepository,
    taskRepository: dependencies.taskRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildNewProjectScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return NewProjectScreen(
    projectRepository: dependencies.projectRepository,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    folderPicker: canChooseFolders(defaultTargetPlatform)
        ? dependencies.folderPicker
        : null,
    navigation: navigation,
  );
}

Widget buildProjectScreen({
  required ProjectRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return ProjectScreen(
    projectId: route.projectId,
    projectRepository: dependencies.projectRepository,
    workspaceRepository: dependencies.workspaceRepository,
    taskRepository: dependencies.taskRepository,
    ruleRepository: dependencies.ruleRepository,
    deviceRepository: dependencies.deviceRepository,
    navigation: navigation,
  );
}

Widget buildWorkspaceSwitcherScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkspaceSwitcherScreen(
    dependencies: dependencies,
    navigation: navigation,
  );
}

Widget buildProjectFilesScreen({
  required ProjectFilesRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return ProjectFilesScreen(
    route: route,
    projectRepository: dependencies.projectRepository,
    fileRepository: dependencies.fileRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildRepositoryFileScreen({
  required RepositoryFileRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return RepositoryFileScreen(
    route: route,
    projectRepository: dependencies.projectRepository,
    fileRepository: dependencies.fileRepository,
    navigation: navigation,
  );
}
