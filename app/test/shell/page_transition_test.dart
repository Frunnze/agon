import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/rising_page.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

const String _jobsTitle = 'Jobs';

bool _isPaperBox(Widget widget) {
  return widget is ColoredBox && widget.color == AppColors.paper;
}

Widget _buildNavigatorShowing(String screenText) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Navigator(
      pages: <Page<Object?>>[
        RisingPage(
          key: const ValueKey<String>('only page'),
          child: Text(screenText),
        ),
      ],
      onDidRemovePage: _ignoreRemovedPage,
    ),
  );
}

void _ignoreRemovedPage(Page<Object?> page) {}

void main() {
  testWidgets('test_rising_page_property_rebuilt_page_shows_its_new_screen', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String firstText = 'screen ${random.nextInt(1000)}';
      final String secondText = '$firstText then ${random.nextInt(1000)}';

      await tester.pumpWidget(_buildNavigatorShowing(firstText));
      await tester.pump(AppDurations.enter);
      await tester.pumpWidget(_buildNavigatorShowing(secondText));
      await tester.pump();

      expect(find.text(secondText), findsOneWidget);
      expect(find.text(firstText), findsNothing);
    }
  });

  testWidgets(
    'test_open_section_property_new_page_hides_the_old_one_at_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(7501);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppNavigation navigation = await pumpApp(
          tester,
          size: desktopSize,
          route: const SectionRoute(AppSection.tasks),
          dependencies: buildGalleryDependencies(),
        );

        navigation.openSection(const SectionRoute(AppSection.jobs));
        await tester.pump();
        final int progressMilliseconds = random.nextInt(
          AppDurations.enter.inMilliseconds,
        );
        await tester.pump(Duration(milliseconds: progressMilliseconds));

        final Finder newPageTitle = find.text(_jobsTitle).last;
        final Finder coveringBox = find.ancestor(
          of: newPageTitle,
          matching: find.byWidgetPredicate(_isPaperBox),
        );
        expect(coveringBox, findsWidgets, reason: '$progressMilliseconds');

        final Size navigatorSize = tester.getSize(find.byType(Navigator).last);
        final Size coveredSize = tester.getSize(coveringBox.last);
        expect(coveredSize, navigatorSize, reason: '$progressMilliseconds');

        await tester.pump(AppDurations.enter);
      }
    },
  );
}
