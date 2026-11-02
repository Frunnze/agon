import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';

const SectionRoute _jobsRoute = SectionRoute(AppSection.jobs);

void expectGalleryJobs() {
  expect(find.text('Jobs'), findsWidgets);
  expect(find.text('Tasks that repeat on a schedule.'), findsOneWidget);
  expect(find.text('New job'), findsOneWidget);
  expect(find.text('Nightly tests'), findsOneWidget);
  expect(find.text('acme-app · workflow nightly-tests'), findsOneWidget);
  expect(find.text('Every night at 02:00'), findsOneWidget);
  expect(find.text('Tonight 02:00'), findsOneWidget);
  expect(find.text('Update dependencies'), findsOneWidget);
  expect(find.text('Every Monday at 09:00'), findsOneWidget);
  expect(find.text('Monday 09:00'), findsOneWidget);
  expect(find.text('Retrain the ranker'), findsOneWidget);
  expect(find.text('ml-ranker · workflow train-ranker'), findsOneWidget);
  expect(find.text('Every Sunday at 03:00'), findsOneWidget);
  expect(find.text('Sunday 03:00'), findsOneWidget);
  expect(find.text('Publish the docs'), findsOneWidget);
  expect(find.text('docs · workflow docs-sync'), findsOneWidget);
  expect(find.text('Every day at 18:00'), findsOneWidget);
  expect(find.text('Today 18:00'), findsOneWidget);
  expect(find.text('Passed'), findsNWidgets(3));
  expect(find.text('Failed'), findsOneWidget);
}

Future<void> fillGalleryJob(WidgetTester tester) async {
  final Finder fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Update dependencies');
  await tester.enterText(
    fields.at(1),
    'Update npm and Swift packages.\n'
    'Open a pull request with the changes.',
  );
  await tester.enterText(fields.at(2), 'code-review');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFrames(tester);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('jobs page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _jobsRoute,
        dependencies: buildGalleryDependencies(),
      );

      expectGalleryJobs();
      expect(
        find.text('Next run'),
        size == desktopSize ? findsOne : findsNothing,
      );
    });

    testWidgets('new job form matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: _jobsRoute,
        dependencies: buildGalleryDependencies(),
      );
      navigation.openRoute(NewItemFormRoute(DraftKind.job));
      await pumpFrames(tester);
      await fillGalleryJob(tester);

      expect(find.byType(JobFormScreen), findsOneWidget);
      expect(find.text('New job'), findsOneWidget);
      expect(find.text('Update dependencies'), findsOneWidget);
      expect(find.text('code-review'), findsOneWidget);
      expect(find.text('Every week'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text("Don't repeat"), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create job'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('creating a job lists it with its schedule', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _jobsRoute,
      dependencies: dependencies,
    );
    navigation.openRoute(NewItemFormRoute(DraftKind.job));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField).first, 'Rotate secrets');

    await tester.ensureVisible(find.text('Create job'));
    await tester.tap(find.text('Create job'));
    await pumpFrames(tester);

    final Task job = dependencies.jobRepository.listJobs().first;
    expect(job.title, 'Rotate secrets');
    expect(job.schedule, isA<WeeklySchedule>());
    expect(find.text('Rotate secrets'), findsOneWidget);
    expect(navigation.currentRoute, _jobsRoute);
  });

  testWidgets('a malformed time is rejected', (WidgetTester tester) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: _jobsRoute,
      dependencies: dependencies,
    );
    navigation.openRoute(NewItemFormRoute(DraftKind.job));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField).first, 'Rotate secrets');
    await tester.enterText(find.byType(TextField).last, '9 am');

    await tester.ensureVisible(find.text('Create job'));
    await tester.tap(find.text('Create job'));
    await pumpFrames(tester);

    expect(
      find.text('Write the time as HH:MM, for example 09:00.'),
      findsOneWidget,
    );
    expect(dependencies.jobRepository.listJobs().length, 4);
  });
}
