import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/node_wire_names.dart';

void main() {
  test('test_map_skill_usage_from_node_property_keeps_the_choice_name', () {
    for (final node.SkillUsage wire in node.SkillUsage.values) {
      expect(mapSkillUsageFromNode(wire).name, wire.name);
    }
  });

  test('test_map_skill_usage_from_node_property_wire_names_cover_usages', () {
    final Set<SkillUsage> usages = <SkillUsage>{
      for (final String wireName in nodeSkillUsages)
        mapSkillUsageFromNode(node.SkillUsage.decode(wireName)),
    };

    expect(nodeSkillUsages, hasLength(SkillUsage.values.length));
    expect(usages, SkillUsage.values.toSet());
  });

  test('test_map_skill_usage_to_node_property_is_one_to_one', () {
    final Set<node.SkillUsage> wires = <node.SkillUsage>{
      for (final SkillUsage usage in SkillUsage.values)
        mapSkillUsageToNode(usage),
    };

    expect(wires, node.SkillUsage.values.toSet());
  });

  test('test_map_skill_usage_to_node_property_round_trips_the_model', () {
    for (final SkillUsage usage in SkillUsage.values) {
      final node.SkillUsage wire = mapSkillUsageToNode(usage);

      expect(mapSkillUsageFromNode(wire), same(usage));
      expect(node.SkillUsage.decode(wire.wireName), same(wire));
    }
  });

  test('test_map_skill_source_from_node_property_keeps_the_choice_name', () {
    for (final node.SkillSource wire in node.SkillSource.values) {
      expect(mapSkillSourceFromNode(wire).name, wire.name);
    }
  });

  test(
    'test_map_skill_source_from_node_property_wire_names_cover_sources',
    () {
      final Set<SkillSource> sources = <SkillSource>{
        for (final String wireName in nodeSkillSources)
          mapSkillSourceFromNode(node.SkillSource.decode(wireName)),
      };

      expect(nodeSkillSources, hasLength(SkillSource.values.length));
      expect(sources, SkillSource.values.toSet());
    },
  );

  test('test_map_skill_improvement_from_node_property_keeps_the_name', () {
    for (final node.SkillImprovement wire in node.SkillImprovement.values) {
      expect(mapSkillImprovementFromNode(wire).name, wire.name);
    }
  });

  test(
    'test_map_skill_improvement_from_node_property_wire_names_cover_all',
    () {
      final Set<SkillImprovement> improvements = <SkillImprovement>{
        for (final String wireName in nodeSkillImprovements)
          mapSkillImprovementFromNode(node.SkillImprovement.decode(wireName)),
      };

      expect(nodeSkillImprovements, hasLength(SkillImprovement.values.length));
      expect(improvements, SkillImprovement.values.toSet());
    },
  );

  test('test_map_skill_improvement_to_node_property_is_one_to_one', () {
    final Set<node.SkillImprovement> wires = <node.SkillImprovement>{
      for (final SkillImprovement improvement in SkillImprovement.values)
        mapSkillImprovementToNode(improvement),
    };

    expect(wires, node.SkillImprovement.values.toSet());
  });

  test(
    'test_map_skill_improvement_to_node_property_round_trips_the_model',
    () {
      for (final SkillImprovement improvement in SkillImprovement.values) {
        final node.SkillImprovement wire = mapSkillImprovementToNode(
          improvement,
        );

        expect(mapSkillImprovementFromNode(wire), same(improvement));
        expect(node.SkillImprovement.decode(wire.wireName), same(wire));
      }
    },
  );
}
