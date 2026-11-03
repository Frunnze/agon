import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/projects/repository_entry_field.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

void main() {
  testWidgets('test_repository_entry_field_property_button_matches_input', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final String? problem = random.nextBool() ? randomText(random) : null;
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: RepositoryEntryField(
          controller: TextEditingController(),
          problem: problem,
          placeholder: 'github.com/acme/repo or /path/to/folder',
          onChanged: (String _) {},
          onAdded: () {},
        ),
      );

      final Rect button = tester.getRect(find.byType(AppButton));
      final Rect field = tester.getRect(find.byType(TextField));
      final String reason = 'width $width, problem $problem';
      expect(button.height, AppSizes.controlHeight, reason: reason);
      expect(button.top, field.top, reason: reason);
    }
  });
}
