import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/library_commands.dart'
    as node;

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _skillsTitle = 'Skills';
const String _rulesTitle = 'Rules';
const String _skillName = 'release-notes';
const String _changedSkillSummary = 'Write notes for every release';
const String _changedInstructions = 'Read the merged pull requests.';
const String _ruleTitle = 'Keep commits small';
const String _changedRuleDetails = 'One change per commit.';
const node.Scope _everywhere = node.Scope(
  workspaces: node.AllWorkspaces(),
  projects: node.AllProjects(),
);

Future<List<node.Skill>> _listNodeSkills(RealStack stack) {
  return stack.channel.execute(
    node.ListSkillsCommand(workspaceId: stack.homeWorkspaceId),
  );
}

Future<List<node.Rule>> _listNodeRules(RealStack stack) {
  return stack.channel.execute(
    node.ListRulesCommand(workspaceId: stack.homeWorkspaceId),
  );
}

Future<bool> _isSkillChangedOnNode(RealStack stack) async {
  final List<node.Skill> skills = await _listNodeSkills(stack);
  return skills.any(
    (node.Skill skill) =>
        skill.summary == _changedSkillSummary &&
        skill.instructions == _changedInstructions,
  );
}

Future<bool> _isSkillGoneFromNode(RealStack stack) async {
  final List<node.Skill> skills = await _listNodeSkills(stack);
  return skills.isEmpty;
}

Future<bool> _isRuleChangedOnNode(RealStack stack) async {
  final List<node.Rule> rules = await _listNodeRules(stack);
  return rules.any(
    (node.Rule rule) => rule.details == _changedRuleDetails && rule.enabled,
  );
}

Future<bool> _isRuleGoneFromNode(RealStack stack) async {
  final List<node.Rule> rules = await _listNodeRules(stack);
  return rules.isEmpty;
}

Future<void> _confirmDelete(WidgetTester tester, String confirmLabel) async {
  await tapAndWait(
    tester,
    find.text('Delete'),
    expected: find.text(confirmLabel),
  );
  await tapWhenShown(tester, find.text(confirmLabel));
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_update_skill_property_edits_and_deletion_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await askNode(
        tester,
        () => stack.channel.execute(
          node.CreateSkillCommand(
            workspaceId: stack.homeWorkspaceId,
            skillName: _skillName,
            summary: 'Write release notes',
            instructions: 'List merged pull requests.',
            scope: _everywhere,
            usage: node.SkillUsage.automatic,
          ),
        ),
      );
      await openRailSection(
        tester,
        label: _skillsTitle,
        pageTitle: _skillsTitle,
      );

      await tapAndWait(
        tester,
        find.text(_skillName),
        expected: findPageTitle(_skillName),
      );
      await tapAndWait(
        tester,
        find.text('Edit'),
        expected: findPageTitle('Edit skill'),
      );
      await enterFieldText(
        tester,
        label: 'What it does',
        text: _changedSkillSummary,
      );
      await enterFieldText(
        tester,
        label: 'Instructions',
        text: _changedInstructions,
      );
      await tapWhenShown(tester, find.text('Save skill'));
      await waitUntilGone(tester, findPageTitle('Edit skill'));
      await waitUntilShown(tester, find.text(_changedInstructions));
      await waitUntilNodeAgrees(
        tester,
        description: 'the changed skill',
        check: () => _isSkillChangedOnNode(stack),
      );

      await _confirmDelete(tester, 'Delete skill');
      await waitUntilShown(tester, findPageTitle(_skillsTitle));
      await waitUntilGone(tester, find.text(_skillName));
      await waitUntilNodeAgrees(
        tester,
        description: 'the skill deleted',
        check: () => _isSkillGoneFromNode(stack),
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_update_rule_property_edits_and_deletion_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await askNode(
        tester,
        () => stack.channel.execute(
          node.CreateRuleCommand(
            workspaceId: stack.homeWorkspaceId,
            title: _ruleTitle,
            details: 'Small commits are easy to review.',
            scope: _everywhere,
          ),
        ),
      );
      await openRailSection(
        tester,
        label: _rulesTitle,
        pageTitle: _rulesTitle,
      );

      await tapAndWait(
        tester,
        find.text(_ruleTitle),
        expected: findPageTitle(_ruleTitle),
      );
      await tapAndWait(
        tester,
        find.text('Edit'),
        expected: findPageTitle('Edit rule'),
      );
      await enterFieldText(
        tester,
        label: 'Details',
        text: _changedRuleDetails,
      );
      await tapWhenShown(tester, find.text('Save rule'));
      await waitUntilGone(tester, findPageTitle('Edit rule'));
      await waitUntilShown(tester, find.text(_changedRuleDetails));
      await waitUntilNodeAgrees(
        tester,
        description: 'the changed rule',
        check: () => _isRuleChangedOnNode(stack),
      );

      await _confirmDelete(tester, 'Delete rule');
      await waitUntilShown(tester, findPageTitle(_rulesTitle));
      await waitUntilGone(tester, find.text(_ruleTitle));
      await waitUntilNodeAgrees(
        tester,
        description: 'the rule deleted',
        check: () => _isRuleGoneFromNode(stack),
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
