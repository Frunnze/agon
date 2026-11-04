import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/keep_on_top_button.dart';

import '../support/app_harness.dart';
import '../support/person_step_dependencies.dart';
import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';
import '../support/run_window_harness.dart';
import '../support/widget_harness.dart';

const double _denseControlHeight = 32;
const double _denseBodyFontSize = 14;

final TargetPlatformVariant _onMac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

AppDependencies _buildQuietDependencies() {
  return removeApprovals(
    buildDependenciesWithQuestion(notes: const <RunNote>[]),
  );
}

Future<void> _pumpReleaseWindow(
  WidgetTester tester, {
  required AppDependencies dependencies,
  required RecordingOnTopSwitch onTopSwitch,
}) async {
  await pumpRunWindow(
    tester,
    runId: GalleryRunIds.release42,
    dependencies: dependencies,
    onTopSwitch: onTopSwitch,
  );
}

String _describeLabel(AppDependencies dependencies) {
  final Run run = dependencies.taskRepository.findRun(GalleryRunIds.release42);
  final Task task = dependencies.taskRepository.findTask(run.taskId);
  final Workflow? workflow = findWorkflowForDoer(
    task.doer,
    dependencies.workflowRepository.listWorkflows(),
  );
  return describeRunLabel(task: task, workflow: workflow, run: run);
}

Future<void> _pressKeepOnTop(
  WidgetTester tester,
  RecordingOnTopSwitch onTopSwitch,
) async {
  final String label = onTopSwitch.isKeptOnTop
      ? stopKeepingOnTopLabel
      : keepOnTopLabel;
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('test_run_window_screen_property_shows_the_run_page', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = _buildQuietDependencies();
    await _pumpReleaseWindow(
      tester,
      dependencies: dependencies,
      onTopSwitch: RecordingOnTopSwitch(),
    );

    expect(find.text(_describeLabel(dependencies)), findsOneWidget);
    expect(find.text(questionText), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('plan'), findsWidgets);
    expect(find.text('Cancel run'), findsOneWidget);
    expect(find.text('Chat with agent'), findsOneWidget);
    expect(find.byType(BackLinkButton), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_keep_on_top_button_property_follows_presses_on_any_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6301);
    final RecordingOnTopSwitch onTopSwitch = RecordingOnTopSwitch();
    await _pumpReleaseWindow(
      tester,
      dependencies: _buildQuietDependencies(),
      onTopSwitch: onTopSwitch,
    );
    final int presses = 1 + random.nextInt(widgetPropertyIterations);

    for (int press = 0; press < presses; press += 1) {
      final bool isKeptOnTop = onTopSwitch.isKeptOnTop;
      await _pressKeepOnTop(tester, onTopSwitch);
      expect(onTopSwitch.isKeptOnTop, !isKeptOnTop);
      if (random.nextBool()) {
        await tester.tap(find.text('Chat with agent'));
        await pumpFrames(tester);
        await tester.tap(find.byType(BackLinkButton));
        await pumpFrames(tester);
      }
    }

    expect(onTopSwitch.switchCount, presses);
    expect(onTopSwitch.isKeptOnTop, presses.isOdd);
    final String shownLabel = presses.isOdd
        ? stopKeepingOnTopLabel
        : keepOnTopLabel;
    expect(find.text(shownLabel), findsOneWidget);
  });

  testWidgets('test_run_window_screen_property_updates_live', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = _buildQuietDependencies();
    await _pumpReleaseWindow(
      tester,
      dependencies: dependencies,
      onTopSwitch: RecordingOnTopSwitch(),
    );
    expect(find.textContaining('started', findRichText: true), findsWidgets);

    await dependencies.taskRepository.cancelRun(GalleryRunIds.release42);
    await pumpFrames(tester);

    final Run cancelled = dependencies.taskRepository.findRun(
      GalleryRunIds.release42,
    );
    expect(isRunActive(cancelled), isFalse);
    expect(find.textContaining('stopped', findRichText: true), findsOneWidget);
  });

  testWidgets('test_run_window_screen_property_deleted_run_says_so', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = _buildQuietDependencies();
    await _pumpReleaseWindow(
      tester,
      dependencies: dependencies,
      onTopSwitch: RecordingOnTopSwitch(),
    );
    final Run run = dependencies.taskRepository.findRun(
      GalleryRunIds.release42,
    );

    await dependencies.taskRepository.cancelRun(run.id);
    await dependencies.taskRepository.deleteTask(run.taskId);
    await pumpFrames(tester);

    expect(find.text('This run was deleted'), findsOneWidget);
    expect(find.text(keepOnTopLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_run_window_screen_property_renders_at_window_widths', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6302);
    final AppDependencies dependencies = _buildQuietDependencies();
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: smallestRunWindowSize.width,
        most: desktopWidth,
      );
      await _pumpReleaseWindow(
        tester,
        dependencies: dependencies,
        onTopSwitch: RecordingOnTopSwitch(),
      );
      useViewSize(tester, Size(width, runWindowSize.height));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');

      await tester.tap(find.text('Chat with agent'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: 'chat at $width');
    }
  });

  testWidgets('test_run_window_app_property_dense_on_macos', (
    WidgetTester tester,
  ) async {
    await _pumpReleaseWindow(
      tester,
      dependencies: _buildQuietDependencies(),
      onTopSwitch: RecordingOnTopSwitch(),
    );

    final Finder keepOnTopButton = find.widgetWithText(
      AppButton,
      keepOnTopLabel,
    );
    final BuildContext buttonContext = tester.element(keepOnTopButton);
    final TextScaler textScaler = MediaQuery.textScalerOf(buttonContext);

    expect(tester.getSize(keepOnTopButton).height, _denseControlHeight);
    expect(textScaler.scale(AppFontSizes.body), _denseBodyFontSize);
  }, variant: _onMac);
}
