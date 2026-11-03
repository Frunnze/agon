import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/compact_page_header.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

CompactPageHeader _buildRandomHeader(Random random) {
  return CompactPageHeader(
    title: randomText(random),
    summary: randomText(random),
    backLink: BackLink(label: 'Workflows', onPressed: () {}),
    actions: <Widget>[
      AppButton.secondary(label: 'Cancel', onPressed: () {}),
      AppButton.primary(label: 'Sign and save', onPressed: () {}),
    ],
  );
}

void main() {
  testWidgets('test_compact_page_header_property_one_row_when_wide', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: _buildRandomHeader(random),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byType(BackLinkButton), findsOneWidget);
      if (width >= compactHeaderSingleRowMinimumWidth) {
        expect(
          tester.getSize(find.byType(CompactPageHeader)).height,
          lessThanOrEqualTo(AppSizes.controlHeight),
          reason: 'width $width',
        );
      }
    }
  });
}
