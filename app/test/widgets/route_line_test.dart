import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('test_route_line_property_renders_every_path_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 2201,
      buildChild: (Random random) => RouteLine(
        startName: randomText(random),
        endName: randomText(random),
        path: pickOne(random, RoutePath.values),
        badgeLabel: randomText(random),
        badgeIcon: pickOne(random, AppIconKind.values),
      ),
    );
  });

  testWidgets('route line names both devices and the link', (
    WidgetTester tester,
  ) async {
    await pumpScrollableAtWidth(
      tester,
      width: phoneWidth,
      child: const RouteLine(
        startName: 'air-laptop',
        endName: 'mac-studio',
        path: RoutePath.direct,
        badgeLabel: 'Direct · encrypted',
        badgeIcon: AppIconKind.lock,
      ),
    );

    expect(find.text('air-laptop'), findsOneWidget);
    expect(find.text('Direct · encrypted'), findsOneWidget);
    expect(find.text('mac-studio'), findsOneWidget);
  });

  test('test_route_path_property_only_broken_routes_are_red', () {
    for (final RoutePath path in RoutePath.values) {
      expect(path.color == AppColors.danger, path == RoutePath.broken);
      expect(
        RouteLinePainter(path: path)
            .shouldRepaint(RouteLinePainter(path: path)),
        isFalse,
      );
    }
  });
}
