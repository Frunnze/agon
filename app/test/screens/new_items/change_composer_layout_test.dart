import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

void main() {
  testWidgets('test_change_request_composer_property_send_matches_the_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ChangeRequestComposer(
          example: 'For example: ask before pushing',
          onSend: (String _) {},
        ),
      );

      final Rect field = tester.getRect(find.byType(TextField));
      final Rect send = tester.getRect(find.byType(AppButton));
      final String reason = 'width $width';
      final double controlHeight = AppSizes.controlHeightFor(
        densityMeantByWidth(width),
      );
      expect(field.height, controlHeight, reason: reason);
      expect(send.height, controlHeight, reason: reason);
      expect(send.bottom, field.bottom, reason: reason);
    }
  });
}
