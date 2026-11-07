import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _retryLabel = 'Retry';
const String _cancelLabel = 'Cancel run';
const int _largestRetryRounds = 3;

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, desktopHeight);
}

Future<AppNavigation> _openRun(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
  required RunId runId,
}) {
  return pumpApp(
    tester,
    size: _randomWindowSize(random),
    route: TaskRunRoute(runId),
    dependencies: dependencies,
  );
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

List<RunId> _listRunIdsOfTask(AppDependencies dependencies, RunId runId) {
  final Run run = dependencies.taskRepository.findRun(runId);
  return <RunId>[
    for (final Run sibling in dependencies.taskRepository.listRuns(run.taskId))
      sibling.id,
  ];
}

void main() {
  testWidgets('test_retry_run_property_the_page_stays_on_the_same_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(68801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await _openRun(
        tester,
        random: random,
        dependencies: dependencies,
        runId: GalleryRunIds.release41,
      );

      await _tapButton(tester, _retryLabel);

      expect(tester.takeException(), isNull);
      expect(navigation.routes, const <AppRoute>[
        TaskRunRoute(GalleryRunIds.release41),
      ]);
      expect(find.text('release #41'), findsOneWidget);
      expect(find.text(_cancelLabel), findsOneWidget);
      final Run reopened = dependencies.taskRepository.findRun(
        GalleryRunIds.release41,
      );
      expect(isRunActive(reopened), isTrue);
    }
  });

  testWidgets('test_retry_run_property_the_task_keeps_its_runs', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(68802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<RunId> runIdsBefore = _listRunIdsOfTask(
        dependencies,
        GalleryRunIds.release41,
      );
      await _openRun(
        tester,
        random: random,
        dependencies: dependencies,
        runId: GalleryRunIds.release41,
      );

      await _tapButton(tester, _retryLabel);

      final List<RunId> runIdsAfter = _listRunIdsOfTask(
        dependencies,
        GalleryRunIds.release41,
      );
      expect(runIdsAfter, runIdsBefore);
    }
  });

  testWidgets('test_retry_run_property_cancel_and_retry_rounds_keep_the_'
      'run', (WidgetTester tester) async {
    final Random random = seededRandom(68803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final Run before = tasks.findRun(GalleryRunIds.release42);
      final AppNavigation navigation = await _openRun(
        tester,
        random: random,
        dependencies: dependencies,
        runId: GalleryRunIds.release42,
      );
      final int rounds = 1 + random.nextInt(_largestRetryRounds);

      for (int round = 0; round < rounds; round += 1) {
        await _tapButton(tester, _cancelLabel);
        expect(isRunActive(tasks.findRun(before.id)), isFalse);
        await _tapButton(tester, _retryLabel);
      }

      final Run after = tasks.findRun(before.id);
      expect(isRunActive(after), isTrue);
      expect(after.number, before.number);
      expect(navigation.currentRoute, TaskRunRoute(before.id));
      expect(find.text('release #${before.number}'), findsOneWidget);
    }
  });
}
