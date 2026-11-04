import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

final class _RecordingRunWindowOpener implements RunWindowOpener {
  final List<(RunId, String)> openedRuns = <(RunId, String)>[];

  @override
  void openRunWindow({required RunId runId, required String title}) {
    openedRuns.add((runId, title));
  }
}

Future<AppNavigation> _pumpRunPage(
  WidgetTester tester, {
  required Size size,
  required RunId runId,
  required RunWindowOpener? runWindowOpener,
}) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final AppNavigation navigation = AppNavigation(
    initialRoute: const SectionRoute(AppSection.tasks),
  );
  navigation.openRoute(TaskRunRoute(runId));
  useViewSize(tester, size);
  await tester.pumpWidget(
    AgentOrchestrationApp(
      key: UniqueKey(),
      dependencies: dependencies,
      navigation: navigation,
      messengerKey: GlobalKey<ScaffoldMessengerState>(),
      runWindowOpener: runWindowOpener,
    ),
  );
  await pumpFrames(tester);
  return navigation;
}

void main() {
  testWidgets('test_task_run_screen_property_new_window_needs_an_opener', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7101);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Run run = galleryRuns[random.nextInt(galleryRuns.length)];
      final bool hasOpener = random.nextBool();
      await _pumpRunPage(
        tester,
        size: hasOpener ? desktopSize : phoneSize,
        runId: run.id,
        runWindowOpener: hasOpener ? _RecordingRunWindowOpener() : null,
      );

      expect(
        find.text(openInNewWindowLabel),
        hasOpener ? findsOneWidget : findsNothing,
        reason: run.id.value,
      );
    }
  });

  testWidgets('test_task_run_screen_property_phones_hide_new_window', (
    WidgetTester tester,
  ) async {
    await _pumpRunPage(
      tester,
      size: phoneSize,
      runId: galleryRuns.first.id,
      runWindowOpener: null,
    );

    expect(find.text(openInNewWindowLabel), findsNothing);
    expect(find.byType(TaskRunScreen), findsOneWidget);
  });

  testWidgets('test_task_run_screen_property_new_window_moves_the_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7102);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Run run = galleryRuns[random.nextInt(galleryRuns.length)];
      final _RecordingRunWindowOpener opener = _RecordingRunWindowOpener();
      final AppNavigation navigation = await _pumpRunPage(
        tester,
        size: desktopSize,
        runId: run.id,
        runWindowOpener: opener,
      );

      await tester.tap(find.text(openInNewWindowLabel));
      await pumpFrames(tester);

      expect(opener.openedRuns.single.$1, run.id);
      expect(opener.openedRuns.single.$2, isNotEmpty);
      expect(navigation.currentRoute, const SectionRoute(AppSection.tasks));
    }
  });
}
