import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

TaskFormOptions buildTaskFormOptionsFor({
  required AppDependencies dependencies,
  required RunnerTarget chosenTarget,
}) {
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    runners: dependencies.runnerRepository.listRunners(),
    deviceNames: DeviceNames(dependencies.deviceRepository.listDevices()),
    skills: dependencies.skillRepository.listSkills(),
    chosenTarget: chosenTarget,
  );
}

Widget buildTaskFormScreen({
  required Task? existingTask,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return TaskFormScreen(
    existingTask: existingTask,
    initialDoer: defaultTaskDoer,
    options: buildTaskFormOptionsFor(
      dependencies: dependencies,
      chosenTarget: existingTask?.runsOn ?? const AnyFreeRunner(),
    ),
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
    navigation: navigation,
  );
}

Widget buildJobFormScreen({
  required Task? existingJob,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return JobFormScreen(
    existingJob: existingJob,
    options: buildTaskFormOptionsFor(
      dependencies: dependencies,
      chosenTarget: existingJob?.runsOn ?? const AnyFreeRunner(),
    ),
    jobRepository: dependencies.jobRepository,
    navigation: navigation,
  );
}
