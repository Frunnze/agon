import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/rule_inputs.dart';
import '../../fakes/support/simulated_scoped_rules.dart';
import '../../fakes/support/workspace_scope_inputs.dart';
import 'out_of_order_replies.dart';
import 'simulated_catalog_node.dart';

const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const int _largestSeededRuleCount = 6;
const Set<String> _ruleChangeCommands = <String>{
  'create_rule',
  'update_rule',
  'delete_rule',
  'set_rule_enabled',
};
const node.AreaChanged _rulesChanged = node.AreaChanged(
  area: node.ChangeArea.rules,
);

typedef RuleReplyRace = ({
  SimulatedCatalogNode node,
  OutOfOrderReplyTransport transport,
  AnnouncingNodeAnswer announcements,
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedRuleRepository rules,
  List<WorkspaceId> workspaceIds,
  PendingRaceWork pendingWork,
});

Future<RuleReplyRace> openRuleReplyRace(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final String name in _workspaceNames)
      WorkspaceId(simulated.addWorkspace(name)['id']! as String),
  ];
  seedSimulatedRules(
    random: random,
    simulated: simulated,
    workspaceIds: workspaceIds,
    count: random.nextInt(_largestSeededRuleCount),
  );
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: simulated.answer,
    changeCommands: _ruleChangeCommands,
  );
  final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
    answer: announcements.answerAndAnnounce,
    random: random,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    channel,
  );
  final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
    channel: channel,
    workspaceRepository: workspaces,
  );
  await rules.load();
  transport.isHoldingReplies = true;
  return (
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    rules: rules,
    workspaceIds: workspaceIds,
    pendingWork: PendingRaceWork(),
  );
}

RuleDraft randomRaceRuleDraft(Random random, RuleReplyRace race) {
  return RuleDraft(
    title: 'Rule ${randomWordPhrase(random)}x',
    details: randomText(random),
    scope: randomScopeOver(random, race.workspaceIds),
  );
}

RuleId? pickListedRuleId(Random random, RuleReplyRace race) {
  final List<Rule> listed = race.rules.listRules();
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed).id;
}

void editRuleElsewhere(Random random, RuleReplyRace race) {
  if (race.node.rules.isEmpty) {
    return;
  }
  final Map<String, Object?> record = pickOne(random, race.node.rules);
  final RuleDraft draft = randomRaceRuleDraft(random, race);
  record['title'] = draft.title;
  record['details'] = draft.details;
  record['scope'] = mapScopeToNode(draft.scope).toJson();
  record['enabled'] = random.nextBool();
  announceRuleChange(race);
}

void deleteRuleElsewhere(Random random, RuleReplyRace race) {
  if (race.node.rules.isEmpty) {
    return;
  }
  race.node.rules.remove(pickOne(random, race.node.rules));
  announceRuleChange(race);
}

void switchWorkspaceInRace(Random random, RuleReplyRace race) {
  final WorkspaceId currentWorkspaceId = race.workspaces.currentWorkspace().id;
  final List<Workspace> others = <Workspace>[
    for (final Workspace workspace in race.workspaces.listWorkspaces())
      if (workspace.id != currentWorkspaceId) workspace,
  ];
  race.pendingWork.start(
    race.workspaces.switchWorkspace(pickOne(random, others).id),
  );
}

void announceRuleChange(RuleReplyRace race) {
  race.pendingWork.start(race.rules.applyChange(_rulesChanged));
}

void deliverWaitingAnnouncement(RuleReplyRace race) {
  if (race.announcements.waitingAnnouncements == 0) {
    return;
  }
  race.announcements.takeAnnouncement();
  announceRuleChange(race);
}

Future<void> _releaseEverything(RuleReplyRace race) {
  return releaseRepliesAndAnnouncements(
    transport: race.transport,
    announcements: race.announcements,
    deliverAnnouncement: () => announceRuleChange(race),
  );
}

Future<List<String>> finishRuleReplyRace(RuleReplyRace race) async {
  await _releaseEverything(race);
  await race.pendingWork.finish();
  await _releaseEverything(race);
  return describeSortedRules(race.rules.listRules());
}

Future<List<String>> reloadRulesFrom(
  NodeCommandChannel channel,
  NodeBackedWorkspaceRepository workspaces,
) async {
  final NodeBackedRuleRepository reloaded = NodeBackedRuleRepository(
    channel: channel,
    workspaceRepository: workspaces,
  );
  await reloaded.load();
  final List<String> listing = describeSortedRules(reloaded.listRules());
  reloaded.dispose();
  return listing;
}

List<String> describeSortedRules(List<Rule> rules) {
  final List<String> described = <String>[
    for (final Rule rule in rules)
      '${rule.id.value} ${describeRuleContent(rule)}',
  ];
  described.sort();
  return described;
}

void closeRuleReplyRace(RuleReplyRace race) {
  race.rules.dispose();
  race.workspaces.dispose();
}
