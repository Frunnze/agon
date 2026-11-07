import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';

const int _largestStackDepth = 6;
const int _largestMoveCount = 5;
const int _identifierSpan = 4;

AppRoute _randomRoute(Random random) {
  final int number = random.nextInt(_identifierSpan);
  final List<AppRoute> choices = <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
    ProjectRoute(ProjectId('project-$number')),
    EditTaskRoute(TaskId('task-$number')),
    TaskRunRoute(RunId('run-$number')),
    ChatRoute(RunId('run-$number')),
    const WorkspaceSwitcherRoute(),
  ];
  return pickOne(random, choices);
}

List<AppRoute> _randomStack(Random random) {
  final int depth = 1 + random.nextInt(_largestStackDepth);
  final List<AppRoute> stack = <AppRoute>[];
  for (int i = 0; i < depth; i += 1) {
    stack.add(_randomRoute(random));
  }
  return stack;
}

AppNavigation _navigateRandomly(Random random) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: _randomRoute(random),
  );
  final int moveCount = random.nextInt(_largestMoveCount);
  for (int i = 0; i < moveCount; i += 1) {
    if (random.nextBool()) {
      navigation.openRoute(_randomRoute(random));
    } else {
      navigation.openSection(SectionRoute(pickOne(random, AppSection.values)));
    }
  }
  return navigation;
}

void main() {
  test('test_restore_routes_property_brings_back_the_exact_stack', () {
    final Random random = seededRandom(84121);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _navigateRandomly(random);
      final List<AppRoute> savedRoutes = navigation.routes;
      navigation.openSection(SectionRoute(pickOne(random, AppSection.values)));
      navigation.openRoute(_randomRoute(random));

      navigation.restoreRoutes(savedRoutes);

      expect(navigation.routes, savedRoutes);
      expect(navigation.currentRoute, savedRoutes.last);
    }
  });

  test('test_restore_routes_property_notifies_listeners_once', () {
    final Random random = seededRandom(84122);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _navigateRandomly(random);
      final List<AppRoute> stack = _randomStack(random);
      int notificationCount = 0;
      navigation.addListener(() => notificationCount += 1);

      navigation.restoreRoutes(stack);

      expect(notificationCount, 1);
      expect(navigation.routes, stack);
    }
  });

  test('test_restore_routes_property_keeps_its_own_copy', () {
    final Random random = seededRandom(84123);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _navigateRandomly(random);
      final List<AppRoute> stack = _randomStack(random);
      final List<AppRoute> expectedRoutes = List<AppRoute>.of(stack);

      navigation.restoreRoutes(stack);
      stack.add(_randomRoute(random));

      expect(navigation.routes, expectedRoutes);
      expect(
        () => navigation.routes.add(_randomRoute(random)),
        throwsA(isA<UnsupportedError>()),
      );
    }
  });

  test('test_restore_routes_property_refuses_an_empty_stack', () {
    final Random random = seededRandom(84124);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _navigateRandomly(random);
      final List<AppRoute> routesBefore = navigation.routes;

      expect(
        () => navigation.restoreRoutes(const <AppRoute>[]),
        throwsStateError,
      );
      expect(navigation.routes, routesBefore);
    }
  });

  test('test_restore_routes_property_run_windows_refuse_other_pages', () {
    final Random random = seededRandom(84125);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = RunId('run-${random.nextInt(_identifierSpan)}');
      final AppNavigation navigation = AppNavigation.limitedToRunPages(
        runId: runId,
      );
      final List<AppRoute> stack = _randomStack(random);
      final bool isEveryRouteARunPage = stack.every(
        (AppRoute route) => route is RunPageRoute,
      );

      if (isEveryRouteARunPage) {
        navigation.restoreRoutes(stack);
        expect(navigation.routes, stack);
      } else {
        expect(() => navigation.restoreRoutes(stack), throwsStateError);
        expect(navigation.routes, <AppRoute>[TaskRunRoute(runId)]);
      }
    }
  });
}
