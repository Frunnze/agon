import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/route_screens.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

final List<AppRoute> _routesNeedingProject = <AppRoute>[
  const NewTaskRoute(),
  const NewJobRoute(),
  const NewWorkflowTaskRoute(GalleryWorkflowIds.release),
  const NewWorkflowTaskRoute(GalleryWorkflowIds.nightlyTests),
  NewItemFormRoute(DraftKind.task),
  NewItemFormRoute(DraftKind.job),
];

bool _isNewProjectChat(Widget screen) {
  return screen is NewItemScreen && screen.kind == DraftKind.project;
}

void main() {
  final AppNavigation navigation = AppNavigation(
    initialRoute: const SectionRoute(AppSection.tasks),
  );
  final AppDependencies withProjects = buildGalleryDependencies();
  final AppDependencies withoutProjects = replaceRepositories(
    withProjects,
    projectRepository: FakeProjectRepository(projects: const <Project>[]),
  );

  test('test_build_route_screen_property_new_work_without_projects_opens_'
      'new_project_chat', () {
    final Random random = seededRandom(7301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppRoute route = pickOne(random, _routesNeedingProject);

      final Widget screenWithoutProjects = buildRouteScreen(
        route: route,
        dependencies: withoutProjects,
        navigation: navigation,
      );
      final Widget screenWithProjects = buildRouteScreen(
        route: route,
        dependencies: withProjects,
        navigation: navigation,
      );

      expect(_isNewProjectChat(screenWithoutProjects), isTrue);
      expect(_isNewProjectChat(screenWithProjects), isFalse);
    }
  });
}
