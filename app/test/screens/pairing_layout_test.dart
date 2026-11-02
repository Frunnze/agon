import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const List<String> _requestTerms = <String>[
  'Role',
  'Hardware key',
  'Code used',
];

void main() {
  testWidgets('test_pairing_approval_property_request_facts_share_a_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpApp(
        tester,
        size: Size(width, desktopHeight),
        route: const PairingApprovalRoute(),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.byType(FactRow), findsOneWidget, reason: 'width $width');
      final double rowWidth = tester.getSize(find.byType(FactRow)).width;
      final int columns = countFactColumns(
        width: rowWidth,
        factCount: _requestTerms.length,
      );
      final double firstTop = tester.getRect(find.text(_requestTerms[0])).top;
      for (int index = 0; index < columns; index += 1) {
        final double top = tester.getRect(find.text(_requestTerms[index])).top;
        expect(top, firstTop, reason: 'width $width, ${_requestTerms[index]}');
      }
    }
  });
}
