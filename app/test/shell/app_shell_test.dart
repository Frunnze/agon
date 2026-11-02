import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/bottom_tabs.dart';
import 'package:agent_orchestration/shell/side_rail.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

List<AppRoute> galleryRoutes() {
  return <AppRoute>[
    const SectionRoute(AppSection.tasks),
    const NewTaskRoute(),
    const EditTaskRoute(GalleryTaskIds.cleanUpBranches),
    const TaskRunRoute(GalleryRunIds.release42),
    const TaskRunRoute(GalleryRunIds.release41),
    const ChatRoute(GalleryRunIds.release42),
    const SectionRoute(AppSection.jobs),
    const NewJobRoute(),
    const EditJobRoute(GalleryTaskIds.updateDependencies),
    const SectionRoute(AppSection.approvals),
    const SectionRoute(AppSection.more),
    const SectionRoute(AppSection.projects),
    const RunnersSettingsRoute(),
  ];
}

void main() {
  testWidgets('test_app_shell_property_rail_from_768_and_tabs_below', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpApp(
        tester,
        size: Size(width, desktopHeight),
        route: const SectionRoute(AppSection.tasks),
        dependencies: buildGalleryDependencies(),
      );
      final bool isCompact = LayoutSize.forWidth(width).isCompact;

      expect(find.byType(BottomTabs).evaluate().isNotEmpty, isCompact);
      expect(find.byType(SideRail).evaluate().isNotEmpty, !isCompact);
    }
  });

  testWidgets('test_screens_property_render_without_overflow_at_any_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3102);
    final List<AppRoute> routes = galleryRoutes();

    for (int i = 0; i < routes.length * 2; i += 1) {
      final Size size = Size(
        randomWidth(random, least: narrowestWidth, most: widestWidth),
        randomWidth(random, least: 640, most: 1100),
      );
      await pumpApp(
        tester,
        size: size,
        route: routes[i % routes.length],
        dependencies: buildGalleryDependencies(),
      );
      await pumpFrames(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: '$size ${routes[i % routes.length]}',
      );
    }
  });

  testWidgets('test_bottom_tabs_property_each_tab_opens_its_section', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = await pumpApp(
        tester,
        size: phoneSize,
        route: const SectionRoute(AppSection.tasks),
        dependencies: buildGalleryDependencies(),
      );
      final AppSection section = pickOne(random, bottomTabSections);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomTabs),
          matching: find.text(section.label),
        ),
      );
      await pumpFrames(tester);

      expect(navigation.currentRoute, SectionRoute(section));
    }
  });

  testWidgets('test_side_rail_property_each_link_opens_its_section', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = await pumpApp(
        tester,
        size: desktopSize,
        route: const SectionRoute(AppSection.tasks),
        dependencies: buildGalleryDependencies(),
      );
      final AppSection section = pickOne(random, railSections);
      await tester.tap(
        find.descendant(
          of: find.byType(SideRail),
          matching: find.text(section.label),
        ),
      );
      await pumpFrames(tester);

      expect(navigation.currentRoute, SectionRoute(section));
    }
  });

  testWidgets('back links and the system back close pushed pages', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.jobs),
      dependencies: buildGalleryDependencies(),
    );
    navigation.openRoute(const NewJobRoute());
    await pumpFrames(tester);

    await tester.tap(find.byType(BackLinkButton));
    await pumpFrames(tester);
    expect(navigation.routes.length, 1);

    navigation.openRoute(const NewJobRoute());
    await pumpFrames(tester);
    final NavigatorState content = tester.state<NavigatorState>(
      find.byType(Navigator).last,
    );
    await content.maybePop();
    await pumpFrames(tester);
    expect(navigation.routes.length, 1);
  });
}
