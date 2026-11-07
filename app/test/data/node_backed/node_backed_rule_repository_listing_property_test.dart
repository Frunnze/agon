import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../support/random_inputs.dart';
import 'support/scoped_library_listing.dart';

typedef _OpenedRules = ({
  ScopedLibrary library,
  NodeBackedRuleRepository rules,
});

Future<_OpenedRules> _openRules() async {
  final ScopedLibrary library = await openScopedLibrary();
  final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
    channel: library.channel,
    workspaceRepository: library.workspaces,
  );
  await rules.load();
  return (library: library, rules: rules);
}

Map<RuleId, String> _describeListing(List<Rule> rules) {
  return <RuleId, String>{for (final Rule rule in rules) rule.id: rule.title};
}

Future<Map<RuleId, String>> _reloadListing(ScopedLibrary library) async {
  final NodeBackedRuleRepository reloaded = NodeBackedRuleRepository(
    channel: library.channel,
    workspaceRepository: library.workspaces,
  );
  await reloaded.load();
  final Map<RuleId, String> listing = _describeListing(reloaded.listRules());
  reloaded.dispose();
  return listing;
}

RuleDraft _randomDraft(Random random, ScopedLibrary library, int number) {
  return RuleDraft(
    title: 'Rule $number',
    details: randomText(random),
    scope: randomListingScope(random, library.workspaceIds),
  );
}

bool _isListedHere(ScopedLibrary library, RuleDraft draft) {
  return includesWorkspace(
    draft.scope.workspaces,
    library.workspaces.currentWorkspace().id,
  );
}

void _close(_OpenedRules opened) {
  opened.rules.dispose();
  opened.library.workspaces.dispose();
}

void main() {
  test('test_store_rule_property_created_rules_list_like_a_reload', () async {
    final Random random = seededRandom(66301);
    final _OpenedRules opened = await _openRules();

    for (int i = 0; i < propertyIterations; i += 1) {
      await opened.rules.createRule(_randomDraft(random, opened.library, i));

      expect(
        _describeListing(opened.rules.listRules()),
        await _reloadListing(opened.library),
      );
    }
    _close(opened);
  });

  test('test_store_rule_property_updated_rules_list_like_a_reload', () async {
    final Random random = seededRandom(66302);
    final _OpenedRules opened = await _openRules();
    final List<RuleId> knownRuleIds = <RuleId>[];
    for (int i = 0; i < 6; i += 1) {
      final RuleDraft draft = _randomDraft(random, opened.library, i);
      knownRuleIds.add((await opened.rules.createRule(draft)).id);
    }

    for (int i = 0; i < propertyIterations; i += 1) {
      await opened.rules.updateRule(
        pickOne(random, knownRuleIds),
        _randomDraft(random, opened.library, i),
      );

      expect(
        _describeListing(opened.rules.listRules()),
        await _reloadListing(opened.library),
      );
    }
    _close(opened);
  });

  test('test_store_rule_property_only_rules_for_this_workspace_are_'
      'found', () async {
    final Random random = seededRandom(66303);
    final _OpenedRules opened = await _openRules();
    final List<RuleId> knownRuleIds = <RuleId>[];

    for (int i = 0; i < propertyIterations; i += 1) {
      final RuleDraft draft = _randomDraft(random, opened.library, i);
      final bool isUpdate = knownRuleIds.isNotEmpty && random.nextBool();
      final Rule saved = isUpdate
          ? await opened.rules.updateRule(pickOne(random, knownRuleIds), draft)
          : await opened.rules.createRule(draft);
      knownRuleIds.add(saved.id);

      if (_isListedHere(opened.library, draft)) {
        expect(opened.rules.findRule(saved.id).title, draft.title);
      } else {
        expect(
          () => opened.rules.findRule(saved.id),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
    _close(opened);
  });

  test('test_store_rule_property_toggles_keep_the_listing_like_a_'
      'reload', () async {
    final Random random = seededRandom(66304);
    final _OpenedRules opened = await _openRules();
    for (int i = 0; i < 8; i += 1) {
      await opened.rules.createRule(_randomDraft(random, opened.library, i));
    }

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> listed = opened.rules.listRules();
      if (listed.isEmpty) {
        break;
      }
      final RuleId ruleId = pickOne(random, listed).id;
      final Rule toggled = random.nextBool()
          ? await opened.rules.turnRuleOn(ruleId)
          : await opened.rules.turnRuleOff(ruleId);

      expect(opened.rules.findRule(ruleId).enabled, toggled.enabled);
      expect(
        _describeListing(opened.rules.listRules()),
        await _reloadListing(opened.library),
      );
    }
    _close(opened);
  });
}
