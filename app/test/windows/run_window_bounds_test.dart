import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';
import '../support/run_window_harness.dart';

const int _tapsPerWindow = 8;
const List<String> _waysOutOfTheRun = <String>[
  'Tasks',
  'Delete',
  openInNewWindowLabel,
  connectClaudeCodeLabel,
];

Future<AppNavigation> _pumpWindowFor(WidgetTester tester, Run run) {
  return pumpRunWindow(
    tester,
    runId: run.id,
    dependencies: removeApprovals(buildGalleryDependencies()),
    onTopSwitch: RecordingOnTopSwitch(),
  );
}

List<Finder> _listTappableControls(WidgetTester tester) {
  final List<Finder> controls = <Finder>[];
  for (final Element element in find.byType(AppButton).evaluate()) {
    controls.add(find.byWidget(element.widget));
  }
  for (final Element element in find.byType(BackLinkButton).evaluate()) {
    controls.add(find.byWidget(element.widget));
  }
  return controls;
}

void main() {
  testWidgets('test_run_window_screen_property_shows_no_way_out_of_the_run', (
    WidgetTester tester,
  ) async {
    for (final Run run in galleryRuns) {
      await _pumpWindowFor(tester, run);

      for (final String wayOut in _waysOutOfTheRun) {
        expect(find.text(wayOut), findsNothing, reason: run.id.value);
      }
      expect(
        find.textContaining('Browse the branch'),
        findsNothing,
        reason: run.id.value,
      );
      expect(find.byType(TaskRunScreen), findsOneWidget);
    }
  });

  testWidgets('test_run_window_screen_property_every_tap_stays_on_the_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9301);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final AppNavigation navigation = await _pumpWindowFor(tester, run);

      for (int tap = 0; tap < _tapsPerWindow; tap += 1) {
        final Finder control = pickOne(random, _listTappableControls(tester));
        await tester.ensureVisible(control);
        await tester.tap(control);
        await pumpFrames(tester);

        expect(navigation.currentRoute, isA<RunPageRoute>());
        expect(tester.takeException(), isNull, reason: run.id.value);
      }
    }
  });
}
