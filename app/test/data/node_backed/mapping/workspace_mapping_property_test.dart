import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../support/random_inputs.dart';

List<String> _randomPatternsWithRepeats(Random random) {
  final List<String> patterns = randomHostileTexts(random);
  if (patterns.isNotEmpty && random.nextBool()) {
    patterns.add(pickOne(random, patterns));
  }
  return patterns;
}

node.Workspace _randomHostileWorkspace(Random random) {
  return node.Workspace.fromJson(<String, Object?>{
    ...randomWorkspaceJson(random),
    'name': randomHostileText(random),
    'app_server_address': randomHostileText(random),
    'protected_files': <String, Object?>{
      'patterns': _randomPatternsWithRepeats(random),
    },
  });
}

node.Repository _randomHostileRepository(Random random) {
  return node.Repository.fromJson(<String, Object?>{
    ...randomRepositoryJson(random),
    'address': randomHostileText(random),
    'default_branch': randomHostileText(random),
  });
}

node.Project _randomProjectWithRepeats(Random random) {
  final List<Object?> repositories = randomListOf(
    random,
    randomRepositoryJson,
  );
  if (repositories.isNotEmpty && random.nextBool()) {
    repositories.add(pickOne(random, repositories));
  }
  return node.Project.fromJson(<String, Object?>{
    ...randomProjectJson(random),
    'name': randomHostileText(random),
    'repositories': repositories,
  });
}

void main() {
  test('test_map_workspace_from_node_property_keeps_hostile_texts', () {
    final Random random = seededRandom(74501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Workspace wire = _randomHostileWorkspace(random);
      final Workspace workspace = mapWorkspaceFromNode(wire);

      expect(workspace.id, wire.id);
      expect(workspace.name, wire.name);
      expect(workspace.appServerAddress, wire.appServerAddress);
      expect(workspace.protectedFiles, wire.protectedFiles);
    }
  });

  test('test_map_workspace_from_node_property_policy_is_one_to_one', () {
    final Random random = seededRandom(74502);
    for (final String policyName in nodeApprovalPolicies) {
      final node.Workspace wire = node.Workspace.fromJson(<String, Object?>{
        ...randomWorkspaceJson(random),
        'approval_policy': policyName,
      });
      final Workspace workspace = mapWorkspaceFromNode(wire);

      expect(
        mapApprovalPolicyToNode(workspace.approvalPolicy).wireName,
        policyName,
      );
    }
  });

  test('test_map_agent_access_from_node_property_keeps_access_name', () {
    for (final node.AgentAccess wire in node.AgentAccess.values) {
      expect(mapAgentAccessFromNode(wire).name, wire.name);
    }
  });

  test('test_map_agent_access_from_node_property_repository_access', () {
    final Random random = seededRandom(74503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Repository wire = node.Repository.fromJson(
        randomRepositoryJson(random),
      );
      final Repository repository = mapRepositoryFromNode(wire);

      expect(repository.agentAccess, mapAgentAccessFromNode(wire.agentAccess));
      expect(repository.agentAccess.name, wire.agentAccess.name);
    }
  });

  test('test_map_agent_access_to_node_property_model_round_trips', () {
    for (final AgentAccess access in AgentAccess.values) {
      expect(mapAgentAccessFromNode(mapAgentAccessToNode(access)), access);
    }
  });

  test('test_map_agent_access_to_node_property_covers_rust_wire_names', () {
    final List<String> wireNames = <String>[
      for (final AgentAccess access in AgentAccess.values)
        mapAgentAccessToNode(access).wireName,
    ];

    expect(wireNames.toSet(), nodeAgentAccesses.toSet());
    expect(wireNames.length, nodeAgentAccesses.length);
  });

  test('test_map_repository_from_node_property_keeps_hostile_texts', () {
    final Random random = seededRandom(74504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Repository wire = _randomHostileRepository(random);
      final Repository repository = mapRepositoryFromNode(wire);

      expect(repository.address, wire.address);
      expect(repository.defaultBranch, wire.defaultBranch);
      expect(repository.agentAccess.name, wire.agentAccess.name);
    }
  });

  test('test_map_repository_from_node_property_access_is_kept', () {
    final Random random = seededRandom(74505);
    for (final node.AgentAccess access in node.AgentAccess.values) {
      final node.Repository wire = node.Repository(
        address: randomHostileText(random),
        defaultBranch: randomHostileText(random),
        agentAccess: access,
      );

      expect(
        mapRepositoryToNode(mapRepositoryFromNode(wire)).agentAccess,
        access,
      );
    }
  });

  test('test_map_repository_to_node_property_model_round_trips', () {
    final Random random = seededRandom(74506);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repository = Repository(
        address: randomHostileText(random),
        defaultBranch: randomHostileText(random),
        agentAccess: pickOne(random, AgentAccess.values),
      );
      final Repository returned = mapRepositoryFromNode(
        mapRepositoryToNode(repository),
      );

      expect(returned.address, repository.address);
      expect(returned.defaultBranch, repository.defaultBranch);
      expect(returned.agentAccess, repository.agentAccess);
    }
  });

  test('test_map_repository_to_node_property_json_decodes_back', () {
    final Random random = seededRandom(74507);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repository = mapRepositoryFromNode(
        _randomHostileRepository(random),
      );
      final Map<String, Object?> json = mapRepositoryToNode(repository)
          .toJson();

      expect(node.Repository.fromJson(json).toJson(), json);
    }
  });

  test('test_map_project_from_node_property_keeps_repository_order', () {
    final Random random = seededRandom(74508);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Project wire = _randomProjectWithRepeats(random);
      final Project project = mapProjectFromNode(wire);

      expect(<Object?>[
        for (final Repository repository in project.repositories)
          mapRepositoryToNode(repository).toJson(),
      ], wire.toJson()['repositories']);
      expect(project.name, wire.name);
    }
  });

  test('test_map_project_from_node_property_repositories_are_frozen', () {
    final Random random = seededRandom(74509);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = mapProjectFromNode(
        _randomProjectWithRepeats(random),
      );

      expect(project.repositories.clear, throwsUnsupportedError);
    }
  });
}
