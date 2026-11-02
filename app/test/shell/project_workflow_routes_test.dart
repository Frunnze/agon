import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';

List<AppRoute> _buildRoutes(String identifier) {
  return <AppRoute>[
    ProjectRoute(ProjectId(identifier)),
    WorkflowDetailRoute(WorkflowId(identifier)),
    WorkflowBuilderRoute(
      WorkflowId(identifier),
      opening: BuilderOpening.forEditing,
    ),
    WorkflowBuilderRoute(
      WorkflowId(identifier),
      opening: BuilderOpening.afterDrafting,
    ),
    WorkflowDraftingRoute(WorkflowDraft(description: identifier)),
    NewWorkflowTaskRoute(WorkflowId(identifier)),
  ];
}

void main() {
  test('test_route_identity_property_equal_only_for_the_same_record', () {
    final Random random = seededRandom(9501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = 'record-${random.nextInt(5)}';
      final String second = 'record-${random.nextInt(5)}';
      final List<AppRoute> firstRoutes = _buildRoutes(first);
      final List<AppRoute> secondRoutes = _buildRoutes(second);

      for (int index = 0; index < firstRoutes.length; index += 1) {
        expect(firstRoutes[index] == secondRoutes[index], first == second);
        if (first == second) {
          expect(firstRoutes[index].hashCode, secondRoutes[index].hashCode);
        }
      }
      expect(firstRoutes[2] == firstRoutes[3], isFalse);
    }
  });

  test('test_route_section_property_routes_sit_in_their_section', () {
    final List<AppRoute> routes = _buildRoutes('record');

    expect(routes.first.section, AppSection.projects);
    expect(const NewProjectRoute().section, AppSection.projects);
    expect(const NewWorkflowRoute().section, AppSection.workflows);
    for (final AppRoute route in routes.sublist(1, routes.length - 1)) {
      expect(route.section, AppSection.workflows);
    }
    expect(routes.last.section, AppSection.tasks);
  });
}
