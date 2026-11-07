import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes/fake_rule_repository.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/rule_saving_white_space_checks.dart';
import '../../support/rule_title_white_space_table.dart';

const RuleId _existingRuleId = RuleId('existing-rule');

FakeRuleRepository _openRules() {
  final Rule existing = Rule(
    id: _existingRuleId,
    title: 'Keep commits small',
    details: '',
    scope: const Scope.everywhere(),
    enabled: true,
    addedAt: galleryNow,
  );
  return FakeRuleRepository(
    rules: <Rule>[existing],
    clock: FixedClock(galleryNow),
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test(
    'test_fake_rule_repository_create_rule_property_trims_rust_white_space',
    () async {
      final FakeRuleRepository rules = _openRules();

      await checkSavesModelTrimmedTitles(
        table: table,
        saveRule: rules.createRule,
        findRule: rules.findRule,
        seed: 60841,
      );
    },
  );

  test(
    'test_fake_rule_repository_create_rule_property_agrees_with_shared_table',
    () async {
      final FakeRuleRepository rules = _openRules();

      await checkRefusesSharedBlankTitles(
        table: table,
        saveRule: rules.createRule,
      );
    },
  );

  test(
    'test_fake_rule_repository_create_rule_property_renders_like_the_draft',
    () async {
      final FakeRuleRepository rules = _openRules();

      await checkSavedRuleRendersLikeDraft(
        table: table,
        saveRule: rules.createRule,
        seed: 60842,
      );
    },
  );

  test(
    'test_fake_rule_repository_update_rule_property_trims_rust_white_space',
    () async {
      final FakeRuleRepository rules = _openRules();

      await checkSavesModelTrimmedTitles(
        table: table,
        saveRule: (RuleDraft draft) =>
            rules.updateRule(_existingRuleId, draft),
        findRule: rules.findRule,
        seed: 60843,
      );
    },
  );

  test(
    'test_fake_rule_repository_update_rule_property_agrees_with_shared_table',
    () async {
      final FakeRuleRepository rules = _openRules();

      await checkRefusesSharedBlankTitles(
        table: table,
        saveRule: (RuleDraft draft) =>
            rules.updateRule(_existingRuleId, draft),
      );
    },
  );

  test(
    'test_fake_rule_repository_update_rule_property_renders_like_the_draft',
    () async {
      final FakeRuleRepository rules = _openRules();

      await checkSavedRuleRendersLikeDraft(
        table: table,
        saveRule: (RuleDraft draft) =>
            rules.updateRule(_existingRuleId, draft),
        seed: 60844,
      );
    },
  );
}
