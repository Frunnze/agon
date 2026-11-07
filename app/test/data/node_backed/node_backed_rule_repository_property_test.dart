import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/rule_saving_white_space_checks.dart';
import '../../support/rule_title_white_space_table.dart';
import 'support/simulated_catalog_node.dart';

const Duration _retryInterval = Duration(seconds: 30);

typedef _OpenedRules = ({
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedRuleRepository rules,
  RuleId existingRuleId,
});

Future<_OpenedRules> _openRules() async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final String workspaceId = simulated.addWorkspace('home')['id'] as String;
  final Map<String, Object?> existing = simulated.addRule(
    workspaceId: workspaceId,
    title: 'Keep commits small',
  );
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(DateTime.utc(2026, 11, 7)),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  await workspaces.load();
  await rules.load();
  return (
    workspaces: workspaces,
    rules: rules,
    existingRuleId: RuleId(existing['id'] as String),
  );
}

void _close(_OpenedRules opened) {
  opened.rules.dispose();
  opened.workspaces.dispose();
}

SaveRule _updateExisting(_OpenedRules opened) {
  return (RuleDraft draft) {
    return opened.rules.updateRule(opened.existingRuleId, draft);
  };
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test(
    'test_node_backed_rule_repository_create_rule_property_trims_rust_space',
    () async {
      final _OpenedRules opened = await _openRules();

      await checkSavesModelTrimmedTitles(
        table: table,
        saveRule: opened.rules.createRule,
        findRule: opened.rules.findRule,
        seed: 60851,
      );
      _close(opened);
    },
  );

  test(
    'test_node_backed_rule_repository_create_rule_property_shared_table',
    () async {
      final _OpenedRules opened = await _openRules();

      await checkRefusesSharedBlankTitles(
        table: table,
        saveRule: opened.rules.createRule,
      );
      _close(opened);
    },
  );

  test(
    'test_node_backed_rule_repository_create_rule_property_renders_as_draft',
    () async {
      final _OpenedRules opened = await _openRules();

      await checkSavedRuleRendersLikeDraft(
        table: table,
        saveRule: opened.rules.createRule,
        seed: 60852,
      );
      _close(opened);
    },
  );

  test(
    'test_node_backed_rule_repository_update_rule_property_trims_rust_space',
    () async {
      final _OpenedRules opened = await _openRules();

      await checkSavesModelTrimmedTitles(
        table: table,
        saveRule: _updateExisting(opened),
        findRule: opened.rules.findRule,
        seed: 60853,
      );
      _close(opened);
    },
  );

  test(
    'test_node_backed_rule_repository_update_rule_property_shared_table',
    () async {
      final _OpenedRules opened = await _openRules();

      await checkRefusesSharedBlankTitles(
        table: table,
        saveRule: _updateExisting(opened),
      );
      _close(opened);
    },
  );

  test(
    'test_node_backed_rule_repository_update_rule_property_renders_as_draft',
    () async {
      final _OpenedRules opened = await _openRules();

      await checkSavedRuleRendersLikeDraft(
        table: table,
        saveRule: _updateExisting(opened),
        seed: 60854,
      );
      _close(opened);
    },
  );
}
