import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/shared/live_run_watch.dart';
import 'package:agent_orchestration/screens/task_run/run_failure_banner.dart';
import 'package:agent_orchestration/screens/task_run/run_log_section.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const SectionRoute _tasksRoute = SectionRoute(AppSection.tasks);

class TaskRunScreen extends StatelessWidget {
  const TaskRunScreen({
    required this.runId,
    required this.taskRepository,
    required this.workflowRepository,
    required this.projectRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final RunId runId;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final ProjectRepository projectRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return LiveRunWatch(
      runId: runId,
      taskRepository: taskRepository,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          taskRepository,
          workflowRepository,
          projectRepository,
          deviceRepository,
        ]),
        builder: _buildPage,
      ),
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Run run = taskRepository.findRun(runId);
    final Task task = taskRepository.findTask(run.taskId);
    final Workflow? workflow = findWorkflowForDoer(
      task.doer,
      workflowRepository.listWorkflows(),
    );
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );
    final DateTime now = clock.now();
    final RunFailure? failure = run.failure;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: describeRunLabel(task: task, workflow: workflow, run: run),
          summary: _describeSummary(run, task, now),
          backLink: BackLink(label: 'Tasks', onPressed: _returnToTasks),
          actions: _buildActions(context, run, task),
        ),
        if (failure != null)
          RunFailureBanner(failure: failure, deviceNames: deviceNames),
        SplitLayout(
          start: RunStepsSection(
            run: run,
            task: task,
            workflow: workflow,
            deviceNames: deviceNames,
            now: now,
          ),
          end: RunLogSection(
            run: run,
            deviceNames: deviceNames,
            thisDevice: deviceRepository.currentDevice(),
          ),
        ),
      ],
    );
  }

  List<TextSegment> _describeSummary(Run run, Task task, DateTime now) {
    final String projectName = projectRepository
        .findProject(task.projectId)
        .name;
    final String timing = describeRunTiming(run, now);

    return <TextSegment>[
      TextSegment('${task.title} · $projectName · $timing'),
    ];
  }

  List<Widget> _buildActions(BuildContext context, Run run, Task task) {
    if (isRunActive(run)) {
      return <Widget>[
        AppButton.secondary(label: 'Cancel run', onPressed: _cancelRun),
        AppButton.primary(
          label: 'Chat with agent',
          icon: AppIconKind.chat,
          onPressed: _openChat,
        ),
      ];
    }

    final Widget deleteButton = AppButton.secondary(
      label: 'Delete',
      onPressed: () => unawaited(_reviewDeletion(context, task)),
    );
    final Widget askButton = AppButton.secondary(
      label: 'Ask the agent',
      icon: AppIconKind.chat,
      onPressed: _openChat,
    );
    if (run.status == RunStatus.done) {
      return <Widget>[deleteButton, askButton];
    }

    return <Widget>[
      deleteButton,
      askButton,
      AppButton.primary(
        label: 'Retry ${findCurrentStep(run).name}',
        icon: AppIconKind.retry,
        onPressed: () => unawaited(_retryRun()),
      ),
    ];
  }

  void _returnToTasks() {
    navigation.returnTo(_tasksRoute);
  }

  Future<void> _reviewDeletion(BuildContext context, Task task) {
    final DeletionPrompt prompt = task.schedule == null
        ? describeTaskDeletion(task)
        : describeJobDeletion(task);

    return reviewDeletion(
      context: context,
      prompt: prompt,
      leavePage: _returnToTasks,
      deleteRecord: () => taskRepository.deleteTask(task.id),
    );
  }

  void _openChat() {
    navigation.openRoute(ChatRoute(runId));
  }

  void _cancelRun() {
    unawaited(taskRepository.cancelRun(runId));
  }

  Future<void> _retryRun() async {
    final Run retried = await taskRepository.retryRun(runId);
    navigation.replaceRoute(TaskRunRoute(retried.id));
  }
}
