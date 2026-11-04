import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

class TaskFormScreen extends StatelessWidget {
  const TaskFormScreen({
    required this.existingTask,
    required this.initialDoer,
    required this.options,
    required this.taskRepository,
    required this.jobRepository,
    required this.navigation,
    super.key,
  });

  final Task? existingTask;
  final TaskDoer initialDoer;
  final TaskFormOptions options;
  final TaskRepository taskRepository;
  final JobRepository jobRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final Task? task = existingTask;
    final TaskFormValues initialValues = task == null
        ? TaskFormValues.blank(
            projectId: options.firstProjectId,
            doer: initialDoer,
            repeat: RepeatChoice.none,
          )
        : TaskFormValues.fromTask(task);

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: task == null ? 'New task' : 'Edit task',
          backLink: BackLink(label: 'Tasks', onPressed: navigation.closeRoute),
          actions: <Widget>[
            if (task != null)
              AppButton.secondary(
                label: 'Delete',
                onPressed: () => unawaited(_reviewDeletion(context, task)),
              ),
          ],
        ),
        TaskForm(
          initialValues: initialValues,
          options: options,
          repeatChoices: RepeatChoice.values,
          repeatHint: taskRepeatHint,
          actions: <FormAction<TaskFormValues>>[
            SubmitFormAction<TaskFormValues>(
              label: 'Save for later',
              tone: ButtonTone.secondary,
              onSubmitted: _saveForLater,
            ),
            SubmitFormAction<TaskFormValues>(
              label: 'Start now',
              tone: ButtonTone.primary,
              icon: AppIconKind.play,
              onSubmitted: _startNow,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(BuildContext context, Task task) {
    return reviewDeletion(
      context: context,
      prompt: describeTaskDeletion(task),
      leavePage: () =>
          navigation.returnTo(const SectionRoute(AppSection.tasks)),
      deleteRecord: () => taskRepository.deleteTask(task.id),
    );
  }

  Future<void> _saveForLater(TaskFormValues values) async {
    final Schedule? schedule = values.toSchedule();
    if (schedule != null) {
      await _storeJob(values, schedule);
      navigation.openSection(const SectionRoute(AppSection.jobs));
      return;
    }

    await _storeTask(values);
    navigation.closeSavedForm();
  }

  Future<void> _startNow(TaskFormValues values) async {
    final Schedule? schedule = values.toSchedule();
    final Task task = schedule == null
        ? await _storeTask(values)
        : await _storeJob(values, schedule);

    final Run run = await taskRepository.startTask(task.id);
    navigation.replaceSavedForm(TaskRunRoute(run.id));
  }

  Future<Task> _storeTask(TaskFormValues values) {
    final Task? task = existingTask;
    if (task == null) {
      return taskRepository.createTask(values.toTaskDraft());
    }
    return taskRepository.updateTask(task.id, values.toTaskDraft());
  }

  Future<Task> _storeJob(TaskFormValues values, Schedule schedule) {
    final JobDraft draft = JobDraft(
      task: values.toTaskDraft(),
      schedule: schedule,
    );
    final Task? task = existingTask;
    if (task == null) {
      return jobRepository.createJob(draft);
    }
    return jobRepository.updateJob(task.id, draft);
  }
}
