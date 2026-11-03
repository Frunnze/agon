import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/screens/approvals/approvals_screen.dart';
import 'package:agent_orchestration/screens/jobs/jobs_screen.dart';
import 'package:agent_orchestration/screens/more/more_screen.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/screens/tasks/tasks_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/device_route_screens.dart';
import 'package:agent_orchestration/shell/library_route_screens.dart';
import 'package:agent_orchestration/shell/project_route_screens.dart';
import 'package:agent_orchestration/shell/workflow_route_screens.dart';

Widget buildSectionScreen({
  required AppSection section,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  switch (section) {
    case AppSection.approvals:
      return ApprovalsScreen(
        approvalRepository: dependencies.approvalRepository,
        personStepRepository: dependencies.personStepRepository,
        taskRepository: dependencies.taskRepository,
        workflowRepository: dependencies.workflowRepository,
        deviceRepository: dependencies.deviceRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );
    case AppSection.tasks:
      return TasksScreen(
        taskRepository: dependencies.taskRepository,
        workflowRepository: dependencies.workflowRepository,
        projectRepository: dependencies.projectRepository,
        deviceRepository: dependencies.deviceRepository,
        approvalRepository: dependencies.approvalRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );
    case AppSection.jobs:
      return JobsScreen(
        jobRepository: dependencies.jobRepository,
        workflowRepository: dependencies.workflowRepository,
        projectRepository: dependencies.projectRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );
    case AppSection.more:
      return MoreScreen(
        workspaceRepository: dependencies.workspaceRepository,
        navigation: navigation,
      );
    case AppSection.skills:
      return buildSkillsScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case AppSection.rules:
      return buildRulesScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case AppSection.settings:
      return buildSettingsScreen(
        initialTab: SettingsTab.general,
        dependencies: dependencies,
        navigation: navigation,
      );
    case AppSection.devices:
      return buildDevicesScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case AppSection.projects:
      return buildProjectsScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
    case AppSection.workflows:
      return buildWorkflowsScreen(
        dependencies: dependencies,
        navigation: navigation,
      );
  }
}
