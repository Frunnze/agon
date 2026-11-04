import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

typedef TaskFormOptionsBuilder = TaskFormOptions Function(
  RunnerTarget chosenTarget,
);

final class WorkDraftReview implements DraftReview {
  const WorkDraftReview({
    required this.kind,
    required this.buildOptions,
    required this.taskRepository,
    required this.jobRepository,
    required this.navigation,
  });

  final DraftKind kind;
  final TaskFormOptionsBuilder buildOptions;
  final TaskRepository taskRepository;
  final JobRepository jobRepository;
  final AppNavigation navigation;

  bool get _isJob => kind == DraftKind.job;

  @override
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks) {
    final DraftedWork work = _requireWork(item);
    final TaskFormOptions options = buildOptions(work.runsOn);
    final RepeatChoice unscheduledRepeat = _isJob
        ? RepeatChoice.weekly
        : RepeatChoice.none;

    return TaskForm(
      initialValues: TaskFormValues.fromDraftedWork(
        work: work,
        options: options,
        unscheduledRepeat: unscheduledRepeat,
      ),
      options: options,
      repeatChoices: _isJob ? jobRepeatChoices : RepeatChoice.values,
      repeatHint: _isJob ? null : taskRepeatHint,
      onRouteOpened: navigation.openRoute,
      onChanged: (TaskFormValues values) =>
          _reportReadableWork(values, callbacks),
      actions: buildReviewActions<TaskFormValues>(
        onCancelled: callbacks.onCancelled,
        onApproved: (TaskFormValues values) =>
            callbacks.onApproved(values.toDraftedWork()),
      ),
    );
  }

  @override
  Future<void> approve(DraftedItem item) async {
    final DraftedWork work = _requireWork(item);
    final Schedule? schedule = work.schedule;
    if (schedule != null) {
      await jobRepository.createJob(
        JobDraft(task: work.toTaskDraft(), schedule: schedule),
      );
      _openJobs();
      return;
    }
    if (_isJob) {
      throw StateError('The job ${work.title} has no schedule');
    }

    final Task task = await taskRepository.createTask(work.toTaskDraft());
    final Run run = await taskRepository.startTask(task.id);
    navigation.replaceRoute(TaskRunRoute(run.id));
  }

  void _reportReadableWork(
    TaskFormValues values,
    DraftFormCallbacks callbacks,
  ) {
    final bool isTimeReadable = values.describeTimeProblem() == null;
    if (isTimeReadable) {
      callbacks.onChanged(values.toDraftedWork());
    }
  }

  void _openJobs() {
    if (_isJob) {
      navigation.closeRoute();
      return;
    }
    navigation.openSection(const SectionRoute(AppSection.jobs));
  }

  DraftedWork _requireWork(DraftedItem item) {
    if (item is! DraftedWork) {
      throw ArgumentError.value(item, 'item', 'Not a task or job draft');
    }
    return item;
  }
}
