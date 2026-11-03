import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/random_inputs.dart';

const String _settingsTitle = 'Agent settings';
const String _addAgentLabel = 'Add agent';
const String _nameLabel = 'Workflow name';
const double _cornerInset = 24;
const int _cornerCases = 4;

Offset _pickEmptyCorner(Rect canvas, Random random) {
  final double insetFromRight = _cornerInset + random.nextDouble() * 40;
  final double insetFromBottom = _cornerInset + random.nextDouble() * 40;
  return Offset(
    canvas.right - insetFromRight,
    canvas.bottom - insetFromBottom,
  );
}

Finder _findNameField() {
  return find.descendant(
    of: find
        .ancestor(of: find.text(_nameLabel), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );
}

void main() {
  testWidgets('test_editable_diagram_property_empty_canvas_space_takes_taps', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8803);

    for (int i = 0; i < _cornerCases; i += 1) {
      await openPipelineBuilder(
        tester,
        size: tallDesktopSize,
        dependencies: buildGalleryDependencies(),
      );
      await selectDiagramNode(tester, 'review');
      expect(find.text(_settingsTitle), findsOneWidget);

      final Rect canvas = tester.getRect(find.byType(CanvasFrame));
      await tester.tapAt(_pickEmptyCorner(canvas, random));
      await pumpFrames(tester);

      expect(find.text(_settingsTitle), findsNothing);
    }
  });

  testWidgets('add agent sits beside the workflow name', (
    WidgetTester tester,
  ) async {
    final navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: workflowsSectionRoute,
      dependencies: buildGalleryDependencies(),
    );
    navigation.openRoute(const ManualWorkflowRoute());
    await pumpFrames(tester);

    final Rect nameField = tester.getRect(_findNameField());
    final Rect addAgent = tester.getRect(
      find.ancestor(
        of: find.text(_addAgentLabel),
        matching: find.byType(TextButton),
      ),
    );

    expect(addAgent.left, greaterThan(nameField.right));
    expect(addAgent.center.dy, closeTo(nameField.center.dy, 4));
  });
}
