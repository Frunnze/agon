import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/random_item_drafts.dart';

const Set<String> _nodeSkillDraftFields = <String>{
  'kind',
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
  'improvement',
};

const List<String> _skillFieldsTheNodeRequires = <String>[
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
];

const Set<String> _nodeRuleDraftFields = <String>{
  'kind',
  'title',
  'details',
  'scope',
};

const List<String> _ruleFieldsTheNodeRequires = <String>['title', 'scope'];

const List<String> _choiceNearMisses = <String>[
  'whenChosen',
  'when-chosen',
  'Automatic',
  'askMe',
  'ask me',
  'AUTO',
  '',
];

JsonObject _randomSkillDraftJson(Random random) {
  return <String, Object?>{
    'kind': 'skill',
    'name': randomHostileText(random),
    'summary': randomHostileText(random),
    'instructions': randomHostileText(random),
    'scope': randomScopeJson(random),
    'usage': pickOne(random, nodeSkillUsages),
    'improvement': pickOne(random, nodeSkillImprovements),
  };
}

JsonObject _randomRuleDraftJson(Random random) {
  return <String, Object?>{
    'kind': 'rule',
    'title': randomHostileText(random),
    'details': randomHostileText(random),
    'scope': randomScopeJson(random),
  };
}

Object? _decodeJsonText(JsonObject json) => jsonDecode(jsonEncode(json));

void main() {
  test('test_skill_item_draft_from_fields_property_keeps_node_values', () {
    final Random random = seededRandom(50901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomSkillDraftJson(random);

      final SkillItemDraft draft = SkillItemDraft.fromFields(json);

      expect(draft.name, json['name']);
      expect(draft.summary, json['summary']);
      expect(draft.instructions, json['instructions']);
      expect(draft.scope.toJson(), equals(json['scope']));
      expect(draft.usage.wireName, json['usage']);
      expect(draft.improvement.wireName, json['improvement']);
    }
  });

  test('test_skill_item_draft_from_fields_property_rejects_missing', () {
    final Random random = seededRandom(50902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomSkillDraftJson(random);
      json.remove(pickOne(random, _skillFieldsTheNodeRequires));

      expect(() => SkillItemDraft.fromFields(json), throwsFormatException);
    }
  });

  test('test_skill_item_draft_from_fields_property_rejects_near_misses', () {
    final Random random = seededRandom(50903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomSkillDraftJson(random);
      final String choiceField = pickOne(random, <String>[
        'usage',
        'improvement',
      ]);
      json[choiceField] = pickOne(random, _choiceNearMisses);

      expect(() => SkillItemDraft.fromFields(json), throwsFormatException);
    }
  });

  test('test_skill_item_draft_to_json_property_round_trips_as_text', () {
    final Random random = seededRandom(50904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillItemDraft draft = randomSkillItemDraft(random);

      final ItemDraft decoded = ItemDraft.fromJson(
        _decodeJsonText(draft.toJson()),
      );

      final SkillItemDraft skillDraft = decoded as SkillItemDraft;
      expect(skillDraft.name, draft.name);
      expect(skillDraft.summary, draft.summary);
      expect(skillDraft.instructions, draft.instructions);
      expect(skillDraft.scope.toJson(), equals(draft.scope.toJson()));
      expect(skillDraft.usage, same(draft.usage));
      expect(skillDraft.improvement, same(draft.improvement));
    }
  });

  test('test_skill_item_draft_to_json_property_writes_the_node_fields', () {
    final Random random = seededRandom(50905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomSkillItemDraft(random).toJson();

      expect(json.keys.toSet(), equals(_nodeSkillDraftFields));
      expect(json['kind'], 'skill');
      expect(json['usage'], isIn(nodeSkillUsages));
      expect(json['improvement'], isIn(nodeSkillImprovements));
    }
  });

  test('test_skill_item_draft_to_json_property_always_says_skill', () {
    final Random random = seededRandom(50906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomSkillDraftJson(random);
      json['kind'] = pickOne(random, nodeDraftKinds);

      final JsonObject encoded = SkillItemDraft.fromFields(json).toJson();

      expect(encoded['kind'], 'skill');
      expect(ItemDraft.fromJson(encoded), isA<SkillItemDraft>());
    }
  });

  test('test_rule_item_draft_from_fields_property_keeps_node_values', () {
    final Random random = seededRandom(50907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomRuleDraftJson(random);

      final RuleItemDraft draft = RuleItemDraft.fromFields(json);

      expect(draft.title, json['title']);
      expect(draft.details, json['details']);
      expect(draft.scope.toJson(), equals(json['scope']));
    }
  });

  test('test_rule_item_draft_from_fields_property_rejects_missing', () {
    final Random random = seededRandom(50908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomRuleDraftJson(random);
      json.remove(pickOne(random, _ruleFieldsTheNodeRequires));

      expect(() => RuleItemDraft.fromFields(json), throwsFormatException);
    }
  });

  test('test_rule_item_draft_from_fields_property_rejects_wrong_types', () {
    final Random random = seededRandom(50909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomRuleDraftJson(random);
      final String textField = pickOne(random, <String>['title', 'details']);
      json[textField] = <Object?>[randomHostileText(random)];
      final JsonObject scopeAsText = _randomRuleDraftJson(random);
      scopeAsText['scope'] = randomHostileText(random);

      expect(() => RuleItemDraft.fromFields(json), throwsFormatException);
      expect(
        () => RuleItemDraft.fromFields(scopeAsText),
        throwsFormatException,
      );
    }
  });

  test('test_rule_item_draft_to_json_property_round_trips_as_text', () {
    final Random random = seededRandom(50910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RuleItemDraft draft = randomRuleItemDraft(random);

      final ItemDraft decoded = ItemDraft.fromJson(
        _decodeJsonText(draft.toJson()),
      );

      final RuleItemDraft ruleDraft = decoded as RuleItemDraft;
      expect(ruleDraft.title, draft.title);
      expect(ruleDraft.details, draft.details);
      expect(ruleDraft.scope.toJson(), equals(draft.scope.toJson()));
    }
  });

  test('test_rule_item_draft_to_json_property_writes_the_node_fields', () {
    final Random random = seededRandom(50911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RuleItemDraft draft = randomRuleItemDraft(random);

      final JsonObject json = draft.toJson();

      expect(json.keys.toSet(), equals(_nodeRuleDraftFields));
      expect(json['kind'], 'rule');
      expect(json['title'], draft.title);
      expect(json['details'], draft.details);
    }
  });

  test('test_rule_item_draft_to_json_property_always_says_rule', () {
    final Random random = seededRandom(50912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomRuleDraftJson(random);
      json['kind'] = pickOne(random, nodeDraftKinds);

      final JsonObject encoded = RuleItemDraft.fromFields(json).toJson();

      expect(encoded['kind'], 'rule');
      expect(ItemDraft.fromJson(encoded), isA<RuleItemDraft>());
    }
  });
}
