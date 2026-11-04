import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';

const String _movedStep = 'review';
const Offset _screenDrag = Offset(60, 40);
const Offset _wheelTowardsYou = Offset(0, 120);
const Offset _wheelAwayFromYou = Offset(0, -120);
const Offset _trackpadPan = Offset(-30, -50);
const double _pinchScale = 1.5;
const double _pixelTolerance = 1;
const double _scaleTolerance = 0.01;
const int _clicksPastEitherLimit = 12;
const double _wheelClicksToZoomOut = 4;
const double _oneStepLarger = 1 + CanvasZoom.buttonStep;
const Duration _draftStep = Duration(milliseconds: 700);
const int _stepsBeforePlanArrives = 4;
const int _stepsUntilDraftFinishes = 8;
const WorkflowDraftingRoute _draftingRoute = WorkflowDraftingRoute(
  WorkflowDraft(description: 'Plan, build and review, then ship.'),
);

final class _ButtonZoom {
  const _ButtonZoom({required this.label, required this.clicks});

  final String label;
  final int clicks;

  double get expectedScale {
    final double direction = label == zoomInLabel ? 1 : -1;
    return 1 + direction * clicks * CanvasZoom.buttonStep;
  }
}

const List<_ButtonZoom> _buttonZooms = <_ButtonZoom>[
  _ButtonZoom(label: zoomOutLabel, clicks: 2),
  _ButtonZoom(label: zoomInLabel, clicks: 2),
];

double _readScale(WidgetTester tester) {
  final Rect box = tester.getRect(findDiagramNode(_movedStep));
  return box.width / CanvasMetrics.nodeWidth;
}

Future<void> _clickZoomButton(
  WidgetTester tester,
  String label, {
  required int clicks,
}) async {
  for (int i = 0; i < clicks; i += 1) {
    await tester.tap(find.text(label));
    await tester.pump();
  }
  await pumpFrames(tester);
}

Future<void> _scrollWheelAt(
  WidgetTester tester, {
  required Offset location,
  required Offset scrollDelta,
}) async {
  final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(location));
  await tester.sendEventToBinding(mouse.scroll(scrollDelta));
  await pumpFrames(tester);
}

Future<void> _zoomWithButtons(
  WidgetTester tester,
  _ButtonZoom zoom, {
  required String keptInView,
}) async {
  await _clickZoomButton(tester, zoom.label, clicks: zoom.clicks);
  final Offset nodeCentre = tester.getCenter(findDiagramNode(keptInView));
  final Offset canvasCentre = tester.getCenter(find.byType(CanvasFrame));
  await _scrollWheelAt(
    tester,
    location: canvasCentre,
    scrollDelta: nodeCentre - canvasCentre,
  );
}

void _expectSamePoint(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, _pixelTolerance));
  expect(actual.dy, closeTo(expected.dy, _pixelTolerance));
}

Future<AppDependencies> _openBuilder(WidgetTester tester, Size size) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  await openPipelineBuilder(tester, size: size, dependencies: dependencies);
  return dependencies;
}

