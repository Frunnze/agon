import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

const SectionRoute _tasksRoute = SectionRoute(AppSection.tasks);
const String openInNewWindowLabel = 'Open in new window';

bool canLeaveRun(AppNavigation navigation) {
  return navigation.canOpen(_tasksRoute);
}

class RunPageHeader extends StatelessWidget {
  const RunPageHeader({
    required this.run,
    required this.task,
    required this.runLabel,
    required this.summary,
    required this.taskRepository,
    required this.navigation,
    required this.runWindowOpener,
    super.key,
  });

  final Run run;
  final Task task;
  final String runLabel;
  final List<TextSegment> summary;
  final TaskRepository taskRepository;
  final AppNavigation navigation;
  final RunWindowOpener? runWindowOpener;

  @override
  Widget build(BuildContext context) {
    return PageHeader(
      title: runLabel,
      summary: summary,
      backLink: _offerTasksLink(),
      actions: <Widget>[?_buildNewWindowAction(), ..._buildActions(context)],
    );
  }

  BackLink? _offerTasksLink() {
    if (!canLeaveRun(navigation)) {
      return null;
    }
    return BackLink(label: 'Tasks', onPressed: _returnToTasks);
  }

  Widget? _buildNewWindowAction() {
    final RunWindowOpener? opener = runWindowOpener;
    if (opener == null) {
      return null;
    }
    return AppButton.secondary(
      label: openInNewWindowLabel,
      icon: AppIconKind.newWindow,
      onPressed: () => _moveToNewWindow(opener),
    );
  }

  void _moveToNewWindow(RunWindowOpener opener) {
    opener.openRunWindow(runId: run.id, title: runLabel);
    _returnToTasks();
  }

  List<Widget> _buildActions(BuildContext context) {
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

    final Widget? deleteButton = _buildDeleteAction(context);
    final Widget askButton = AppButton.secondary(
      label: 'Ask the agent',
      icon: AppIconKind.chat,
      onPressed: _openChat,
    );
    if (run.status == RunStatus.done) {
      return <Widget>[?deleteButton, askButton];
    }

    return <Widget>[
      ?deleteButton,
      askButton,
      AppButton.primary(
        label: 'Retry',
        icon: AppIconKind.retry,
        onPressed: () => unawaited(_retryRun()),
      ),
    ];
  }

  Widget? _buildDeleteAction(BuildContext context) {
    if (!canLeaveRun(navigation)) {
      return null;
    }
    return AppButton.secondary(
      label: 'Delete',
      onPressed: () => unawaited(_reviewDeletion(context)),
    );
  }

  void _returnToTasks() {
    navigation.returnTo(_tasksRoute);
  }

  Future<void> _reviewDeletion(BuildContext context) {
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
    navigation.openRoute(ChatRoute(run.id));
  }

  void _cancelRun() {
    unawaited(taskRepository.cancelRun(run.id));
  }

  Future<void> _retryRun() async {
    final Run retried = await taskRepository.retryRun(run.id);
    navigation.replaceRoute(TaskRunRoute(retried.id));
  }
}
