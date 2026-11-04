import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/run_approval_prompts.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

TaskFormOptions buildTaskFormOptionsFor({
  required AppDependencies dependencies,
  required RunnerTarget chosenTarget,
}) {
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    findPendingChange: dependencies.workflowRepository.findPendingChange,
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

Widget buildTaskRunScreen({
  required RunId runId,
  required AppDependencies dependencies,
  required AppNavigation navigation,
  required RunWindowOpener? runWindowOpener,
}) {
  return TaskRunScreen(
    runId: runId,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    projectRepository: dependencies.projectRepository,
    deviceRepository: dependencies.deviceRepository,
    approvalRepository: dependencies.approvalRepository,
    personStepRepository: dependencies.personStepRepository,
    runnerRepository: dependencies.runnerRepository,
    clock: dependencies.clock,
    navigation: navigation,
    runWindowOpener: runWindowOpener,
  );
}

Widget buildChatScreen({
  required RunId runId,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return ChatScreen(
    runId: runId,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    chatRepository: dependencies.chatRepository,
    runnerRepository: dependencies.runnerRepository,
    deviceRepository: dependencies.deviceRepository,
    navigation: navigation,
  );
}

Widget buildRunApprovalPrompts({
  required RunId runId,
  required AppDependencies dependencies,
  required Widget child,
}) {
  return RunApprovalPrompts(
    key: ValueKey<RunId>(runId),
    runId: runId,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    approvalRepository: dependencies.approvalRepository,
    deviceRepository: dependencies.deviceRepository,
    clock: dependencies.clock,
    child: child,
  );
}

Widget buildRunWindowPage({
  required RunPageRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  switch (route) {
    case TaskRunRoute(:final RunId runId):
      return buildTaskRunScreen(
        runId: runId,
        dependencies: dependencies,
        navigation: navigation,
        runWindowOpener: null,
      );
    case ChatRoute(:final RunId runId):
      return buildChatScreen(
        runId: runId,
        dependencies: dependencies,
        navigation: navigation,
      );
  }
}
