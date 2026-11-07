import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/rule_inputs.dart';
import '../../fakes/support/simulated_scoped_rules.dart';
import '../../fakes/support/workspace_scope_inputs.dart';
import 'identifier_ordered_records.dart';
import 'out_of_order_replies.dart';
import 'reply_race_properties.dart';
import 'simulated_catalog_node.dart';
import 'simulated_node_replies.dart';

const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const int _largestSeededRuleCount = 6;
const String _ruleKind = 'rule';
const Set<String> _ruleChangeCommands = <String>{
  'create_rule',
  'update_rule',
  'delete_rule',
  'set_rule_enabled',
};
const node.AreaChanged _rulesChanged = node.AreaChanged(
  area: node.ChangeArea.rules,
);

final class OrderedRuleReplyRace implements ReplyRace {
  OrderedRuleReplyRace._({
    required this.node,
    required this.transport,
    required this.announcements,
    required this.workspaces,
    required this.rules,
    required this.workspaceIds,
    required NodeCommandChannel reloadChannel,
  }) : _reloadChannel = reloadChannel;

  final SimulatedCatalogNode node;
  @override
  final OutOfOrderReplyTransport transport;
  final AnnouncingNodeAnswer announcements;
  final NodeBackedWorkspaceRepository workspaces;
  final NodeBackedRuleRepository rules;
  final List<WorkspaceId> workspaceIds;
  final NodeCommandChannel _reloadChannel;
  @override
  final PendingRaceWork pendingWork = PendingRaceWork();

  void announceRuleChange() {
    pendingWork.start(rules.applyChange(_rulesChanged));
  }

  @override
  void deliverWaitingAnnouncement() {
    if (announcements.waitingAnnouncements == 0) {
      return;
    }
    announcements.takeAnnouncement();
    announceRuleChange();
  }

  Future<void> _releaseEverything() {
    return releaseRepliesAndAnnouncements(
      transport: transport,
      announcements: announcements,
      deliverAnnouncement: announceRuleChange,
    );
  }

  @override
  Future<void> settle() async {
    await _releaseEverything();
    await pendingWork.finish();
    await _releaseEverything();
  }

  @override
  List<String> describeShown() => _describeRules(rules.listRules());

  @override
  List<String> listShownIdentifiers() {
    return <String>[for (final Rule rule in rules.listRules()) rule.id.value];
  }

  @override
  Future<List<String>> describeReload() async {
    final NodeBackedRuleRepository reloaded = NodeBackedRuleRepository(
      channel: _reloadChannel,
      workspaceRepository: workspaces,
    );
    await reloaded.load();
    final List<String> described = _describeRules(reloaded.listRules());
    reloaded.dispose();
    return described;
  }

  @override
  void close() {
    rules.dispose();
    workspaces.dispose();
  }
}

List<String> _describeRules(List<Rule> rules) {
  return <String>[
    for (final Rule rule in rules)
      '${rule.id.value} ${describeRuleContent(rule)}',
  ];
}

Future<OrderedRuleReplyRace> openOrderedRuleReplyRace(Random random) async {
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
  giveRandomIdentifiers(random, simulated.rules, kind: _ruleKind);
  final IdentifierOrderedCatalogNode ordered = IdentifierOrderedCatalogNode(
    simulated,
  );
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: ordered.answer,
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
  return OrderedRuleReplyRace._(
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    rules: rules,
    workspaceIds: workspaceIds,
    reloadChannel: buildSimulatedChannel(ordered.answer),
  );
}

RuleDraft _randomRuleDraft(Random random, OrderedRuleReplyRace race) {
  return RuleDraft(
    title: 'Rule ${random.nextInt(1000)}',
    details: randomText(random),
    scope: randomScopeOver(random, race.workspaceIds),
  );
}

void createOrderedRaceRule(Random random, OrderedRuleReplyRace race) {
  final RuleDraft draft = _randomRuleDraft(random, race);
  race.pendingWork.start(race.rules.createRule(draft));
}

void updateOrderedRaceRule(Random random, OrderedRuleReplyRace race) {
  final List<Rule> listed = race.rules.listRules();
  if (listed.isEmpty) {
    return;
  }
  final RuleId ruleId = pickOne(random, listed).id;
  final RuleDraft draft = _randomRuleDraft(random, race);
  race.pendingWork.start(race.rules.updateRule(ruleId, draft));
}

void switchOrderedRuleWorkspace(Random random, OrderedRuleReplyRace race) {
  final WorkspaceId currentWorkspaceId = race.workspaces.currentWorkspace().id;
  final List<Workspace> others = <Workspace>[
    for (final Workspace workspace in race.workspaces.listWorkspaces())
      if (workspace.id != currentWorkspaceId) workspace,
  ];
  race.pendingWork.start(
    race.workspaces.switchWorkspace(pickOne(random, others).id),
  );
}

void addRuleElsewhere(Random random, OrderedRuleReplyRace race) {
  seedSimulatedRule(
    random: random,
    simulated: race.node,
    workspaceIds: race.workspaceIds,
    index: random.nextInt(1000),
  );
  race.node.rules.last['id'] = randomRecordIdentifier(random, _ruleKind);
  race.announceRuleChange();
}

void deleteRuleElsewhereInOrder(Random random, OrderedRuleReplyRace race) {
  if (race.node.rules.isEmpty) {
    return;
  }
  race.node.rules.remove(pickOne(random, race.node.rules));
  race.announceRuleChange();
}
