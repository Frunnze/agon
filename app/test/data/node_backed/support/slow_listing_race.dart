import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import 'identifier_ordered_records.dart';
import 'simulated_catalog_node.dart';
import 'simulated_scopes.dart';

const Set<String> _slowListingCommands = <String>{'list_skills', 'list_rules'};
const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const Duration _retryInterval = Duration(seconds: 30);

typedef SlowListingRace = ({
  SimulatedCatalogNode node,
  SlowListingTransport transport,
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedSkillRepository skills,
  NodeBackedRuleRepository rules,
});

final class SlowListingTransport implements NodeTransport {
  SlowListingTransport({required this.answer});

  final NodeAnswer answer;
  final List<Completer<void>> _heldReplies = <Completer<void>>[];

  int get heldReplyCount => _heldReplies.length;

  void releaseHeldReply(int position) {
    final Completer<void> heldReply = _heldReplies.removeAt(position);
    heldReply.complete();
  }

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final String reply = answer(inputJson);
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    if (!_slowListingCommands.contains(command['command'])) {
      await Future<void>.delayed(Duration.zero);
      return reply;
    }

    final Completer<void> heldReply = Completer<void>();
    _heldReplies.add(heldReply);
    await heldReply.future;
    return reply;
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a slow listing transport is never stopped');
  }
}

Future<void> releaseEveryHeldReply(SlowListingTransport transport) async {
  await pumpEventQueue();
  while (transport.heldReplyCount > 0) {
    transport.releaseHeldReply(0);
    await pumpEventQueue();
  }
}

void releaseOneHeldReply(Random random, SlowListingTransport transport) {
  if (transport.heldReplyCount == 0) {
    return;
  }
  transport.releaseHeldReply(random.nextInt(transport.heldReplyCount));
}

Future<SlowListingRace> openSlowListingRace() async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (final String name in _workspaceNames) {
    final String workspaceId = simulated.addWorkspace(name)['id']! as String;
    simulated.addSkill(workspaceId: workspaceId, name: 'skill-of-$name');
    simulated.addRule(workspaceId: workspaceId, title: 'Rule of $name');
  }
  final SlowListingTransport transport = SlowListingTransport(
    answer: IdentifierOrderedCatalogNode(simulated).answer,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: channel,
        clock: FixedClock(DateTime.utc(2026, 11, 7)),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await workspaces.load();

  final SlowListingRace race = (
    node: simulated,
    transport: transport,
    workspaces: workspaces,
    skills: NodeBackedSkillRepository(
      channel: channel,
      workspaceRepository: workspaces,
    ),
    rules: NodeBackedRuleRepository(
      channel: channel,
      workspaceRepository: workspaces,
    ),
  );
  final Future<void> skillsLoading = race.skills.load();
  final Future<void> rulesLoading = race.rules.load();
  await releaseEveryHeldReply(transport);
  await skillsLoading;
  await rulesLoading;
  return race;
}

List<String> listNodeIdsInCurrentWorkspace(
  SlowListingRace race,
  List<Map<String, Object?>> records,
) {
  final String currentWorkspaceId = race.workspaces
      .currentWorkspace()
      .id
      .value;
  final List<String> recordIds = <String>[
    for (final Map<String, Object?> record in records)
      if (isSimulatedScopeInWorkspace(record, currentWorkspaceId))
        record['id']! as String,
  ];
  recordIds.sort();
  return recordIds;
}

void expectListingsMatchTheCurrentWorkspace(SlowListingRace race) {
  final List<String> shownSkillIds = <String>[
    for (final Skill skill in race.skills.listSkills()) skill.id.value,
  ];
  final List<String> shownRuleIds = <String>[
    for (final Rule rule in race.rules.listRules()) rule.id.value,
  ];

  expect(shownSkillIds, listNodeIdsInCurrentWorkspace(race, race.node.skills));
  expect(shownRuleIds, listNodeIdsInCurrentWorkspace(race, race.node.rules));
}

void closeSlowListingRace(SlowListingRace race) {
  race.rules.dispose();
  race.skills.dispose();
  race.workspaces.dispose();
}
