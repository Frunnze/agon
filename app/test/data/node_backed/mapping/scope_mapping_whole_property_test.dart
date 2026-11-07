import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import 'support/scope_mapping_values.dart';

void main() {
  test('test_map_scope_from_node_property_halves_stay_apart', () {
    final Random random = seededRandom(73709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Scope wire = node.Scope(
        workspaces: randomNodeWorkspaceScope(random),
        projects: randomNodeProjectScope(random),
      );

      final Scope scope = mapScopeFromNode(wire);

      expect(
        describeWorkspaceScope(scope.workspaces),
        describeNodeWorkspaceScope(wire.workspaces),
      );
      expect(
        describeProjectScope(scope.projects),
        describeNodeProjectScope(wire.projects),
      );
    }
  });

  test('test_map_scope_from_node_property_matches_the_half_mappers', () {
    final Random random = seededRandom(73710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Scope wire = node.Scope(
        workspaces: randomNodeWorkspaceScope(random),
        projects: randomNodeProjectScope(random),
      );

      final Scope scope = mapScopeFromNode(wire);

      expect(
        describeWorkspaceScope(scope.workspaces),
        describeWorkspaceScope(mapWorkspaceScopeFromNode(wire.workspaces)),
      );
      expect(
        describeProjectScope(scope.projects),
        describeProjectScope(mapProjectScopeFromNode(wire.projects)),
      );
    }
  });

  test('test_map_scope_to_node_property_round_trips_the_model', () {
    final Random random = seededRandom(73711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = Scope(
        workspaces: randomHostileWorkspaceScope(random),
        projects: randomHostileProjectScope(random),
      );

      final Scope mapped = mapScopeFromNode(mapScopeToNode(scope));

      expect(
        describeWorkspaceScope(mapped.workspaces),
        describeWorkspaceScope(scope.workspaces),
      );
      expect(
        describeProjectScope(mapped.projects),
        describeProjectScope(scope.projects),
      );
    }
  });

  test('test_map_scope_to_node_property_survives_node_json', () {
    final Random random = seededRandom(73712);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = Scope(
        workspaces: randomHostileWorkspaceScope(random),
        projects: randomHostileProjectScope(random),
      );
      final node.Scope wire = mapScopeToNode(scope);

      final node.Scope reread = node.Scope.fromJson(wire.toJson());

      expect(
        describeNodeWorkspaceScope(reread.workspaces),
        describeWorkspaceScope(scope.workspaces),
      );
      expect(
        describeNodeProjectScope(reread.projects),
        describeProjectScope(scope.projects),
      );
    }
  });
}
