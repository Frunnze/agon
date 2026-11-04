import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/clickable.dart';

import '../support/hovered_cursor.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _clickableLabel = 'Show earlier rounds';

void _ignoreTap() {}

void main() {
  testWidgets('test_clickable_property_click_cursor_only_when_enabled', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7411);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isEnabled = random.nextBool();
      final VoidCallback? onTap = isEnabled ? _ignoreTap : null;
      await tester.pumpWidget(
        wrapInApp(
          Center(
            child: Clickable(onTap: onTap, child: const Text(_clickableLabel)),
          ),
          platform: desktopPlatform,
        ),
      );

      final MouseCursor? hoveredCursor = await readCursorOver(
        tester,
        tester.getCenter(find.text(_clickableLabel)),
      );
      final MouseCursor expectedCursor = isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic;
      expect(hoveredCursor, expectedCursor, reason: 'enabled $isEnabled');
    }
  });

  testWidgets('test_clickable_property_taps_reach_the_handler', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7412);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int tapsWanted = random.nextInt(4);
      int tapCount = 0;
      await tester.pumpWidget(
        wrapInApp(
          Center(
            child: Clickable(
              onTap: () => tapCount += 1,
              child: const Text(_clickableLabel),
            ),
          ),
          platform: desktopPlatform,
        ),
      );

      for (int tap = 0; tap < tapsWanted; tap += 1) {
        await tester.tap(find.text(_clickableLabel));
      }
      expect(tapCount, tapsWanted);
    }
  });
}
