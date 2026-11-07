import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
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

class JobFormScreen extends StatelessWidget {
  const JobFormScreen({
    required this.existingJob,
    required this.options,
    required this.jobRepository,
    required this.navigation,
    super.key,
  });

  final Task? existingJob;
  final TaskFormOptions options;
  final JobRepository jobRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final Task? job = existingJob;
    final TaskFormValues initialValues = job == null
        ? TaskFormValues.blank(
            projectId: options.firstProjectId,
            doer: defaultTaskDoer,
            repeat: RepeatChoice.weekly,
          )
        : TaskFormValues.fromTask(job);

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: job == null ? 'New job' : 'Edit job',
          backLink: BackLink(label: 'Jobs', onPressed: navigation.closeRoute),
          actions: <Widget>[
            if (job != null)
              AppButton.secondary(
                label: 'Delete',
                onPressed: () => unawaited(_reviewDeletion(context, job)),
              ),
          ],
        ),
        TaskForm(
          initialValues: initialValues,
          options: options,
          repeatChoices: jobRepeatChoices,
          onRouteOpened: navigation.openRoute,
          actions: <FormAction<TaskFormValues>>[
            LeaveFormAction<TaskFormValues>(
              label: 'Cancel',
              onPressed: navigation.closeRoute,
            ),
            SubmitFormAction<TaskFormValues>(
              label: job == null ? 'Create job' : 'Save job',
              tone: ButtonTone.primary,
              onSubmitted: _saveJob,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(BuildContext context, Task job) {
    return reviewDeletion(
      context: context,
      prompt: describeJobDeletion(job),
      navigation: navigation,
      leavePage: () =>
          navigation.returnTo(const SectionRoute(AppSection.jobs)),
      deleteRecord: () => jobRepository.deleteJob(job.id),
    );
  }

  Future<void> _saveJob(TaskFormValues values) async {
    final Schedule? schedule = values.toSchedule();
    if (schedule == null) {
      throw StateError('A job always repeats');
    }

    final JobDraft draft = JobDraft(
      task: values.toTaskDraft(),
      schedule: schedule,
    );
    final Task? job = existingJob;
    if (job == null) {
      await jobRepository.createJob(draft);
    } else {
      await jobRepository.updateJob(job.id, draft);
    }
    navigation.closeSavedForm();
  }
}
