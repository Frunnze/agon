import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_item_drafts.dart';
import '../../../support/random_inputs.dart';

DraftKind _findModelKind(node.ItemDraft wire) {
  return switch (wire) {
    node.WorkItemDraft() => DraftKind.values.byName(wire.kind.name),
    node.SkillItemDraft() => DraftKind.skill,
    node.RuleItemDraft() => DraftKind.rule,
  };
}

List<DraftKind> _findContradictingKinds(DraftedItem item) {
  final Set<DraftKind> fittingKinds = switch (item) {
    DraftedWork() => <DraftKind>{DraftKind.task, DraftKind.job},
    DraftedSkill() => <DraftKind>{DraftKind.skill},
    DraftedRule() => <DraftKind>{DraftKind.rule},
  };
  return <DraftKind>[
    for (final DraftKind kind in DraftKind.values)
      if (!fittingKinds.contains(kind)) kind,
  ];
}

void main() {
  test('test_map_draft_kind_to_node_property_is_one_to_one', () {
    final Set<node.DraftKind> wires = <node.DraftKind>{
      for (final DraftKind kind in DraftKind.values) mapDraftKindToNode(kind),
    };

    expect(wires, node.DraftKind.values.toSet());
  });

  test('test_map_draft_kind_to_node_property_survives_wire_decoding', () {
    for (final DraftKind kind in DraftKind.values) {
      final node.DraftKind wire = mapDraftKindToNode(kind);

      expect(node.DraftKind.decode(wire.wireName), same(wire));
      expect(DraftKind.values.byName(wire.name), same(kind));
    }
  });

  test('test_map_item_draft_from_node_property_freezes_hostile_problems', () {
    final Random random = seededRandom(72501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> problems = randomHostileTexts(random);
      final node.ItemDraftDone done = node.ItemDraftDone(
        draft: randomTypedItemDraft(random),
        problems: problems,
      );

      final ItemDraft draft = mapItemDraftFromNode(done);

      expect(draft.problems, problems);
      expect(() => draft.problems.add(''), throwsUnsupportedError);
    }
  });

  test(
    'test_map_item_draft_from_node_property_item_maps_back_to_the_draft',
    () {
      final Random random = seededRandom(72502);

      for (int i = 0; i < propertyIterations; i += 1) {
        final node.ItemDraft wire = randomTypedItemDraft(random);
        final node.ItemDraftDone done = node.ItemDraftDone(
          draft: wire,
          problems: randomHostileTexts(random),
        );

        final ItemDraft draft = mapItemDraftFromNode(done);

        final node.ItemDraft mappedBack = mapDraftedItemToNode(
          draft.item,
          _findModelKind(wire),
        );
        expect(mappedBack.toJson(), wire.toJson());
      }
    },
  );

  test('test_map_drafted_item_from_node_property_keeps_the_item_family', () {
    final Random random = seededRandom(72503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ItemDraft wire = randomTypedItemDraft(random);

      final DraftedItem item = mapDraftedItemFromNode(wire);

      expect(item is DraftedWork, wire is node.WorkItemDraft);
      expect(item is DraftedSkill, wire is node.SkillItemDraft);
      expect(item is DraftedRule, wire is node.RuleItemDraft);
    }
  });

  test('test_map_drafted_item_from_node_property_keeps_every_skill_field', () {
    final Random random = seededRandom(72504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SkillItemDraft wire = randomSkillItemDraft(random);

      final DraftedItem item = mapDraftedItemFromNode(wire);

      expect(item, isA<DraftedSkill>());
      final SkillDraft skill = (item as DraftedSkill).skill;
      expect(skill.name, wire.name);
      expect(skill.summary, wire.summary);
      expect(skill.instructions, wire.instructions);
      expect(mapScopeToNode(skill.scope).toJson(), wire.scope.toJson());
      expect(mapSkillUsageToNode(skill.usage), wire.usage);
      expect(mapSkillImprovementToNode(skill.improvement), wire.improvement);
    }
  });

  test('test_map_drafted_item_from_node_property_keeps_every_rule_field', () {
    final Random random = seededRandom(72505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RuleItemDraft wire = randomRuleItemDraft(random);

      final DraftedItem item = mapDraftedItemFromNode(wire);

      expect(item, isA<DraftedRule>());
      final RuleDraft rule = (item as DraftedRule).rule;
      expect(rule.title, wire.title);
      expect(rule.details, wire.details);
      expect(mapScopeToNode(rule.scope).toJson(), wire.scope.toJson());
    }
  });

  test(
    'test_map_drafted_item_to_node_property_rejects_a_contradicting_kind',
    () {
      final Random random = seededRandom(72506);

      for (int i = 0; i < propertyIterations; i += 1) {
        final DraftedItem item = mapDraftedItemFromNode(
          randomTypedItemDraft(random),
        );

        for (final DraftKind kind in _findContradictingKinds(item)) {
          expect(
            () => mapDraftedItemToNode(item, kind),
            throwsArgumentError,
            reason: '${item.runtimeType} sent as $kind',
          );
        }
      }
    },
  );

  test(
    'test_map_drafted_item_to_node_property_second_trip_changes_nothing',
    () {
      final Random random = seededRandom(72507);

      for (int i = 0; i < propertyIterations; i += 1) {
        final node.ItemDraft wire = randomTypedItemDraft(random);
        final DraftKind kind = _findModelKind(wire);

        final node.ItemDraft once = mapDraftedItemToNode(
          mapDraftedItemFromNode(wire),
          kind,
        );
        final node.ItemDraft twice = mapDraftedItemToNode(
          mapDraftedItemFromNode(once),
          kind,
        );

        expect(twice.toJson(), once.toJson());
      }
    },
  );
}
