import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import 'support/rule_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';

Matcher _isRuleNotFound(RuleId ruleId) {
  return isA<RecordNotFound>()
      .having((RecordNotFound error) => error.kind, 'kind', 'rule')
      .having(
        (RecordNotFound error) => error.identifier,
        'identifier',
        ruleId.value,
      );
}

void main() {
  test('${_typePrefix}_constructor_property_keeps_every_rule_in_order', () {
    final Random random = seededRandom(66001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);

      final CountedRules counted = buildCountedRules(random, seeded);

      expect(counted.repository.listRules(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_constructor_property_copies_the_given_list', () {
    final Random random = seededRandom(66002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final List<Rule> callerList = List<Rule>.of(seeded);
      final CountedRules counted = buildCountedRules(random, callerList);

      callerList.add(randomRuleWithId(random, const RuleId('rule-late')));
      callerList.shuffle(random);

      expect(counted.repository.listRules(), orderedEquals(seeded));
    }
  });

  test('${_typePrefix}_constructor_property_refuses_repeated_ids', () {
    final Random random = seededRandom(66003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final Rule repeated = randomRuleWithId(
        random,
        pickOne(random, seeded).id,
      );
      final List<Rule> withRepeat = <Rule>[...seeded, repeated]
        ..shuffle(random);

      expect(
        () => FakeRuleRepository(
          rules: withRepeat,
          clock: FixedClock(randomUtcMoment(random)),
          workspaceRepository: buildAcmeWorkspaceRepository(),
        ),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_list_rules_property_callers_cannot_change_it', () {
    final Random random = seededRandom(66004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRules counted = buildCountedRules(
        random,
        randomSeededRules(random),
      );
      final List<Rule> listed = counted.repository.listRules();

      expect(
        () => listed.add(randomRuleWithId(random, const RuleId('rule-x'))),
        throwsUnsupportedError,
      );
    }
  });

  test('${_typePrefix}_list_rules_property_grows_only_by_'
      'creation', () async {
    final Random random = seededRandom(66005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRules counted = buildCountedRules(
        random,
        randomSeededRules(random),
      );
      final int lengthBefore = counted.repository.listRules().length;
      final List<Rule> listed = counted.repository.listRules();
      if (listed.isNotEmpty) {
        final RuleId picked = pickOne(random, listed).id;
        await counted.repository.turnRuleOff(picked);
        await counted.repository.turnRuleOn(picked);
      }
      expect(counted.repository.listRules().length, lengthBefore);

      final Rule created = await counted.repository.createRule(
        RuleDraft(
          title: 'Keep it short',
          details: randomText(random),
          scope: randomScopeInRuleWorkspace(random),
        ),
      );

      expect(counted.repository.listRules().length, lengthBefore + 1);
      expect(counted.repository.listRules().last, created);
    }
  });

  test('${_typePrefix}_list_rules_property_find_round_trips_every_'
      'listed_rule', () {
    final Random random = seededRandom(66006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRules counted = buildCountedRules(
        random,
        randomSeededRules(random),
      );

      for (final Rule listed in counted.repository.listRules()) {
        expect(
          identical(counted.repository.findRule(listed.id), listed),
          isTrue,
        );
      }
    }
  });

  test('${_typePrefix}_find_rule_property_unknown_ids_name_the_rule', () {
    final Random random = seededRandom(66007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRules counted = buildCountedRules(
        random,
        randomSeededRules(random),
      );
      final RuleId missing = randomMissingRuleId(random);

      expect(
        () => counted.repository.findRule(missing),
        throwsA(_isRuleNotFound(missing)),
      );
    }
  });

  test('${_typePrefix}_find_rule_property_sees_the_latest_version', () async {
    final Random random = seededRandom(66008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final RuleId picked = pickOne(random, seeded).id;

      final Rule switched = random.nextBool()
          ? await counted.repository.turnRuleOn(picked)
          : await counted.repository.turnRuleOff(picked);

      expect(identical(counted.repository.findRule(picked), switched), isTrue);
    }
  });

  test('${_typePrefix}_find_rule_property_reads_are_quiet', () {
    final Random random = seededRandom(66009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);

      for (final Rule rule in seeded) {
        counted.repository.findRule(rule.id);
      }

      expect(counted.notifications.count, 0);
      expect(counted.repository.listRules(), orderedEquals(seeded));
    }
  });

  test('${_typePrefix}_delete_rule_property_removes_exactly_that_'
      'rule', () async {
    final Random random = seededRandom(66010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final Rule deleted = pickOne(random, seeded);

      await counted.repository.deleteRule(deleted.id);

      expect(counted.repository.listRules(), <Rule>[
        for (final Rule rule in seeded)
          if (rule.id != deleted.id) rule,
      ]);
      expect(counted.notifications.count, 1);
    }
  });

  test('${_typePrefix}_delete_rule_property_unknown_ids_change_'
      'nothing', () async {
    final Random random = seededRandom(66011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);
      final RuleId missing = randomMissingRuleId(random);

      await expectLater(
        counted.repository.deleteRule(missing),
        throwsA(_isRuleNotFound(missing)),
      );

      expect(counted.repository.listRules(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_delete_rule_property_a_deleted_rule_is_gone', () async {
    final Random random = seededRandom(66012);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedRules counted = buildCountedRules(random, seeded);
      final RuleId deleted = pickOne(random, seeded).id;

      await counted.repository.deleteRule(deleted);

      expect(
        () => counted.repository.findRule(deleted),
        throwsA(_isRuleNotFound(deleted)),
      );
      await expectLater(
        counted.repository.turnRuleOn(deleted),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        counted.repository.deleteRule(deleted),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
