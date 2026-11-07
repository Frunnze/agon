import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/deletion_review_harness.dart';
import 'support/refused_deletion_pages.dart';

const int _pageIterations = 3;

Future<AppNavigation> _openRefusingPage(
  WidgetTester tester, {
  required Random random,
  required RefusedDeletionPage page,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final AppDependencies dependencies = await page.buildDependencies();
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final bool opensFromItsSection =
      page.route is! SectionRoute && random.nextBool();
  final AppRoute firstRoute = opensFromItsSection
      ? SectionRoute(page.route.section)
      : page.route;
  final AppNavigation navigation = await pumpApp(
    tester,
    size: Size(width, desktopHeight),
    route: firstRoute,
    dependencies: dependencies,
  );
  if (opensFromItsSection) {
    navigation.openRoute(page.route);
    await pumpFrames(tester);
  }
  return navigation;
}

Future<void> _confirmRefusedDeletion(
  WidgetTester tester, {
  required RefusedDeletionPage page,
}) async {
  await tapAppButton(tester, page.pageButtonLabel);
  expect(find.text(page.confirmationTitle), findsOneWidget);
  await tapAppButton(tester, page.deleteLabel);
}

void main() {
  for (final RefusedDeletionPage page in refusedDeletionPages) {
    final String name = page.pageName;

    testWidgets('test_${name}_review_deletion_property_refusal_returns_to_'
        'the_page', (WidgetTester tester) async {
      final Random random = seededRandom(53001);

      for (int i = 0; i < _pageIterations; i += 1) {
        final AppNavigation navigation = await _openRefusingPage(
          tester,
          random: random,
          page: page,
        );
        final List<AppRoute> pageRoutes = navigation.routes;

        await _confirmRefusedDeletion(tester, page: page);

        expect(tester.takeException(), isNull);
        expect(navigation.routes, pageRoutes);
      }
    });

    testWidgets('test_${name}_review_deletion_property_refusal_is_shown_in_'
        'plain_words', (WidgetTester tester) async {
      final Random random = seededRandom(53002);

      for (int i = 0; i < _pageIterations; i += 1) {
        await _openRefusingPage(tester, random: random, page: page);

        await _confirmRefusedDeletion(tester, page: page);

        expect(find.text('${page.deleteLabel} did not work'), findsOneWidget);
        expect(find.text(page.refusal), findsOneWidget);
        expect(find.text(page.confirmationTitle), findsOneWidget);
      }
    });

    testWidgets('test_${name}_review_deletion_property_after_keeping_delete_'
        'asks_again', (WidgetTester tester) async {
      final Random random = seededRandom(53003);

      for (int i = 0; i < _pageIterations; i += 1) {
        final AppNavigation navigation = await _openRefusingPage(
          tester,
          random: random,
          page: page,
        );
        final List<AppRoute> pageRoutes = navigation.routes;
        await _confirmRefusedDeletion(tester, page: page);
        await tapAppButton(tester, page.keepLabel);

        expect(find.text(page.refusal), findsNothing);
        await tapAppButton(tester, page.pageButtonLabel);

        expect(find.text(page.confirmationTitle), findsOneWidget);
        expect(navigation.routes, pageRoutes);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
