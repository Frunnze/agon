import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../../support/random_inputs.dart';
import '../../node_backed/support/simulated_catalog_node.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import 'rule_inputs.dart';
import 'workspace_scope_inputs.dart';

Rule seedSimulatedRule({
  required Random random,
  required SimulatedCatalogNode simulated,
  required List<WorkspaceId> workspaceIds,
  required int index,
}) {
  final Scope scope = randomScopeOver(random, workspaceIds);
  final bool enabled = random.nextBool();
  final Map<String, Object?> record = simulated.addRule(
    workspaceId: pickOne(random, workspaceIds).value,
    title: 'Seeded rule $index',
  );
  record['scope'] = mapScopeToNode(scope).toJson();
  record['enabled'] = enabled;
  return Rule(
    id: RuleId(record['id']! as String),
    title: record['title']! as String,
    details: record['details']! as String,
    scope: scope,
    enabled: enabled,
    addedAt: DateTime.parse(simulatedMoment),
  );
}

List<Rule> seedSimulatedRules({
  required Random random,
  required SimulatedCatalogNode simulated,
  required List<WorkspaceId> workspaceIds,
  required int count,
}) {
  return <Rule>[
    for (int index = 0; index < count; index += 1)
      seedSimulatedRule(
        random: random,
        simulated: simulated,
        workspaceIds: workspaceIds,
        index: index,
      ),
  ];
}

List<String> describeRuleListing(RuleRepository repository) {
  return <String>[
    for (final Rule rule in repository.listRules()) describeRuleContent(rule),
  ];
}
