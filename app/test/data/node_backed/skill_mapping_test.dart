import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';

RunId? _readWireRunId(node.SkillChangeOrigin origin) {
  return switch (origin) {
    node.PersonEdit() => null,
    node.ApprovedAgentRun(:final RunId runId) => runId,
    node.AutomaticAgentRun(:final RunId runId) => runId,
  };
}

RunId? _readRunId(SkillChangeOrigin origin) {
  return switch (origin) {
    PersonEdit() => null,
    AgentRunOrigin(:final RunId runId) => runId,
  };
}

void main() {
  test('test_map_skill_improvement_to_node_property_round_trips', () {
    for (final node.SkillImprovement wire in node.SkillImprovement.values) {
      final SkillImprovement improvement = mapSkillImprovementFromNode(wire);
      expect(mapSkillImprovementToNode(improvement), wire);
      expect(improvement.name, wire.name);
    }
  });

  test('test_map_skill_improvement_from_node_property_is_one_to_one', () {
    final Set<SkillImprovement> improvements = <SkillImprovement>{
      for (final node.SkillImprovement wire in node.SkillImprovement.values)
        mapSkillImprovementFromNode(wire),
    };
    expect(improvements, SkillImprovement.values.toSet());
  });

  test('test_map_skill_change_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9121);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SkillChange wire = node.SkillChange.fromJson(
        randomSkillChangeJson(random),
      );

      final SkillChange change = mapSkillChangeFromNode(wire);

      expect(change.savedAt, wire.savedAt);
      expect(change.replacedInstructions, wire.replacedInstructions);
      expect(_readRunId(change.origin), _readWireRunId(wire.origin));
      expect(change.origin is PersonEdit, wire.origin is node.PersonEdit);
      expect(
        change.origin is ApprovedAgentRun,
        wire.origin is node.ApprovedAgentRun,
      );
    }
  });

  test('test_map_skill_from_node_property_keeps_history_oldest_first', () {
    final Random random = seededRandom(9122);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Skill wire = node.Skill.fromJson(randomSkillJson(random));

      final Skill skill = mapSkillFromNode(wire);

      expect(
        <DateTime>[
          for (final SkillChange change in skill.history) change.savedAt,
        ],
        <DateTime>[
          for (final node.SkillChange change in wire.history) change.savedAt,
        ],
      );
      expect(skill.history.clear, throwsUnsupportedError);
    }
  });
}