void main() {
  for (final _ButtonZoom zoom in _buttonZooms) {
    testWidgets(
      'a box drag at ${zoom.expectedScale}x moves it on the canvas',
      (WidgetTester tester) async {
        final AppDependencies dependencies = await _openBuilder(
          tester,
          tallDesktopSize,
        );
        await _zoomWithButtons(tester, zoom, keptInView: _movedStep);
        expect(
          _readScale(tester),
          closeTo(zoom.expectedScale, _scaleTolerance),
        );
        final CanvasPosition start = findAgentNamed(
          readPipeline(dependencies),
          _movedStep,
        ).position;
        final Offset centre = tester.getCenter(findDiagramNode(_movedStep));

        await dragBetween(tester, start: centre, end: centre + _screenDrag);

        final CanvasPosition moved = findAgentNamed(
          readPipeline(dependencies),
          _movedStep,
        ).position;
        final Offset canvasDrag = _screenDrag / zoom.expectedScale;
        expect(
          moved.horizontal,
          closeTo(start.horizontal + canvasDrag.dx, _pixelTolerance),
        );
        expect(
          moved.vertical,
          closeTo(start.vertical + canvasDrag.dy, _pixelTolerance),
        );
      },
    );

    testWidgets('drawing a connection works at ${zoom.expectedScale}x', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = await _openBuilder(
        tester,
        tallDesktopSize,
      );
      await _zoomWithButtons(tester, zoom, keptInView: 'backend');
      final Workflow before = readPipeline(dependencies);
      final AgentConnection backendToIos = AgentConnection(
        from: findAgentNamed(before, 'backend').id,
        to: findAgentNamed(before, 'ios').id,
        condition: null,
        roundLimit: null,
      );

      await dragBetween(
        tester,
        start: tester.getRect(findDiagramNode('backend')).bottomCenter,
        end: tester.getCenter(findDiagramNode('ios')),
      );

      expect(readPipeline(dependencies).connections, contains(backendToIos));
    });
  }

  testWidgets('plain wheel scroll moves the diagram and keeps its size', (
    WidgetTester tester,
  ) async {
    await _openBuilder(tester, tallDesktopSize);
    final Offset centre = tester.getCenter(findDiagramNode(_movedStep));

    await _scrollWheelAt(
      tester,
      location: centre,
      scrollDelta: _wheelTowardsYou,
    );

    expect(_readScale(tester), 1);
    _expectSamePoint(
      tester.getCenter(findDiagramNode(_movedStep)),
      centre - _wheelTowardsYou,
    );
  });

  for (final LogicalKeyboardKey modifier in <LogicalKeyboardKey>[
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
  ]) {
    testWidgets('${modifier.keyLabel} and the wheel zoom around the pointer', (
      WidgetTester tester,
    ) async {
      await _openBuilder(tester, tallDesktopSize);
      final Offset centre = tester.getCenter(findDiagramNode(_movedStep));

      await tester.sendKeyDownEvent(modifier);
      await _scrollWheelAt(
        tester,
        location: centre,
        scrollDelta: _wheelAwayFromYou,
      );
      final double zoomedIn = _readScale(tester);
      await _scrollWheelAt(
        tester,
        location: centre,
        scrollDelta: _wheelTowardsYou * _wheelClicksToZoomOut,
      );
      await tester.sendKeyUpEvent(modifier);

      expect(zoomedIn, greaterThan(1));
      expect(_readScale(tester), lessThan(1));
      _expectSamePoint(tester.getCenter(findDiagramNode(_movedStep)), centre);
    });
  }

  testWidgets('a trackpad pinch zooms around the pointer, two fingers pan', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = await _openBuilder(
      tester,
      tallDesktopSize,
    );
    final Workflow before = readPipeline(dependencies);
    final Offset centre = tester.getCenter(findDiagramNode(_movedStep));
    final TestGesture trackpad = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );

    await trackpad.panZoomStart(centre);
    await trackpad.panZoomUpdate(centre, scale: _pinchScale);
    await trackpad.panZoomEnd();
    await pumpFrames(tester);
    expect(_readScale(tester), closeTo(_pinchScale, _scaleTolerance));
    _expectSamePoint(tester.getCenter(findDiagramNode(_movedStep)), centre);

    await trackpad.panZoomStart(centre);
    await trackpad.panZoomUpdate(centre, pan: _trackpadPan);
    await trackpad.panZoomEnd();
    await pumpFrames(tester);
    expect(_readScale(tester), closeTo(_pinchScale, _scaleTolerance));
    _expectSamePoint(
      tester.getCenter(findDiagramNode(_movedStep)),
      centre + _trackpadPan,
    );
    expect(readPipeline(dependencies), before);
  });

  testWidgets('the zoom buttons step the size and stop at the limits', (
    WidgetTester tester,
  ) async {
    await _openBuilder(tester, tallDesktopSize);

    await _clickZoomButton(tester, zoomInLabel, clicks: 1);
    expect(_readScale(tester), closeTo(_oneStepLarger, _scaleTolerance));

    await _clickZoomButton(
      tester,
      zoomInLabel,
      clicks: _clicksPastEitherLimit,
    );
    expect(
      _readScale(tester),
      closeTo(CanvasZoom.largestScale, _scaleTolerance),
    );

    await _clickZoomButton(
      tester,
      zoomOutLabel,
      clicks: _clicksPastEitherLimit,
    );
    expect(
      _readScale(tester),
      closeTo(CanvasZoom.smallestScale, _scaleTolerance),
    );
  });

  testWidgets('Fit shows every box inside the canvas', (
    WidgetTester tester,
  ) async {
    await _openBuilder(tester, desktopSize);
    await _clickZoomButton(
      tester,
      zoomInLabel,
      clicks: _clicksPastEitherLimit,
    );

    await _clickZoomButton(tester, fitLabel, clicks: 1);

    final Rect canvas = tester.getRect(find.byType(CanvasFrame));
    final Finder boxes = find.byType(AgentNodeBox);
    expect(boxes, findsWidgets);
    for (int i = 0; i < boxes.evaluate().length; i += 1) {
      final Rect box = tester.getRect(boxes.at(i));
      expect(canvas.contains(box.topLeft), true);
      expect(canvas.contains(box.bottomRight), true);
    }
    expect(_readScale(tester), lessThanOrEqualTo(CanvasZoom.largestFitScale));
  });

  testWidgets('the drafting diagram zooms and pans like the builder', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: workflowsSectionRoute,
      dependencies: buildGalleryDependencies(),
    );
    navigation.openRoute(_draftingRoute);
    await tester.pump();
    await tester.pump(_draftStep * _stepsBeforePlanArrives);
    await tester.pump();
    final double actualWidth = tester.getRect(findDiagramNode('plan')).width;

    await tester.tap(find.text(zoomInLabel));
    await tester.pump();

    final double zoomedWidth = tester.getRect(findDiagramNode('plan')).width;
    expect(
      zoomedWidth,
      closeTo(actualWidth * _oneStepLarger, _scaleTolerance),
    );

    final Offset planCentre = tester.getCenter(findDiagramNode('plan'));
    await tester.dragFrom(planCentre, _screenDrag);
    await tester.pump();
    _expectSamePoint(
      tester.getCenter(findDiagramNode('plan')),
      planCentre + _screenDrag,
    );
    await tester.pump(_draftStep * _stepsUntilDraftFinishes);
    await pumpFrames(tester);
  });
}
