import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';

import '../../../support/random_inputs.dart';
import 'rule_inputs.dart';
import 'workspace_inputs.dart';
import 'workspace_scope_inputs.dart';

const int _largestScopedRuleCount = 7;

typedef WorkspaceRules = ({
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  List<Rule> seeded,
  FakeRuleRepository rules,
});

List<Rule> randomRulesOver(Random random, List<WorkspaceId> workspaceIds) {
  final int count = random.nextInt(_largestScopedRuleCount);
  return <Rule>[
    for (int i = 0; i < count; i += 1)
      Rule(
        id: RuleId('scoped-rule-$i'),
        title: 'Rule $i ${randomWordPhrase(random)}',
        details: randomText(random),
        scope: randomScopeOver(random, workspaceIds),
        enabled: random.nextBool(),
        addedAt: randomUtcMoment(random),
      ),
  ];
}

WorkspaceRules seedWorkspaceRules(Random random) {
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(seeded.workspaces);
  final List<Rule> rules = randomRulesOver(random, workspaceIds);
  final FakeRuleRepository repository = FakeRuleRepository(
    rules: rules,
    clock: FixedClock(randomUtcMoment(random)),
    workspaceRepository: seeded.repository,
  );
  return (
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
    seeded: rules,
    rules: repository,
  );
}

List<Rule> filterModelRulesFor(List<Rule> rules, WorkspaceId workspaceId) {
  final List<Rule> usableRules = <Rule>[];
  for (final Rule rule in rules) {
    if (isModelUsableInWorkspace(rule.scope.workspaces, workspaceId)) {
      usableRules.add(rule);
    }
  }
  return usableRules;
}

String describeStoredRule(Rule rule) {
  final String moment = rule.addedAt.toIso8601String();
  return '${rule.id.value} $moment ${describeRuleContent(rule)}';
}

List<String> describeStoredRules(List<Rule> rules) {
  final List<String> descriptions = <String>[];
  for (final Rule rule in rules) {
    descriptions.add(describeStoredRule(rule));
  }
  return descriptions;
}

Future<List<String>> describeListingAfterSwitchingTo(
  WorkspaceRules workspaceRules,
  WorkspaceId workspaceId,
) async {
  await workspaceRules.workspaces.switchWorkspace(workspaceId);
  return describeStoredRules(workspaceRules.rules.listRules());
}
