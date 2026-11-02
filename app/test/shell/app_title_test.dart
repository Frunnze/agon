import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/product_name.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _chosenProductName = 'Agon';

void main() {
  test('test_product_name_property_is_the_chosen_name_agon', () {
    expect(productName, _chosenProductName);
  });

  testWidgets('test_agent_orchestration_app_property_window_title_is_agon', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppSection section = pickOne(random, AppSection.values);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpApp(
        tester,
        size: Size(width, desktopHeight),
        route: SectionRoute(section),
        dependencies: buildGalleryDependencies(),
      );

      final Title windowTitle = tester.widget<Title>(find.byType(Title));
      expect(windowTitle.title, _chosenProductName);
    }
  });
}
