import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

Finder _findScrim() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is ModalBarrier && widget.color == AppColors.scrim,
  );
}

void main() {
  testWidgets('test_workspace_switcher_screen_property_scrim_covers_window', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7931);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size window = Size(
        randomWidth(random, least: narrowestWidth, most: widestWidth),
        desktopHeight,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: window,
        route: const WorkspaceSwitcherRoute(),
        dependencies: buildGalleryDependencies(),
      );

      final Rect scrim = tester.getRect(_findScrim());
      final Rect dialog = tester.getRect(find.byType(WorkspaceSwitcherDialog));
      final String reason = 'window $window';
      expect(scrim, Offset.zero & window, reason: reason);
      if (LayoutSize.forWidth(window.width).isCompact) {
        expect(dialog.bottom, closeTo(window.height, 0.5), reason: reason);
        expect(dialog.width, closeTo(window.width, 0.5), reason: reason);
      } else {
        final Offset windowCentre = window.center(Offset.zero);
        expect(dialog.center.dx, closeTo(windowCentre.dx, 0.5));
        expect(dialog.center.dy, closeTo(windowCentre.dy, 0.5));
      }
    }
  });
}
