import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/hovered_cursor.dart';
import '../support/person_step_dependencies.dart';
import '../support/recording_native_windows.dart';
import '../support/run_window_harness.dart';
import '../support/widget_harness.dart';

const int _creatorChainDepth = 8;

final TargetPlatformVariant _onDesktop = TargetPlatformVariant.only(
  desktopPlatform,
);

const List<AppRoute> _mainScreenRoutes = <AppRoute>[
  SectionRoute(AppSection.tasks),
  TaskRunRoute(GalleryRunIds.release42),
  TaskRunRoute(GalleryRunIds.release41),
  ChatRoute(GalleryRunIds.writeApiDocs1),
  SectionRoute(AppSection.approvals),
  SectionRoute(AppSection.settings),
  SectionRoute(AppSection.projects),
  SectionRoute(AppSection.workflows),
  WorkspaceSwitcherRoute(),
  WorkflowBuilderRoute(
    GalleryWorkflowIds.featurePipeline,
    opening: BuilderOpening.forEditing,
  ),
];

final class _TapTarget {
  const _TapTarget({required this.centre, required this.description});

  final Offset centre;
  final String description;
}

AppDependencies _buildDependenciesWithAnswers() {
  return buildDependenciesWithQuestion(notes: const <RunNote>[]);
}

bool _isTapTarget(Widget widget) {
  if (widget is! GestureDetector) {
    return false;
  }

  final bool hasTapHandler = widget.onTap != null || widget.onTapUp != null;
  final bool isDragCanvas = widget.onPanUpdate != null;
  return hasTapHandler && !isDragCanvas;
}

_TapTarget _describeTapTarget(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  final Offset centre = box.localToGlobal(box.size.center(Offset.zero));

  return _TapTarget(
    centre: centre,
    description: element.debugGetCreatorChain(_creatorChainDepth),
  );
}

List<_TapTarget> _findVisibleTapTargets() {
  final Finder tapTargets = find.byWidgetPredicate(_isTapTarget).hitTestable();
  final List<_TapTarget> targets = <_TapTarget>[];

  for (final Element element in tapTargets.evaluate()) {
    targets.add(_describeTapTarget(element));
  }
  return targets;
}

Future<void> _expectEveryTapTargetShowsTheHand(
  WidgetTester tester,
  String screenName,
) async {
  final List<_TapTarget> targets = _findVisibleTapTargets();
  expect(targets, isNotEmpty, reason: screenName);

  for (final _TapTarget target in targets) {
    final MouseCursor? hoveredCursor = await readCursorOver(
      tester,
      target.centre,
    );
    expect(
      hoveredCursor,
      SystemMouseCursors.click,
      reason: '$screenName: ${target.description}',
    );
  }
}

void main() {
  for (final AppRoute route in _mainScreenRoutes) {
    final String screenName = '${route.runtimeType} ${route.identity}';

    testWidgets('every tap target on $screenName shows the hand', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: desktopSize,
        route: route,
        dependencies: _buildDependenciesWithAnswers(),
      );

      await _expectEveryTapTargetShowsTheHand(tester, screenName);
    }, variant: _onDesktop);
  }

  testWidgets('every tap target in the run window shows the hand', (
    WidgetTester tester,
  ) async {
    await pumpRunWindow(
      tester,
      runId: GalleryRunIds.release42,
      dependencies: _buildDependenciesWithAnswers(),
      onTopSwitch: RecordingOnTopSwitch(),
    );

    await _expectEveryTapTargetShowsTheHand(tester, 'run window');
  }, variant: _onDesktop);
}
