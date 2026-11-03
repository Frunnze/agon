import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

Widget buildWorkflowsScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowsScreen(
    workflowRepository: dependencies.workflowRepository,
    workspaceRepository: dependencies.workspaceRepository,
    taskRepository: dependencies.taskRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildWorkflowDetailScreen({
  required WorkflowDetailRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowDetailScreen(
    workflowId: route.workflowId,
    workflowRepository: dependencies.workflowRepository,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildWorkflowChangeScreen({
  required WorkflowChangeRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowChangeScreen(
    workflowId: route.workflowId,
    workflowRepository: dependencies.workflowRepository,
    deviceRepository: dependencies.deviceRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget buildWorkflowDraftingScreen({
  required WorkflowDraftingRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowDraftingScreen(
    draft: route.draft,
    workflowRepository: dependencies.workflowRepository,
    deviceRepository: dependencies.deviceRepository,
    skillRepository: dependencies.skillRepository,
    navigation: navigation,
  );
}

Widget buildWorkflowBuilderScreen({
  required WorkflowBuilderRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowBuilderScreen(
    workflowId: route.workflowId,
    opening: route.opening,
    workflowRepository: dependencies.workflowRepository,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    skillRepository: dependencies.skillRepository,
    navigation: navigation,
  );
}

Widget buildManualWorkflowScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return ManualWorkflowScreen(
    workflowRepository: dependencies.workflowRepository,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    skillRepository: dependencies.skillRepository,
    navigation: navigation,
  );
}

Widget buildWorkflowTaskFormScreen({
  required WorkflowId workflowId,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return TaskFormScreen(
    existingTask: null,
    initialDoer: WorkflowDoer(workflowId),
    options: buildTaskFormOptionsFor(
      dependencies: dependencies,
      chosenTarget: const AnyFreeRunner(),
    ),
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
    navigation: navigation,
  );
}
