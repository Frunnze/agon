import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import 'support/rule_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';
const int _largestCreatedCount = 4;
const List<String> _blankTitles = <String>['', '  ', '\t\n', '　'];

RuleDraft _randomBlankDraft(Random random) {
  return RuleDraft(
    title: pickOne(random, _blankTitles),
    details: randomText(random),
    scope: randomScope(random),
  );
}

void main() {
  test('${_typePrefix}_create_rule_property_starts_on_at_the_clock_'
      'time', () async {
    final Random random = seededRandom(66201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRules counted = buildCountedRules(
        random,
        randomSeededRules(random),
      );
      final RuleDraft draft = randomRuleDraft(random);

      final Rule created = await counted.repository.createRule(draft);

      expect(created.enabled, isTrue);
      expect(created.addedAt, counted.now);
      expect(created.details, draft.details);
      expect(describeScope(created.scope), describeScope(draft.scope));
      expect(
        identical(counted.repository.findRule(created.id), created),
        isTrue,
      );
      expect(counted.notifications.count, 1);
    }
  });

  test('${_typePrefix}_create_rule_property_new_ids_never_repeat_a_'
      'listed_id', () async {
    final Random random = seededRandom(66202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = <Rule>[
        ...randomSeededRules(random),
        for (int created = 1; created <= _largestCreatedCount; created += 1)
          if (random.nextBool())
            randomRuleWithId(random, RuleId('$createdRulePrefix$created')),
      ];
      final CountedRules counted = buildCountedRules(random, seeded);
      final int createCount = 1 + random.nextInt(_largestCreatedCount);

      for (int created = 0; created < createCount; created += 1) {
        await counted.repository.createRule(randomRuleDraft(random));
      }

      final List<RuleId> ruleIds = listRuleIds(counted.repository);
      expect(ruleIds.toSet().length, ruleIds.length);
      expect(ruleIds.length, seeded.length + createCount);
    }
  });

  test('${_typePrefix}_create_rule_property_blank_titles_change_'
      'nothing', () async {
    final Random random = seededRandom(66203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);

      await expectLater(
        counted.repository.createRule(_randomBlankDraft(random)),
        throwsArgumentError,
      );

      expect(counted.repository.listRules(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_update_rule_property_keeps_the_switch_and_'
      'time', () async {
    final Random random = seededRandom(66204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final Rule picked = pickOne(random, seeded);
      final RuleDraft draft = randomRuleDraft(random);

      final Rule updated = await counted.repository.updateRule(
        picked.id,
        draft,
      );

      expect(updated.id, picked.id);
      expect(updated.enabled, picked.enabled);
      expect(updated.addedAt, picked.addedAt);
      expect(updated.details, draft.details);
      expect(describeScope(updated.scope), describeScope(draft.scope));
      expect(listRuleIds(counted.repository), <RuleId>[
        for (final Rule rule in seeded) rule.id,
      ]);
    }
  });

  test('${_typePrefix}_update_rule_property_refusals_change_'
      'nothing', () async {
    final Random random = seededRandom(66205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);
      final bool isBlank = seeded.isEmpty || random.nextBool();
      final RuleId ruleId = seeded.isNotEmpty && random.nextBool()
          ? pickOne(random, seeded).id
          : randomMissingRuleId(random);
      final bool isKnown = seeded.any((Rule rule) => rule.id == ruleId);
      if (!isBlank && isKnown) {
        continue;
      }
      final RuleDraft draft = isBlank
          ? _randomBlankDraft(random)
          : randomRuleDraft(random);

      await expectLater(
        counted.repository.updateRule(ruleId, draft),
        throwsA(isBlank ? isA<ArgumentError>() : isA<RecordNotFound>()),
      );

      expect(counted.repository.listRules(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_update_rule_property_same_draft_twice_is_'
      'idempotent', () async {
    final Random random = seededRandom(66206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final RuleId picked = pickOne(random, seeded).id;
      final RuleDraft draft = randomRuleDraft(random);

      final Rule once = await counted.repository.updateRule(picked, draft);
      final Rule twice = await counted.repository.updateRule(picked, draft);

      expect(describeRuleContent(twice), describeRuleContent(once));
      expect(twice.addedAt, once.addedAt);
      expect(counted.repository.listRules().length, seeded.length);
    }
  });
}
