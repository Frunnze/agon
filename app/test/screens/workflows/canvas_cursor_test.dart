import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/builder_harness.dart';
import '../../support/hovered_cursor.dart';
import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _draggedBoxName = 'review';
const Offset _dragDistance = Offset(40, 0);

final TargetPlatformVariant _onDesktop = TargetPlatformVariant.only(
  desktopPlatform,
);

DiagramEdge? _pickEdgeOrNothing(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );
  if (edges.isEmpty || random.nextBool()) {
    return null;
  }
  return pickOne(random, edges);
}

void main() {
  test(
    'test_choose_canvas_cursor_property_dots_and_lines_click_boxes_grab',
    () {
      final Random random = seededRandom(7421);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkflowAgentId agentId = WorkflowAgentId(randomText(random));
        final PortSide side = pickOne(random, PortSide.values);
        final DiagramEdge? edgeHit = _pickEdgeOrNothing(random);
        final MouseCursor emptySpotCursor = edgeHit == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click;

        expect(
          chooseCanvasCursor(
            agentHit: PortHit(agentId, side),
            edgeHit: edgeHit,
          ),
          SystemMouseCursors.click,
        );
        expect(
          chooseCanvasCursor(agentHit: NodeHit(agentId), edgeHit: edgeHit),
          SystemMouseCursors.grab,
        );
        expect(
          chooseCanvasCursor(agentHit: null, edgeHit: edgeHit),
          emptySpotCursor,
        );
      }
    },
  );

  testWidgets('diagram boxes show the grab cursor and their dots the hand', (
    WidgetTester tester,
  ) async {
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: buildGalleryDependencies(),
    );
    final Rect box = tester.getRect(findDiagramNode(_draggedBoxName));

    final MouseCursor? boxCursor = await readCursorOver(tester, box.center);
    final MouseCursor? dotCursor = await readCursorOver(
      tester,
      box.bottomCenter,
    );

    expect(boxCursor, SystemMouseCursors.grab);
    expect(dotCursor, SystemMouseCursors.click);
  }, variant: _onDesktop);

  testWidgets('a diagram box being dragged shows the grabbing cursor', (
    WidgetTester tester,
  ) async {
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: buildGalleryDependencies(),
    );
    final Offset boxCentre = tester.getCenter(
      findDiagramNode(_draggedBoxName),
    );
    final TestGesture mouse = await hoverMouseAt(tester, boxCentre);

    await mouse.down(boxCentre);
    await mouse.moveBy(_dragDistance);
    await tester.pump();
    final MouseCursor? draggingCursor = readMouseCursor();

    await mouse.up();
    await tester.pump();
    final MouseCursor? droppedCursor = readMouseCursor();
    await mouse.removePointer();

    expect(draggingCursor, SystemMouseCursors.grabbing);
    expect(droppedCursor, SystemMouseCursors.grab);
  }, variant: _onDesktop);
}
