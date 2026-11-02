import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';

void main() {
  test('test_map_workspace_scope_to_node_property_round_trips', () {
    final Random random = seededRandom(9101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkspaceScope wire = node.WorkspaceScope.fromJson(
        randomWorkspaceScopeJson(random),
      );
      final WorkspaceScope scope = mapWorkspaceScopeFromNode(wire);
      expect(mapWorkspaceScopeToNode(scope).toJson(), wire.toJson());
    }
  });

  test('test_map_workspace_scope_from_node_property_keeps_ids', () {
    final Random random = seededRandom(9102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkspaceScope wire = node.WorkspaceScope.fromJson(
        randomWorkspaceScopeJson(random),
      );
      final WorkspaceScope scope = mapWorkspaceScopeFromNode(wire);
      expect(scope is AllWorkspaces, wire is node.AllWorkspaces);
      if (scope is OnlyWorkspaces && wire is node.OnlyWorkspaces) {
        expect(scope.workspaces, wire.workspaces);
      }
    }
  });

  test('test_map_project_scope_to_node_property_round_trips', () {
    final Random random = seededRandom(9103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ProjectScope wire = node.ProjectScope.fromJson(
        randomProjectScopeJson(random),
      );
      final ProjectScope scope = mapProjectScopeFromNode(wire);
      expect(mapProjectScopeToNode(scope).toJson(), wire.toJson());
    }
  });

  test('test_map_project_scope_from_node_property_keeps_kind', () {
    final Random random = seededRandom(9104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ProjectScope wire = node.ProjectScope.fromJson(
        randomProjectScopeJson(random),
      );
      expect(
        mapProjectScopeFromNode(wire) is AllProjects,
        wire is node.AllProjects,
      );
    }
  });

  test('test_map_scope_to_node_property_round_trips', () {
    final Random random = seededRandom(9105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Scope wire = node.Scope.fromJson(randomScopeJson(random));
      final Scope scope = mapScopeFromNode(wire);
      expect(mapScopeToNode(scope).toJson(), wire.toJson());
    }
  });

  test('test_map_scope_from_node_property_is_total', () {
    final Random random = seededRandom(9106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Scope wire = node.Scope.fromJson(randomScopeJson(random));
      expect(() => mapScopeFromNode(wire), returnsNormally);
    }
  });

  test('test_map_device_role_to_node_property_round_trips', () {
    for (final node.DeviceRole wire in node.DeviceRole.values) {
      final DeviceRole role = mapDeviceRoleFromNode(wire);
      expect(mapDeviceRoleToNode(role), wire);
    }
  });

  test('test_map_device_role_from_node_property_is_one_to_one', () {
    final Set<DeviceRole> roles = <DeviceRole>{
      for (final node.DeviceRole wire in node.DeviceRole.values)
        mapDeviceRoleFromNode(wire),
    };
    expect(roles, DeviceRole.values.toSet());
  });

  test('test_map_hardware_key_kind_from_node_property_is_one_to_one', () {
    final Set<HardwareKeyKind> kinds = <HardwareKeyKind>{
      for (final node.HardwareKeyKind wire in node.HardwareKeyKind.values)
        mapHardwareKeyKindFromNode(wire),
    };
    expect(kinds, HardwareKeyKind.values.toSet());
  });

  test('test_map_device_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Device wire = node.Device.fromJson(randomDeviceJson(random));
      final Device device = mapDeviceFromNode(wire);
      expect(device.id, wire.id);
      expect(device.name, wire.name);
      expect(mapDeviceRoleToNode(device.role), wire.role);
      expect(device.keyKind.name, wire.keyKind.name);
      expect(device.signingPublicKey, wire.signingPublicKey);
      expect(device.sealingPublicKey, wire.sealingPublicKey);
      expect(device.workspaces, wire.workspaces);
      expect(device.pairedAt, wire.pairedAt);
      expect(device.approvedBy, wire.approvedBy);
      expect(device.lastSeen, wire.lastSeen);
      expect(device.revoked, wire.revoked);
    }
  });

  test('test_map_workspace_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Workspace wire = node.Workspace.fromJson(
        randomWorkspaceJson(random),
      );
      final Workspace workspace = mapWorkspaceFromNode(wire);
      expect(workspace.id, wire.id);
      expect(workspace.name, wire.name);
      expect(workspace.appServerAddress, wire.appServerAddress);
    }
  });

  test('test_map_agent_access_to_node_property_round_trips', () {
    for (final node.AgentAccess wire in node.AgentAccess.values) {
      expect(mapAgentAccessToNode(mapAgentAccessFromNode(wire)), wire);
    }
  });

  test('test_map_agent_access_from_node_property_is_one_to_one', () {
    final Set<AgentAccess> accesses = <AgentAccess>{
      for (final node.AgentAccess wire in node.AgentAccess.values)
        mapAgentAccessFromNode(wire),
    };
    expect(accesses, AgentAccess.values.toSet());
  });

  test('test_map_repository_to_node_property_round_trips', () {
    final Random random = seededRandom(9109);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Repository wire = node.Repository.fromJson(
        randomRepositoryJson(random),
      );
      final Repository repository = mapRepositoryFromNode(wire);
      expect(mapRepositoryToNode(repository).toJson(), wire.toJson());
    }
  });

  test('test_map_repository_from_node_property_keeps_address', () {
    final Random random = seededRandom(9110);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Repository wire = node.Repository.fromJson(
        randomRepositoryJson(random),
      );
      final Repository repository = mapRepositoryFromNode(wire);
      expect(repository.address, wire.address);
      expect(repository.defaultBranch, wire.defaultBranch);
    }
  });

  test('test_map_project_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9111);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Project wire = node.Project.fromJson(
        randomProjectJson(random),
      );
      final Project project = mapProjectFromNode(wire);
      expect(project.id, wire.id);
      expect(project.workspaceId, wire.workspaceId);
      expect(project.name, wire.name);
      final List<Object?> repositories = <Object?>[
        for (final Repository repository in project.repositories)
          mapRepositoryToNode(repository).toJson(),
      ];
      expect(repositories, wire.toJson()['repositories']);
    }
  });

  test('test_map_skill_usage_to_node_property_round_trips', () {
    for (final node.SkillUsage wire in node.SkillUsage.values) {
      expect(mapSkillUsageToNode(mapSkillUsageFromNode(wire)), wire);
    }
  });

  test('test_map_skill_usage_from_node_property_is_one_to_one', () {
    final Set<SkillUsage> usages = <SkillUsage>{
      for (final node.SkillUsage wire in node.SkillUsage.values)
        mapSkillUsageFromNode(wire),
    };
    expect(usages, SkillUsage.values.toSet());
  });

  test('test_map_skill_source_from_node_property_is_one_to_one', () {
    final Set<SkillSource> sources = <SkillSource>{
      for (final node.SkillSource wire in node.SkillSource.values)
        mapSkillSourceFromNode(wire),
    };
    expect(sources, SkillSource.values.toSet());
  });

  test('test_map_skill_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9112);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Skill wire = node.Skill.fromJson(randomSkillJson(random));
      final Skill skill = mapSkillFromNode(wire);
      expect(skill.id, wire.id);
      expect(skill.name, wire.name);
      expect(skill.summary, wire.summary);
      expect(skill.instructions, wire.instructions);
      expect(mapScopeToNode(skill.scope).toJson(), wire.scope.toJson());
      expect(mapSkillUsageToNode(skill.usage), wire.usage);
      expect(skill.source, mapSkillSourceFromNode(wire.source));
    }
  });

  test('test_map_rule_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9113);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Rule wire = node.Rule.fromJson(randomRuleJson(random));
      final Rule rule = mapRuleFromNode(wire);
      expect(rule.id, wire.id);
      expect(rule.title, wire.title);
      expect(rule.details, wire.details);
      expect(mapScopeToNode(rule.scope).toJson(), wire.scope.toJson());
      expect(rule.enabled, wire.enabled);
      expect(rule.addedAt, wire.addedAt);
    }
  });
}
