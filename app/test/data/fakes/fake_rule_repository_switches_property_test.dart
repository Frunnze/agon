import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/rule_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';

typedef _Switch = Future<Rule> Function(RuleId ruleId);

_Switch _pickSwitch(Random random, CountedRules counted) {
  if (random.nextBool()) {
    return counted.repository.turnRuleOn;
  }
  return counted.repository.turnRuleOff;
}

void main() {
  test('${_typePrefix}_turn_rule_on_property_only_the_switch_'
      'changes', () async {
    final Random random = seededRandom(66101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final Rule picked = pickOne(random, seeded);

      final Rule switched = await counted.repository.turnRuleOn(picked.id);

      expect(switched.enabled, isTrue);
      expect(switched.id, picked.id);
      expect(switched.title, picked.title);
      expect(switched.details, picked.details);
      expect(switched.addedAt, picked.addedAt);
      expect(describeScope(switched.scope), describeScope(picked.scope));
    }
  });

  test('${_typePrefix}_turn_rule_on_property_is_idempotent', () async {
    final Random random = seededRandom(66102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final RuleId picked = pickOne(random, seeded).id;

      final Rule once = await counted.repository.turnRuleOn(picked);
      final Rule twice = await counted.repository.turnRuleOn(picked);

      expect(describeRuleContent(twice), describeRuleContent(once));
      expect(counted.repository.listRules().length, seeded.length);
    }
  });

  test('${_typePrefix}_turn_rule_on_property_unknown_ids_change_'
      'nothing', () async {
    final Random random = seededRandom(66103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);

      await expectLater(
        counted.repository.turnRuleOn(randomMissingRuleId(random)),
        throwsA(isA<RecordNotFound>()),
      );

      expect(counted.repository.listRules(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_turn_rule_off_property_only_the_switch_'
      'changes', () async {
    final Random random = seededRandom(66104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final Rule picked = pickOne(random, seeded);

      final Rule switched = await counted.repository.turnRuleOff(picked.id);

      expect(switched.enabled, isFalse);
      expect(switched.title, picked.title);
      expect(switched.details, picked.details);
      expect(switched.addedAt, picked.addedAt);
      expect(describeScope(switched.scope), describeScope(picked.scope));
    }
  });

  test('${_typePrefix}_turn_rule_off_property_off_then_on_round_'
      'trips', () async {
    final Random random = seededRandom(66105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final Rule picked = pickOne(random, seeded);

      await counted.repository.turnRuleOff(picked.id);
      final Rule restored = picked.enabled
          ? await counted.repository.turnRuleOn(picked.id)
          : counted.repository.findRule(picked.id);

      expect(describeRuleContent(restored), describeRuleContent(picked));
    }
  });

  test('${_typePrefix}_turn_rule_off_property_unknown_ids_change_'
      'nothing', () async {
    final Random random = seededRandom(66106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);

      await expectLater(
        counted.repository.turnRuleOff(randomMissingRuleId(random)),
        throwsA(isA<RecordNotFound>()),
      );

      expect(counted.repository.listRules(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_store_rule_property_keeps_the_place_in_the_'
      'list', () async {
    final Random random = seededRandom(66107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final int switchCount = 1 + random.nextInt(6);

      for (int step = 0; step < switchCount; step += 1) {
        final _Switch switchRule = _pickSwitch(random, counted);
        await switchRule(pickOne(random, seeded).id);
      }

      expect(listRuleIds(counted.repository), <RuleId>[
        for (final Rule rule in seeded) rule.id,
      ]);
      expect(counted.notifications.count, switchCount);
    }
  });

  test('${_typePrefix}_store_rule_property_leaves_other_rules_'
      'alone', () async {
    final Random random = seededRandom(66108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final Rule picked = pickOne(random, seeded);

      await counted.repository.updateRule(picked.id, randomRuleDraft(random));

      for (final Rule other in seeded) {
        if (other.id != picked.id) {
          expect(
            identical(counted.repository.findRule(other.id), other),
            isTrue,
          );
        }
      }
    }
  });

  test('${_typePrefix}_store_rule_property_returns_what_is_'
      'listed', () async {
    final Random random = seededRandom(66109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final RuleId picked = pickOne(random, seeded).id;
      final _Switch switchRule = _pickSwitch(random, counted);

      final Rule stored = await switchRule(picked);

      expect(identical(counted.repository.findRule(picked), stored), isTrue);
      expect(counted.repository.listRules(), contains(stored));
    }
  });
}
