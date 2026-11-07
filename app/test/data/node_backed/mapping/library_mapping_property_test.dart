import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart'
    as node;
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../support/random_inputs.dart';

typedef ChangeSummary = List<Object?>;

const String _approvedAgentRunOrigin = 'approved_agent_run';
const String _automaticAgentRunOrigin = 'automatic_agent_run';

ChangeSummary _summarizeChange(SkillChange change) {
  final SkillChangeOrigin origin = change.origin;
  final String? runIdText = switch (origin) {
    PersonEdit() => null,
    AgentRunOrigin() => origin.runId.value,
  };
  return <Object?>[
    origin.runtimeType,
    runIdText,
    change.savedAt,
    change.replacedInstructions,
  ];
}

SkillChange _mapChangeJson(Map<String, Object?> json) {
  return mapSkillChangeFromNode(node.SkillChange.fromJson(json));
}

Map<String, Object?> _changeJsonWithOrigin(
  Random random,
  Map<String, Object?> origin,
) {
  return <String, Object?>{...randomSkillChangeJson(random), 'origin': origin};
}

void main() {
  test('test_map_skill_change_origin_from_node_property_keeps_the_kind', () {
    final Random random = seededRandom(72401);
    final Map<String, Type> originTypes = <String, Type>{
      nodePersonEditOrigin: PersonEdit,
      _approvedAgentRunOrigin: ApprovedAgentRun,
      _automaticAgentRunOrigin: AutomaticAgentRun,
    };

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomSkillChangeJson(random);
      final Map<String, Object?> origin =
          json['origin']! as Map<String, Object?>;

      final SkillChange change = _mapChangeJson(json);

      expect(change.origin.runtimeType, originTypes[origin['kind']]);
    }
  });

  test('test_map_skill_change_origin_from_node_property_keeps_the_run', () {
    final Random random = seededRandom(72402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runIdText = randomUuidText(random);
      final String kind = pickOne(random, <String>[
        _approvedAgentRunOrigin,
        _automaticAgentRunOrigin,
      ]);

      final SkillChange change = _mapChangeJson(
        _changeJsonWithOrigin(random, <String, Object?>{
          'kind': kind,
          'run_id': runIdText,
        }),
      );

      final SkillChangeOrigin origin = change.origin;
      expect(origin, isA<AgentRunOrigin>());
      expect((origin as AgentRunOrigin).runId.value, runIdText);
    }
  });

  test('test_map_skill_change_origin_from_node_property_'
      'approved_and_automatic_stay_apart', () {
    final Random random = seededRandom(72403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runIdText = randomUuidText(random);
      final SkillChange approved = _mapChangeJson(
        _changeJsonWithOrigin(random, <String, Object?>{
          'kind': _approvedAgentRunOrigin,
          'run_id': runIdText,
        }),
      );
      final SkillChange automatic = _mapChangeJson(
        _changeJsonWithOrigin(random, <String, Object?>{
          'kind': _automaticAgentRunOrigin,
          'run_id': runIdText,
        }),
      );

      expect(approved.origin, isA<ApprovedAgentRun>());
      expect(automatic.origin, isA<AutomaticAgentRun>());
      expect(approved.origin, isNot(isA<AutomaticAgentRun>()));
      expect(automatic.origin, isNot(isA<ApprovedAgentRun>()));
    }
  });

  test('test_map_skill_change_from_node_property_keeps_hostile_text', () {
    final Random random = seededRandom(72404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String replacedInstructions = randomHostileText(random);
      final Map<String, Object?> json = <String, Object?>{
        ...randomSkillChangeJson(random),
        'replaced_instructions': replacedInstructions,
      };

      final SkillChange change = _mapChangeJson(json);

      expect(change.replacedInstructions, replacedInstructions);
    }
  });

  test(
    'test_map_skill_change_from_node_property_agrees_with_skill_history',
    () {
      final Random random = seededRandom(72405);

      for (int i = 0; i < propertyIterations; i += 1) {
        final node.Skill wire = node.Skill.fromJson(randomSkillJson(random));

        final Skill skill = mapSkillFromNode(wire);

        final List<ChangeSummary> alone = <ChangeSummary>[
          for (final node.SkillChange change in wire.history)
            _summarizeChange(mapSkillChangeFromNode(change)),
        ];
        final List<ChangeSummary> inSkill = <ChangeSummary>[
          for (final SkillChange change in skill.history)
            _summarizeChange(change),
        ];
        expect(inSkill, alone);
      }
    },
  );

  test('test_map_skill_from_node_property_keeps_each_change_in_order', () {
    final Random random = seededRandom(72406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Skill wire = node.Skill.fromJson(randomSkillJson(random));

      final Skill skill = mapSkillFromNode(wire);

      final List<String> replaced = <String>[
        for (final SkillChange change in skill.history)
          change.replacedInstructions,
      ];
      final List<String> wireReplaced = <String>[
        for (final node.SkillChange change in wire.history)
          change.replacedInstructions,
      ];
      expect(replaced, wireReplaced);
    }
  });

  test('test_map_rule_from_node_property_keeps_hostile_title_and_details', () {
    final Random random = seededRandom(72407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomHostileText(random);
      final String details = randomHostileText(random);
      final Map<String, Object?> json = <String, Object?>{
        ...randomRuleJson(random),
        'title': title,
        'details': details,
      };

      final Rule rule = mapRuleFromNode(node.Rule.fromJson(json));

      expect(rule.title, title);
      expect(rule.details, details);
    }
  });

  test(
    'test_map_rule_from_node_property_flipping_enabled_changes_only_it',
    () {
      final Random random = seededRandom(72408);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, Object?> json = randomRuleJson(random);
        final bool enabled = json['enabled']! as bool;
        final Map<String, Object?> flippedJson = <String, Object?>{
          ...json,
          'enabled': !enabled,
        };

        final Rule rule = mapRuleFromNode(node.Rule.fromJson(json));
        final Rule flipped = mapRuleFromNode(node.Rule.fromJson(flippedJson));

        expect(rule.enabled, enabled);
        expect(flipped.enabled, !enabled);
        expect(flipped.id, rule.id);
        expect(flipped.title, rule.title);
        expect(flipped.details, rule.details);
        expect(flipped.addedAt, rule.addedAt);
        expect(
          mapScopeToNode(flipped.scope).toJson(),
          mapScopeToNode(rule.scope).toJson(),
        );
      }
    },
  );
}
