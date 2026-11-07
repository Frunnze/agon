import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import 'support/scope_mapping_values.dart';

void main() {
  test('test_map_workspace_scope_from_node_property_keeps_repeated_ids', () {
    final Random random = seededRandom(73701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkspaceScope wire = randomNodeWorkspaceScope(random);

      final WorkspaceScope scope = mapWorkspaceScopeFromNode(wire);

      expect(describeWorkspaceScope(scope), describeNodeWorkspaceScope(wire));
    }
  });

  test('test_map_workspace_scope_from_node_property_ids_are_frozen', () {
    final Random random = seededRandom(73702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope scope = mapWorkspaceScopeFromNode(
        node.OnlyWorkspaces(workspaces: randomWorkspaceIdsWithRepeats(random)),
      );

      final OnlyWorkspaces only = scope as OnlyWorkspaces;
      expect(
        () => only.workspaces.add(WorkspaceId(randomText(random))),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_workspace_scope_to_node_property_round_trips_the_model', () {
    final Random random = seededRandom(73703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope scope = randomHostileWorkspaceScope(random);

      final WorkspaceScope mapped = mapWorkspaceScopeFromNode(
        mapWorkspaceScopeToNode(scope),
      );

      expect(describeWorkspaceScope(mapped), describeWorkspaceScope(scope));
    }
  });

  test('test_map_workspace_scope_to_node_property_survives_node_json', () {
    final Random random = seededRandom(73704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope scope = randomHostileWorkspaceScope(random);
      final node.WorkspaceScope wire = mapWorkspaceScopeToNode(scope);

      final node.WorkspaceScope reread = node.WorkspaceScope.fromJson(
        wire.toJson(),
      );

      expect(
        describeNodeWorkspaceScope(reread),
        describeWorkspaceScope(scope),
      );
    }
  });

  test('test_map_project_scope_from_node_property_keeps_repeated_ids', () {
    final Random random = seededRandom(73705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ProjectScope wire = randomNodeProjectScope(random);

      final ProjectScope scope = mapProjectScopeFromNode(wire);

      expect(describeProjectScope(scope), describeNodeProjectScope(wire));
    }
  });

  test('test_map_project_scope_from_node_property_ids_are_frozen', () {
    final Random random = seededRandom(73706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectScope scope = mapProjectScopeFromNode(
        node.OnlyProjects(projects: randomProjectIdsWithRepeats(random)),
      );

      final OnlyProjects only = scope as OnlyProjects;
      expect(
        () => only.projects.add(ProjectId(randomText(random))),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_project_scope_to_node_property_round_trips_the_model', () {
    final Random random = seededRandom(73707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectScope scope = randomHostileProjectScope(random);

      final ProjectScope mapped = mapProjectScopeFromNode(
        mapProjectScopeToNode(scope),
      );

      expect(describeProjectScope(mapped), describeProjectScope(scope));
    }
  });

  test('test_map_project_scope_to_node_property_survives_node_json', () {
    final Random random = seededRandom(73708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectScope scope = randomHostileProjectScope(random);
      final node.ProjectScope wire = mapProjectScopeToNode(scope);

      final node.ProjectScope reread = node.ProjectScope.fromJson(
        wire.toJson(),
      );

      expect(describeNodeProjectScope(reread), describeProjectScope(scope));
    }
  });
}
