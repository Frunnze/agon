import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/random_moments.dart';
import '../support/random_catalog_json.dart';

const String _historyField = 'history';
const String _addedAtField = 'added_at';
const String _markdownField = 'markdown';

const Set<String> _nodeSkillFields = <String>{
  'id',
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
  'source',
  'improvement',
  _historyField,
};

const Set<String> _nodeRuleFields = <String>{
  'id',
  'title',
  'details',
  'scope',
  'enabled',
  _addedAtField,
};

Object? _throughJsonText(Object? json) => jsonDecode(jsonEncode(json));

JsonObject _withoutField(JsonObject fields, String field) {
  final JsonObject remaining = Map<String, Object?>.of(fields);
  remaining.remove(field);
  return remaining;
}

String _randomMarkdown(Random random) {
  final String phrase = randomWordPhrase(random);
  return '# ${randomText(random)}\r\n\t- $phrase\n\n${randomText(random)} ';
}

void main() {
  test('test_skill_from_json_property_every_required_field_is_required', () {
    final Random random = seededRandom(5241);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject skillJson = randomSkillJson(random);
      final Set<String> required = _nodeSkillFields.difference(<String>{
        _historyField,
      });

      for (final String field in required) {
        expect(
          () => Skill.fromJson(_withoutField(skillJson, field)),
          throwsFormatException,
        );
      }
    }
  });

  test('test_skill_from_json_property_unknown_fields_change_nothing', () {
    final Random random = seededRandom(5242);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject skillJson = randomSkillJson(random);
      final JsonObject widened = Map<String, Object?>.of(skillJson);
      widened['${randomText(random)}~'] = randomArbitraryJson(random);

      final JsonObject plain = Skill.fromJson(skillJson).toJson();
      final JsonObject widenedEncoded = Skill.fromJson(widened).toJson();

      expect(_throughJsonText(widenedEncoded), _throughJsonText(plain));
    }
  });

  test('test_skill_to_json_property_writes_exactly_the_node_fields', () {
    final Random random = seededRandom(5243);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject skillJson = randomSkillJson(random);
      if (random.nextBool()) {
        skillJson.remove(_historyField);
      }

      final JsonObject encoded = Skill.fromJson(skillJson).toJson();

      expect(encoded.keys.toSet(), equals(_nodeSkillFields));
    }
  });

  test('test_skill_to_json_property_is_a_fixpoint_of_from_json', () {
    final Random random = seededRandom(5244);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = Skill.fromJson(randomSkillJson(random))
          .toJson();

      final JsonObject reencoded = Skill.fromJson(encoded).toJson();

      expect(_throughJsonText(reencoded), _throughJsonText(encoded));
    }
  });

  test('test_skill_to_json_property_survives_json_text', () {
    final Random random = seededRandom(5245);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = Skill.fromJson(randomSkillJson(random))
          .toJson();

      expect(_throughJsonText(encoded), equals(encoded));
    }
  });

  test('test_rule_from_json_property_every_field_is_required', () {
    final Random random = seededRandom(5246);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject ruleJson = randomRuleJson(random);

      for (final String field in _nodeRuleFields) {
        expect(
          () => Rule.fromJson(_withoutField(ruleJson, field)),
          throwsFormatException,
        );
      }
    }
  });

  test('test_rule_from_json_property_offset_added_at_is_the_same_instant', () {
    final Random random = seededRandom(5247);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime addedAt = randomPreciseMoment(random).toUtc();
      final JsonObject ruleJson = randomRuleJson(random);
      final String addedAtText = writeMomentWithRandomOffset(random, addedAt);
      ruleJson[_addedAtField] = addedAtText;

      final Rule rule = Rule.fromJson(ruleJson);

      expect(rule.addedAt, equals(addedAt));
      expect(rule.toJson()[_addedAtField], encodeMoment(addedAt));
    }
  });

  test('test_rule_to_json_property_writes_exactly_the_node_fields', () {
    final Random random = seededRandom(5248);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = Rule.fromJson(randomRuleJson(random));
      final JsonObject encoded = rule.toJson();

      expect(encoded.keys.toSet(), equals(_nodeRuleFields));
      expect(_throughJsonText(encoded), equals(encoded));
    }
  });

  test('test_rule_to_json_property_is_a_fixpoint_of_from_json', () {
    final Random random = seededRandom(5249);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = Rule.fromJson(randomRuleJson(random));
      final JsonObject encoded = rule.toJson();

      final JsonObject reencoded = Rule.fromJson(encoded).toJson();

      expect(_throughJsonText(reencoded), _throughJsonText(encoded));
    }
  });

  test('test_rule_to_json_property_writes_added_at_as_utc_text', () {
    final Random random = seededRandom(5250);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = Rule.fromJson(randomRuleJson(random));
      final Rule localRule = Rule(
        id: rule.id,
        title: rule.title,
        details: rule.details,
        scope: rule.scope,
        enabled: rule.enabled,
        addedAt: rule.addedAt.toLocal(),
      );

      final Object? addedAtText = localRule.toJson()[_addedAtField];

      expect(addedAtText, rule.toJson()[_addedAtField]);
      expect(decodeMoment(addedAtText), equals(rule.addedAt));
    }
  });

  test(
    'test_agents_markdown_view_from_json_property_keeps_markdown_exactly',
    () {
      final Random random = seededRandom(5251);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String markdown = _randomMarkdown(random);
        final Object? viewJson = _throughJsonText(<String, Object?>{
          _markdownField: markdown,
        });

        final AgentsMarkdownView view = AgentsMarkdownView.fromJson(viewJson);

        expect(view.markdown, markdown);
      }
    },
  );

  test('test_agents_markdown_view_to_json_property_writes_only_markdown', () {
    final Random random = seededRandom(5252);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String markdown = _randomMarkdown(random);
      final AgentsMarkdownView view = AgentsMarkdownView(markdown: markdown);

      final JsonObject expected = <String, Object?>{_markdownField: markdown};

      expect(view.toJson(), equals(expected));
    }
  });

  test(
    'test_agents_markdown_view_to_json_property_round_trips_through_json',
    () {
      final Random random = seededRandom(5253);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String markdown = _randomMarkdown(random);
        final AgentsMarkdownView view = AgentsMarkdownView(markdown: markdown);

        final Object? viewJson = _throughJsonText(view.toJson());

        expect(AgentsMarkdownView.fromJson(viewJson).markdown, markdown);
      }
    },
  );
}
