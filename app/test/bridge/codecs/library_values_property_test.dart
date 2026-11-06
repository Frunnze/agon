import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';

final class _LibraryChoiceFamily {
  const _LibraryChoiceFamily(this.typeName, this.decode, this.nodeNames);

  final String typeName;
  final JsonValueDecoder<WireNamed> decode;
  final List<String> nodeNames;
}

const List<_LibraryChoiceFamily> _families = <_LibraryChoiceFamily>[
  _LibraryChoiceFamily('skill_usage', SkillUsage.decode, nodeSkillUsages),
  _LibraryChoiceFamily('skill_source', SkillSource.decode, nodeSkillSources),
  _LibraryChoiceFamily(
    'skill_improvement',
    SkillImprovement.decode,
    nodeSkillImprovements,
  ),
];

List<SkillChange> _randomHistory(Random random) {
  final List<Object?> historyJson = randomListOf(
    random,
    randomSkillChangeJson,
  );
  return List<SkillChange>.of(decodeList(historyJson, SkillChange.fromJson));
}

Skill _skillWithHistory(Skill skill, List<SkillChange> history) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: history,
  );
}

void _testChoiceFamily(_LibraryChoiceFamily family, int seed) {
  test('test_${family.typeName}_decode_property_reads_every_node_name', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeName = pickOne(random, family.nodeNames);
      final Set<WireNamed> choices = <WireNamed>{};
      for (final String name in family.nodeNames) {
        choices.add(family.decode(name));
      }

      expect(family.decode(nodeName).wireName, nodeName);
      expect(choices.length, family.nodeNames.length);
    }
  });

  test('test_${family.typeName}_decode_property_rejects_other_names', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LibraryChoiceFamily other = pickOne(random, _families);
      final String otherName = pickOne(random, other.nodeNames);

      if (!family.nodeNames.contains(otherName)) {
        expect(() => family.decode(otherName), throwsFormatException);
      }
    }
  });

  test('test_${family.typeName}_decode_property_rejects_altered_names', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeName = pickOne(random, family.nodeNames);
      final List<Object?> alteredNames = <Object?>[
        nodeName.toUpperCase(),
        '$nodeName ',
        '_$nodeName',
        <Object?>[nodeName],
        null,
        family.nodeNames.indexOf(nodeName),
      ];

      for (final Object? alteredName in alteredNames) {
        expect(() => family.decode(alteredName), throwsFormatException);
      }
    }
  });
}

void main() {
  for (int index = 0; index < _families.length; index += 1) {
    _testChoiceFamily(_families[index], 5200 + 10 * index);
  }

  test('test_skill_constructor_property_history_is_unmodifiable', () {
    final Random random = seededRandom(5231);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = Skill.fromJson(randomSkillJson(random));
      final List<SkillChange> extraHistory = _randomHistory(random);

      final Skill rebuilt = _skillWithHistory(skill, _randomHistory(random));

      expect(
        () => rebuilt.history.addAll(extraHistory),
        throwsUnsupportedError,
      );
      expect(rebuilt.history.clear, throwsUnsupportedError);
    }
  });

  test('test_skill_constructor_property_history_is_a_copy', () {
    final Random random = seededRandom(5232);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = Skill.fromJson(randomSkillJson(random));
      final List<SkillChange> history = _randomHistory(random);
      final List<SkillChange> snapshot = List<SkillChange>.of(history);

      final Skill rebuilt = _skillWithHistory(skill, history);
      history.addAll(_randomHistory(random));
      history.removeRange(0, snapshot.length ~/ 2);

      expect(rebuilt.history, orderedEquals(snapshot));
    }
  });

  test('test_skill_constructor_property_keeps_history_in_order', () {
    final Random random = seededRandom(5233);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = Skill.fromJson(randomSkillJson(random));
      final List<SkillChange> history = _randomHistory(random);

      final Skill rebuilt = _skillWithHistory(skill, history);

      expect(rebuilt.history.length, history.length);
      for (int j = 0; j < history.length; j += 1) {
        expect(rebuilt.history[j], same(history[j]));
      }
    }
  });
}
