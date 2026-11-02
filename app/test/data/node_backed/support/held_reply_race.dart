import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import 'simulated_catalog_node.dart';

const String _homeWorkspaceName = 'home';

typedef CatalogRepositories = ({
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedProjectRepository projects,
  NodeBackedRuleRepository rules,
  NodeBackedSkillRepository skills,
});

typedef HeldReplyRace = ({
  HeldReplyTransport transport,
  CatalogRepositories repositories,
});

final class HeldReplyTransport implements NodeTransport {
  HeldReplyTransport({required this.answer, required this.heldCommandName});

  final NodeAnswer answer;
  final String heldCommandName;
  final Completer<void> _release = Completer<void>();

  void releaseHeldReply() => _release.complete();

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final String reply = answer(inputJson);
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    if (command['command'] == heldCommandName) {
      await _release.future;
    }
    return reply;
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a held reply transport is never stopped');
  }
}

SimulatedCatalogNode buildSimulatedHomeNode() {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  simulated.addWorkspace(_homeWorkspaceName);
  return simulated;
}

String readHomeWorkspaceId(SimulatedCatalogNode simulated) {
  return simulated.workspaces.first['id'] as String;
}

Future<HeldReplyRace> openHeldReplyRace({
  required SimulatedCatalogNode simulated,
  required String heldCommandName,
}) async {
  final HeldReplyTransport transport = HeldReplyTransport(
    answer: simulated.answer,
    heldCommandName: heldCommandName,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: channel,
        clock: FixedClock(DateTime.utc(2026, 10, 31)),
        retryInterval: const Duration(seconds: 30),
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  final CatalogRepositories repositories = (
    workspaces: workspaces,
    projects: NodeBackedProjectRepository(
      channel: channel,
      workspaceRepository: workspaces,
    ),
    rules: NodeBackedRuleRepository(
      channel: channel,
      workspaceRepository: workspaces,
    ),
    skills: NodeBackedSkillRepository(
      channel: channel,
      workspaceRepository: workspaces,
    ),
  );

  await repositories.workspaces.load();
  await repositories.projects.load();
  await repositories.rules.load();
  await repositories.skills.load();
  return (transport: transport, repositories: repositories);
}

Future<Created> createWhileAFetchSeesIt<Created>({
  required HeldReplyRace race,
  required Future<Created> Function() create,
  required node.ChangeArea fetchedArea,
}) async {
  final Future<Created> creating = create();
  await pumpEventQueue();

  final node.AreaChanged change = node.AreaChanged(area: fetchedArea);
  await race.repositories.workspaces.applyChange(change);
  await race.repositories.projects.applyChange(change);
  await race.repositories.rules.applyChange(change);
  await race.repositories.skills.applyChange(change);

  race.transport.releaseHeldReply();
  return creating;
}

Future<void> closeHeldReplyRace(HeldReplyRace race) async {
  await pumpEventQueue();

  race.repositories.skills.dispose();
  race.repositories.rules.dispose();
  race.repositories.projects.dispose();
  race.repositories.workspaces.dispose();
}
