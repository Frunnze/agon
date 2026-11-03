import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/screens/workflows/new_workflow_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/device_route_screens.dart';
import 'package:agent_orchestration/shell/library_route_screens.dart';
import 'package:agent_orchestration/shell/new_item_route_screens.dart';
import 'package:agent_orchestration/shell/project_route_screens.dart';
import 'package:agent_orchestration/shell/section_route_screens.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';
import 'package:agent_orchestration/shell/workflow_route_screens.dart';

bool _startsNewWork(AppRoute route) {
  if (route is NewItemFormRoute) {
    return route.kind == DraftKind.task || route.kind == DraftKind.job;
  }
  return route is NewTaskRoute ||
      route is NewJobRoute ||
      route is NewWorkflowTaskRoute;
}

bool _hasProjectsInCurrentWorkspace(AppDependencies dependencies) {
  final WorkspaceId workspaceId = dependencies.workspaceRepository
      .currentWorkspace()
      .id;
  final List<Project> projects = dependencies.projectRepository.listProjects(
    workspaceId,
  );
  return projects.isNotEmpty;
}

Widget buildRouteScreen({
  required AppRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  if (_startsNewWork(route) && !_hasProjectsInCurrentWorkspace(dependencies)) {
    return buildNewItemScreen(
      formRoute: NewItemFormRoute(DraftKind.project),
      startedFrom: null,
      dependencies: dependencies,
      navigation: navigation,
    );
  }

  switch (route) {
    case SectionRoute(:final AppSection section):
      return buildSectionScreen(
        section: section,
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewTaskRoute():
      return buildNewItemScreen(
        formRoute: NewItemFormRoute(DraftKind.task),
        startedFrom: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case EditTaskRoute():
      return buildTaskFormScreen(
        existingTask: dependencies.taskRepository.findTask(route.taskId),
        dependencies: dependencies,
        navigation: navigation,
      );
    case TaskRunRoute():
      return TaskRunScreen(
        runId: route.runId,
        taskRepository: dependencies.taskRepository,
        workflowRepository: dependencies.workflowRepository,
        projectRepository: dependencies.projectRepository,
        deviceRepository: dependencies.deviceRepository,
        approvalRepository: dependencies.approvalRepository,
        runnerRepository: dependencies.runnerRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );
    case ChatRoute():
      return ChatScreen(
        runId: route.runId,
        taskRepository: dependencies.taskRepository,
        workflowRepository: dependencies.workflowRepository,
        chatRepository: dependencies.chatRepository,
        approvalRepository: dependencies.approvalRepository,
        runnerRepository: dependencies.runnerRepository,
        deviceRepository: dependencies.deviceRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );
    case NewJobRoute():
      return buildNewItemScreen(
        formRoute: NewItemFormRoute(DraftKind.job),
        startedFrom: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case EditJobRoute():
      return buildJobFormScreen(
        existingJob: dependencies.jobRepository.findJob(route.jobId),
        dependencies: dependencies,
        navigation: navigation,
      );
    case WorkflowChangeRoute():
      return buildWorkflowChangeScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case WorkspaceSwitcherRoute():
      return buildWorkspaceSwitcherScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewProjectRoute():
      return buildNewItemScreen(
        formRoute: NewItemFormRoute(DraftKind.project),
        startedFrom: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case ProjectRoute():
      return buildProjectScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case ProjectFilesRoute():
      return buildProjectFilesScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case RepositoryFileRoute():
      return buildRepositoryFileScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewWorkflowRoute():
      return NewWorkflowScreen(navigation: navigation);
    case ManualWorkflowRoute():
      return buildManualWorkflowScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case WorkflowDraftingRoute():
      return buildWorkflowDraftingScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case WorkflowDetailRoute():
      return buildWorkflowDetailScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case WorkflowBuilderRoute():
      return buildWorkflowBuilderScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewWorkflowTaskRoute():
      return buildNewWorkflowTaskScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewSkillRoute():
      return buildNewItemScreen(
        formRoute: NewItemFormRoute(DraftKind.skill),
        startedFrom: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case SkillDetailRoute():
      return buildSkillDetailScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case EditSkillRoute():
      return buildSkillFormScreen(
        existingSkill: dependencies.skillRepository.findSkill(route.skillId),
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewRuleRoute():
      return buildNewRuleScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case NewItemFormRoute():
      return buildNewItemForm(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case RuleDetailRoute():
      return buildRuleDetailScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case EditRuleRoute():
      return buildRuleFormScreen(
        existingRule: dependencies.ruleRepository.findRule(route.ruleId),
        presetProjectId: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case RunnersSettingsRoute():
      return buildSettingsScreen(
        initialTab: SettingsTab.runners,
        dependencies: dependencies,
        navigation: navigation,
      );
    case RunnerDetailRoute():
      return buildRunnerDetailScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
    case PairingCodeRoute():
      return buildPairingCodeScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case PairingApprovalRoute():
      return buildPairingApprovalScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case SetupRoute():
      return buildSetupScreen(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      );
  }
}
