import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/library_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../support/form_finders.dart';
import 'support/item_form_steps.dart';
import 'support/real_stack.dart';
import 'support/stack_catalog.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _projectsTitle = 'Projects';
const String _rulesTitle = 'Rules';
const String _noRulesTitle = 'No rules yet';
const String _newRuleTitle = 'New rule';
const String _skillsTitle = 'Skills';
const String _newSkillTitle = 'New skill';
const String _projectName = 'site';
const String _repositoryAddress = 'github.com/example/site';
const String _ruleTitle = 'Keep commits small';
const String _ruleDetails = 'One change per commit, with a short message.';
const String _ruleMarkdownLine = '- $_ruleTitle.';
const String _skillName = 'release-notes';
const String _skillSummary = 'Write release notes from merged pull requests';
const String _skillInstructions =
    'List pull requests merged since the last tag.\n'
    'Group them by label.';

Finder _findRuleSwitch() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is SwitchToggle && widget.semanticLabel == 'Use "$_ruleTitle"',
  );
}

Future<List<node.Rule>> _listRules(WidgetTester tester, RealStack stack) {
  final node.ListRulesCommand command = node.ListRulesCommand(
    workspaceId: stack.homeWorkspaceId,
  );

  return askNode(tester, () => stack.channel.execute(command));
}

Future<bool> _isRuleEnabledOnNode(RealStack stack) async {
  final List<node.Rule> rules = await stack.channel.execute(
    node.ListRulesCommand(workspaceId: stack.homeWorkspaceId),
  );
  return rules.single.enabled;
}

Future<bool> _isRuleDisabledOnNode(RealStack stack) async {
  final bool isEnabled = await _isRuleEnabledOnNode(stack);
  return !isEnabled;
}

bool _isRuleSwitchOn(WidgetTester tester) {
  return tester.widget<SwitchToggle>(_findRuleSwitch()).value;
}

Future<void> _addRuleThroughForm(WidgetTester tester) async {
  await tapAndWait(
    tester,
    find.text(_newRuleTitle),
    expected: findPageTitle(_newRuleTitle),
  );
  await waitUntilGone(tester, findPageTitle(_rulesTitle));
  await replaceChatWithForm(tester, kind: DraftKind.rule);
  await enterFieldText(tester, label: 'Rule', text: _ruleTitle);
  await enterFieldText(tester, label: 'Details', text: _ruleDetails);
  await addFieldTag(tester, label: 'Workspaces', tag: homeWorkspaceName);
  await addFieldTag(tester, label: 'Projects', tag: _projectName);
  await tapWhenShown(tester, find.text('Add rule'));
  await waitUntilShown(tester, findPageTitle(_rulesTitle));
  await waitUntilGone(tester, findPageTitle(_newRuleTitle));
}

Future<void> _addSkillThroughForm(WidgetTester tester) async {
  await tapAndWait(
    tester,
    find.text(_newSkillTitle),
    expected: findPageTitle(_newSkillTitle),
  );
  await waitUntilGone(tester, findPageTitle(_skillsTitle));
  await replaceChatWithForm(tester, kind: DraftKind.skill);
  await enterFieldText(tester, label: 'Name', text: _skillName);
  await enterFieldText(tester, label: 'What it does', text: _skillSummary);
  await enterFieldText(
    tester,
    label: 'Instructions',
    text: _skillInstructions,
  );
  await tapWhenShown(tester, find.text('Only when chosen'));
  await tapWhenShown(tester, find.text('Save skill'));
  await waitUntilShown(tester, findPageTitle(_skillsTitle));
  await waitUntilGone(tester, findPageTitle(_newSkillTitle));
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_create_rule_property_rule_and_its_switch_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final node.Project project = await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _projectName,
        repositoryAddress: _repositoryAddress,
      );
      await openRailSection(
        tester,
        label: _projectsTitle,
        pageTitle: _projectsTitle,
      );
      await waitUntilShown(tester, find.text(_projectName));
      await openRailSection(
        tester,
        label: _rulesTitle,
        pageTitle: _rulesTitle,
      );
      await waitUntilShown(tester, find.text(_noRulesTitle));

      await _addRuleThroughForm(tester);
      expect(find.text(_ruleTitle), findsOneWidget);
      expect(find.text(_ruleDetails), findsOneWidget);
      expect(find.text(_ruleMarkdownLine), findsOneWidget);
      expect(_isRuleSwitchOn(tester), isTrue);
      final List<node.Rule> rules = await _listRules(tester, stack);
      final node.Rule created = rules.single;
      expect(created.title, _ruleTitle);
      expect(created.details, _ruleDetails);
      expect(created.enabled, isTrue);
      final node.OnlyWorkspaces workspaces =
          created.scope.workspaces as node.OnlyWorkspaces;
      final node.OnlyProjects projects =
          created.scope.projects as node.OnlyProjects;
      expect(workspaces.workspaces, <Object>[stack.homeWorkspaceId]);
      expect(projects.projects, <Object>[project.id]);

      await tapWhenShown(tester, _findRuleSwitch());
      await waitUntilGone(tester, find.text(_ruleMarkdownLine));
      await waitUntilNodeAgrees(
        tester,
        description: 'the rule turned off',
        check: () => _isRuleDisabledOnNode(stack),
      );
      expect(_isRuleSwitchOn(tester), isFalse);

      await tapWhenShown(tester, _findRuleSwitch());
      await waitUntilShown(tester, find.text(_ruleMarkdownLine));
      await waitUntilNodeAgrees(
        tester,
        description: 'the rule turned on',
        check: () => _isRuleEnabledOnNode(stack),
      );
      expect(_isRuleSwitchOn(tester), isTrue);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_create_skill_property_instructions_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await openRailSection(
        tester,
        label: _skillsTitle,
        pageTitle: _skillsTitle,
      );

      await _addSkillThroughForm(tester);
      expect(find.text(_skillName), findsOneWidget);
      expect(find.text(_skillSummary), findsOneWidget);
      final List<node.Skill> skills = await askNode(
        tester,
        () => stack.channel.execute(
          node.ListSkillsCommand(workspaceId: stack.homeWorkspaceId),
        ),
      );
      final node.Skill created = skills.singleWhere(
        (node.Skill skill) => skill.name == _skillName,
      );
      expect(created.summary, _skillSummary);
      expect(created.instructions, _skillInstructions);
      expect(created.usage, node.SkillUsage.whenChosen);
      expect(created.scope.workspaces, isA<node.AllWorkspaces>());
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
