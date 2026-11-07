import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_scoped_rules.dart';

const String _typePrefix = 'test_fake_rule_repository';
const int _longestSwitchSequence = 8;

FakeRuleRepository _buildRulesWithoutWorkspaces(Random random) {
  final NodeBackedWorkspaceRepository emptyWorkspaces =
      NodeBackedWorkspaceRepository(
        channel: SimulatedCatalogNode(hasAccount: false).channel,
        clock: FixedClock(randomUtcMoment(random)),
        retryInterval: const Duration(seconds: 30),
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  final List<WorkspaceId> workspaceIds = randomWorkspaceIds(random);
  return FakeRuleRepository(
    rules: randomRulesOver(random, workspaceIds),
    clock: FixedClock(randomUtcMoment(random)),
    workspaceRepository: emptyWorkspaces,
  );
}

List<String> _describeExpectedListing(WorkspaceRules workspaceRules) {
  final WorkspaceId current = workspaceRules.workspaces.currentWorkspace().id;
  return describeStoredRules(
    filterModelRulesFor(workspaceRules.seeded, current),
  );
}

List<WorkspaceId> _pickOtherWorkspaceIds(
  Random random,
  WorkspaceRules workspaceRules,
) {
  final WorkspaceId current = workspaceRules.workspaces.currentWorkspace().id;
  final List<WorkspaceId> others = <WorkspaceId>[
    for (final WorkspaceId workspaceId in workspaceRules.workspaceIds)
      if (workspaceId != current) workspaceId,
  ];
  return pickSome(random, others);
}

void main() {
  test('${_typePrefix}_list_rules_property_matches_the_model_for_the_'
      'current_workspace', () {
    final Random random = seededRandom(72101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);

      expect(
        describeStoredRules(workspaceRules.rules.listRules()),
        orderedEquals(_describeExpectedListing(workspaceRules)),
      );
    }
  });

  test('${_typePrefix}_list_rules_property_follows_every_workspace_'
      'switch', () async {
    final Random random = seededRandom(72102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final int switchCount = random.nextInt(_longestSwitchSequence);

      for (int step = 0; step < switchCount; step += 1) {
        final WorkspaceId target = pickOne(
          random,
          workspaceRules.workspaceIds,
        );
        await workspaceRules.workspaces.switchWorkspace(target);

        expect(
          describeStoredRules(workspaceRules.rules.listRules()),
          orderedEquals(_describeExpectedListing(workspaceRules)),
        );
      }
    }
  });

  test('${_typePrefix}_list_rules_property_is_empty_without_any_'
      'workspace', () {
    final Random random = seededRandom(72103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRuleRepository rules = _buildRulesWithoutWorkspaces(random);

      expect(rules.listRules(), isEmpty);
    }
  });

  test('${_typePrefix}_list_rules_property_every_seen_rule_is_listed_'
      'somewhere', () async {
    final Random random = seededRandom(72104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final Set<String> listedSomewhere = <String>{};
      for (final WorkspaceId workspaceId in workspaceRules.workspaceIds) {
        listedSomewhere.addAll(
          await describeListingAfterSwitchingTo(workspaceRules, workspaceId),
        );
      }

      final Set<WorkspaceId> known = workspaceRules.workspaceIds.toSet();
      final Set<String> expected = <String>{
        for (final Rule rule in workspaceRules.seeded)
          if (!isModelSeenInNoWorkspace(rule.scope.workspaces, known))
            describeStoredRule(rule),
      };
      expect(listedSomewhere, equals(expected));
    }
  });

  test('${_typePrefix}_find_rule_property_finds_exactly_the_listed_'
      'rules', () {
    final Random random = seededRandom(72105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final List<Rule> listed = workspaceRules.rules.listRules();

      for (final Rule rule in workspaceRules.seeded) {
        if (listed.contains(rule)) {
          expect(workspaceRules.rules.findRule(rule.id), same(rule));
        } else {
          expect(
            () => workspaceRules.rules.findRule(rule.id),
            throwsA(isA<RecordNotFound>()),
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_rule_property_edits_refuse_rules_outside_the_'
      'workspace', () async {
    final Random random = seededRandom(72106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final FakeRuleRepository rules = workspaceRules.rules;
      final List<Rule> listed = rules.listRules();
      final RuleDraft draft = RuleDraft(
        title: 'Keep ${randomWordPhrase(random)}',
        details: randomText(random),
        scope: const Scope.everywhere(),
      );

      for (final Rule rule in workspaceRules.seeded) {
        if (listed.contains(rule)) {
          continue;
        }
        final Matcher isNotFound = throwsA(isA<RecordNotFound>());
        await expectLater(rules.updateRule(rule.id, draft), isNotFound);
        await expectLater(rules.turnRuleOn(rule.id), isNotFound);
        await expectLater(rules.turnRuleOff(rule.id), isNotFound);
        await expectLater(rules.deleteRule(rule.id), isNotFound);
      }

      expect(rules.listRules(), orderedEquals(listed));
    }
  });

  test('${_typePrefix}_find_rule_property_finds_nothing_without_any_'
      'workspace', () {
    final Random random = seededRandom(72107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRuleRepository rules = _buildRulesWithoutWorkspaces(random);
      final RuleId ruleId = RuleId('scoped-rule-${random.nextInt(8)}');

      expect(() => rules.findRule(ruleId), throwsA(isA<RecordNotFound>()));
    }
  });

  test('${_typePrefix}_create_rule_property_rules_outside_the_workspace_'
      'are_stored_unlisted', () async {
    final Random random = seededRandom(72108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final FakeRuleRepository rules = workspaceRules.rules;
      final List<Rule> listedBefore = rules.listRules();
      final List<WorkspaceId> named = _pickOtherWorkspaceIds(
        random,
        workspaceRules,
      );
      final Scope scope = Scope(
        workspaces: OnlyWorkspaces(named),
        projects: randomProjectScope(random),
      );

      final Rule created = await rules.createRule(
        RuleDraft(
          title: 'Keep ${randomWordPhrase(random)}',
          details: randomText(random),
          scope: scope,
        ),
      );

      expect(rules.listRules(), orderedEquals(listedBefore));
      expect(() => rules.findRule(created.id), throwsA(isA<RecordNotFound>()));
      if (named.isNotEmpty) {
        await workspaceRules.workspaces.switchWorkspace(
          pickOne(random, named),
        );
        expect(rules.listRules().last.id, created.id);
      }
    }
  });
}
