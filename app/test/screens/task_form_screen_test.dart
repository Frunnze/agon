import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

Future<AppNavigation> openNewTaskForm(
  WidgetTester tester,
  Size size,
  AppDependencies dependencies,
) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: const SectionRoute(AppSection.tasks),
    dependencies: dependencies,
  );
  navigation.openRoute(NewItemFormRoute(DraftKind.task));
  await pumpFrames(tester);
  return navigation;
}

Future<void> fillGalleryTask(WidgetTester tester) async {
  final Finder fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Clean up old feature branches');
  await tester.enterText(
    fields.at(1),
    'Delete remote branches merged over 30 days ago.\n'
    'Keep release branches.',
  );
  await tester.enterText(fields.at(2), 'git-cleanup');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFrames(tester);
}

void expectGalleryTaskForm() {
  expect(find.text('New task'), findsOneWidget);
  expect(find.text('What should be done?'), findsOneWidget);
  expect(find.text('Clean up old feature branches'), findsOneWidget);
  expect(find.text('acme-app'), findsOneWidget);
  expect(
    find.text('Each task gets its own worktree of this project.'),
    findsNothing,
  );
  expect(find.text('Claude Code'), findsOneWidget);
  expect(find.text('Any free runner'), findsOneWidget);
  expect(find.text('A workflow picks its own runners.'), findsOneWidget);
  expect(find.text('git-cleanup'), findsOneWidget);
  expect(
    find.text('Also let the agent pick automatic skills'),
    findsOneWidget,
  );
  expect(find.text('Commands'), findsOneWidget);
  expect(find.text('Ask for approval'), findsOneWidget);
  expect(find.text('Auto'), findsOneWidget);
  expect(find.text("Don't repeat"), findsOneWidget);
  expect(find.text('A task that repeats becomes a job.'), findsOneWidget);
  expect(find.text('Save for later'), findsOneWidget);
  expect(find.text('Start now'), findsOneWidget);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('new task form matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openNewTaskForm(tester, size, buildGalleryDependencies());
      await fillGalleryTask(tester);

      expectGalleryTaskForm();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('starting a new task opens its run on a fresh worktree', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await openNewTaskForm(
      tester,
      phoneSize,
      dependencies,
    );
    await fillGalleryTask(tester);

    await tester.ensureVisible(find.text('Start now'));
    await tester.tap(find.text('Start now'));
    await pumpFrames(tester);

    final Task created = dependencies.taskRepository.listTasks().first;
    expect(created.status, TaskStatus.running);
    expect(created.skills, <SkillId>[GallerySkillIds.gitCleanup]);
    expect(navigation.currentRoute, isA<TaskRunRoute>());
    expect(find.byType(TaskRunScreen), findsOneWidget);
    expect(
      find.textContaining(
        'Created worktree task/clean-up-old-feature-branches from main',
      ),
      findsOneWidget,
    );
  });

  testWidgets('starting a repeating task saves the job and runs it now', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await openNewTaskForm(
      tester,
      phoneSize,
      dependencies,
    );
    await fillGalleryTask(tester);
    await _chooseEveryHour(tester);

    await tester.ensureVisible(find.text('Start now'));
    await tester.tap(find.text('Start now'));
    await pumpFrames(tester);

    final Task job = dependencies.jobRepository.listJobs().first;
    expect(job.title, 'Clean up old feature branches');
    expect(job.schedule, isNotNull);
    expect(dependencies.taskRepository.listRuns(job.id), hasLength(1));
    expect(navigation.currentRoute, isA<TaskRunRoute>());
    expect(find.byType(TaskRunScreen), findsOneWidget);
  });

  testWidgets('saving for later adds the task to the top of the list', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openNewTaskForm(tester, desktopSize, dependencies);
    await tester.enterText(find.byType(TextField).first, 'Rotate the keys');

    await tester.ensureVisible(find.text('Save for later'));
    await tester.tap(find.text('Save for later'));
    await pumpFrames(tester);

    final Task first = dependencies.taskRepository.listTasks().first;
    expect(first.title, 'Rotate the keys');
    expect(find.text('Rotate the keys'), findsOneWidget);
    expect(find.text('1 running · 1 failed · 2 to do'), findsOneWidget);
  });

  testWidgets('an empty title is rejected before anything is saved', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openNewTaskForm(tester, phoneSize, dependencies);

    await tester.ensureVisible(find.text('Save for later'));
    await tester.tap(find.text('Save for later'));
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Write what should be done.'));

    expect(find.text('Write what should be done.'), findsOneWidget);
    expect(
      dependencies.taskRepository.listTasks().length,
      galleryTasks.length,
    );
  });

  testWidgets('test_task_form_property_repeating_edit_makes_that_task_a_job', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10051);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final bool startsNow = random.nextBool();
      final Task task = pickOne(
        random,
        _listTasksWithoutActiveRun(dependencies.taskRepository),
      );
      final int jobCount = dependencies.jobRepository.listJobs().length;
      final int runCount = dependencies.taskRepository
          .listRuns(task.id)
          .length;
      await tester.pumpWidget(const SizedBox.shrink());
      final AppNavigation navigation = await pumpApp(
        tester,
        size: phoneSize,
        route: const SectionRoute(AppSection.tasks),
        dependencies: dependencies,
      );
      navigation.openRoute(EditTaskRoute(task.id));
      await pumpFrames(tester);
      await _chooseEveryHour(tester);

      final String action = startsNow ? 'Start now' : 'Save for later';
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      await pumpFrames(tester);

      final List<Task> jobs = dependencies.jobRepository.listJobs();
      expect(jobs.length, jobCount + 1);
      expect(dependencies.jobRepository.findJob(task.id).schedule, isNotNull);
      expect(
        dependencies.taskRepository.listTasks().map((Task kept) => kept.id),
        isNot(contains(task.id)),
      );
      final int runsAfter = dependencies.taskRepository
          .listRuns(task.id)
          .length;
      expect(runsAfter, startsNow ? runCount + 1 : runCount);
      if (startsNow) {
        expect(navigation.currentRoute, isA<TaskRunRoute>());
      } else {
        expect(navigation.currentRoute, const SectionRoute(AppSection.jobs));
      }
    }
  });
}

List<Task> _listTasksWithoutActiveRun(TaskRepository repository) {
  return <Task>[
    for (final Task task in repository.listTasks())
      if (!repository.listRuns(task.id).any(isRunActive)) task,
  ];
}

Future<void> _chooseEveryHour(WidgetTester tester) async {
  await tester.ensureVisible(find.text("Don't repeat"));
  await tester.tap(find.text("Don't repeat"));
  await pumpFrames(tester);
  await tester.tap(find.text('Every hour').last);
  await pumpFrames(tester);
}
