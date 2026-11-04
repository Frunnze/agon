import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/route_pages.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../support/random_inputs.dart';

List<AppRoute> sampleRoutes(Random random) {
  return <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
    const NewTaskRoute(),
    EditTaskRoute(TaskId('task-${random.nextInt(3)}')),
    const TaskRunRoute(GalleryRunIds.release42),
    ChatRoute(RunId('run-${random.nextInt(3)}')),
    const NewJobRoute(),
    const WorkspaceSwitcherRoute(),
  ];
}

void main() {
  test('test_open_route_property_stack_grows_and_top_is_newest', () {
    final Random random = seededRandom(3001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.tasks),
      );
      final int pushes = random.nextInt(6);
      for (int push = 0; push < pushes; push += 1) {
        final AppRoute route = pickOne(random, sampleRoutes(random));
        navigation.openRoute(route);
        expect(navigation.currentRoute, route);
      }
      expect(navigation.routes.length, pushes + 1);
    }
  });

  test('test_close_route_property_never_empties_the_stack', () {
    final Random random = seededRandom(3002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.jobs),
      );
      for (int step = 0; step < 10; step += 1) {
        if (random.nextBool()) {
          navigation.openRoute(pickOne(random, sampleRoutes(random)));
        } else if (navigation.routes.length > 1) {
          navigation.closeRoute();
        } else {
          expect(navigation.closeRoute, throwsStateError);
        }
        expect(navigation.routes, isNotEmpty);
      }
    }
  });

  test('test_replace_route_property_keeps_depth', () {
    final Random random = seededRandom(3003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.tasks),
      );
      navigation.openRoute(const NewTaskRoute());
      final AppRoute replacement = pickOne(random, sampleRoutes(random));
      navigation.replaceRoute(replacement);

      expect(navigation.routes.length, 2);
      expect(navigation.currentRoute, replacement);
    }
  });

  test('test_open_section_property_resets_to_one_route', () {
    final Random random = seededRandom(3004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.tasks),
      );
      for (final AppRoute route in sampleRoutes(random)) {
        navigation.openRoute(route);
      }
      final SectionRoute section = SectionRoute(
        pickOne(random, AppSection.values),
      );
      navigation.openSection(section);

      expect(navigation.routes, <AppRoute>[section]);
    }
  });

  test('test_return_to_property_pops_when_below_otherwise_replaces', () {
    final Random random = seededRandom(3005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.tasks),
      );
      const TaskRunRoute runRoute = TaskRunRoute(GalleryRunIds.release42);
      final bool startsBelow = random.nextBool();
      if (startsBelow) {
        navigation.openRoute(runRoute);
      }
      navigation.openRoute(const ChatRoute(GalleryRunIds.release42));
      final int depthBefore = navigation.routes.length;
      navigation.returnTo(runRoute);

      expect(navigation.currentRoute, runRoute);
      expect(
        navigation.routes.length,
        startsBelow ? depthBefore - 1 : depthBefore,
      );
    }
  });

  test('test_find_bottom_tab_for_property_always_a_bottom_tab', () {
    for (final AppSection section in AppSection.values) {
      final AppSection tab = findBottomTabFor(section);
      expect(bottomTabSections.contains(tab), isTrue);
      if (bottomTabSections.contains(section)) {
        expect(tab, section);
      }
    }
  });

  test('test_app_route_equality_property_value_semantics', () {
    final Random random = seededRandom(3007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> first = sampleRoutes(seededRandom(i));
      final List<AppRoute> second = sampleRoutes(seededRandom(i));
      final int index = random.nextInt(first.length);

      expect(first[index], second[index]);
      expect(first[index].hashCode, second[index].hashCode);
    }
    expect(const NewTaskRoute() == const NewJobRoute(), isFalse);
  });

  test('test_build_route_pages_property_one_unique_page_per_route', () {
    final Random random = seededRandom(3008);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final List<AppRoute> routes = <AppRoute>[
        const SectionRoute(AppSection.tasks),
        for (int index = 0; index < random.nextInt(4); index += 1)
          const TaskRunRoute(GalleryRunIds.release42),
      ];
      final pages = buildRoutePages(
        routes: routes,
        dependencies: buildGalleryDependencies(),
        navigation: AppNavigation(initialRoute: routes.first),
        runWindowOpener: null,
      );

      expect(pages.length, routes.length);
      expect(pages.map((page) => page.key).toSet().length, routes.length);
    }
  });

  testWidgets(
    'test_build_route_pages_property_pages_rise_in_and_leave_at_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(3009);
      await tester.pumpWidget(const SizedBox());
      final BuildContext context = tester.element(find.byType(SizedBox));

      for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
        final List<AppRoute> routes = <AppRoute>[
          const SectionRoute(AppSection.tasks),
          for (int index = 0; index < random.nextInt(4); index += 1)
            const TaskRunRoute(GalleryRunIds.release42),
        ];
        final List<Page<Object?>> pages = buildRoutePages(
          routes: routes,
          dependencies: buildGalleryDependencies(),
          navigation: AppNavigation(initialRoute: routes.first),
          runWindowOpener: null,
        );

        for (final Page<Object?> page in pages) {
          final Route<Object?> route = page.createRoute(context);
          expect(route, isA<PageRoute<Object?>>());
          final PageRoute<Object?> pageRoute = route as PageRoute<Object?>;
          expect(pageRoute.transitionDuration, AppDurations.enter);
          expect(pageRoute.reverseTransitionDuration, Duration.zero);
          expect(pageRoute.opaque, isTrue);
        }
      }
    },
  );
}
