import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';

const String _loginFailure = 'Not logged in · Please run /login';

RunId _randomRunId(Random random) {
  return RunId('run-${random.nextInt(99)}');
}

List<AppRoute> _sampleRoutes(Random random) {
  return <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
    const NewTaskRoute(),
    EditTaskRoute(TaskId('task-${random.nextInt(3)}')),
    TaskRunRoute(_randomRunId(random)),
    ChatRoute(_randomRunId(random)),
    ProjectRoute(ProjectId('project-${random.nextInt(3)}')),
    RunnerDetailRoute(DeviceId('device-${random.nextInt(3)}')),
    const WorkspaceSwitcherRoute(),
  ];
}

void main() {
  test('test_limited_to_run_pages_property_opens_only_run_pages', () {
    final Random random = seededRandom(9401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation.limitedToRunPages(
        runId: _randomRunId(random),
      );
      final AppRoute route = pickOne(random, _sampleRoutes(random));
      final List<AppRoute> before = navigation.routes;
      final bool isRunPage = route is RunPageRoute;

      expect(navigation.canOpen(route), isRunPage);
      if (isRunPage) {
        navigation.openRoute(route);
        expect(navigation.currentRoute, route);
        continue;
      }
      expect(() => navigation.openRoute(route), throwsStateError);
      expect(() => navigation.replaceRoute(route), throwsStateError);
      expect(() => navigation.openSection(route), throwsStateError);
      expect(() => navigation.returnTo(route), throwsStateError);
      expect(navigation.routes, before);
    }
  });

  test('test_limited_to_run_pages_property_starts_on_the_run', () {
    final Random random = seededRandom(9402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = _randomRunId(random);
      final AppNavigation navigation = AppNavigation.limitedToRunPages(
        runId: runId,
      );

      expect(navigation.routes, <AppRoute>[TaskRunRoute(runId)]);
    }
  });

  test('test_app_navigation_property_opens_every_page', () {
    final Random random = seededRandom(9403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.tasks),
      );
      final AppRoute route = pickOne(random, _sampleRoutes(random));

      expect(navigation.canOpen(route), isTrue);
      navigation.openRoute(route);
      expect(navigation.currentRoute, route);
    }
  });

  test('test_point_to_agent_login_property_connects_only_where_it_opens', () {
    final Random random = seededRandom(9404);
    final DeviceRepository devices = buildGalleryDependencies()
        .deviceRepository;
    final DeviceId thisDevice = devices.currentDevice().id;

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isRunWindow = random.nextBool();
      final AppNavigation navigation = isRunWindow
          ? AppNavigation.limitedToRunPages(runId: _randomRunId(random))
          : AppNavigation(initialRoute: const SectionRoute(AppSection.tasks));

      final AgentLoginPointer? pointer = pointToAgentLogin(
        reason: '${randomWordPhrase(random)} $_loginFailure',
        runner: thisDevice,
        deviceRepository: devices,
        navigation: navigation,
      );

      expect(pointer, isNotNull);
      expect(pointer!.onConnect == null, isRunWindow);
      pointer.onConnect?.call();
      expect(navigation.currentRoute is RunnerDetailRoute, !isRunWindow);
    }
  });
}
