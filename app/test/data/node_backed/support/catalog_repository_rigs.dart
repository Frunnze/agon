import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../fakes/support/notification_counter.dart';
import '../../fakes/support/simulated_scoped_rules.dart';
import 'out_of_order_replies.dart';
import 'project_reply_race.dart';
import 'simulated_catalog_node.dart';
import 'simulated_node_replies.dart';

const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const int _largestSeededRecordCount = 6;

final class RefusingCatalogNode {
  RefusingCatalogNode(this.simulated);

  final SimulatedCatalogNode simulated;
  final Map<String, String> refusals = <String, String>{};
  final List<String> receivedCommands = <String>[];

  late final NodeCommandChannel channel = buildSimulatedChannel(answer);

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String name = command['command']! as String;
    receivedCommands.add(name);
    final String? refusal = refusals[name];
    if (refusal != null) {
      return encodeErrorReply(refusal);
    }
    return simulated.answer(inputJson);
  }

  int countCommands(String name) {
    return receivedCommands
        .where((String received) => received == name)
        .length;
  }
}

typedef ProjectRig = ({
  RefusingCatalogNode node,
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedProjectRepository projects,
  NotificationCounter notifications,
});

typedef RuleRig = ({
  RefusingCatalogNode node,
  NodeBackedWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  NodeBackedRuleRepository rules,
  NotificationCounter notifications,
});

List<WorkspaceId> _addWorkspaces(SimulatedCatalogNode simulated) {
  return <WorkspaceId>[
    for (final String name in _workspaceNames)
      WorkspaceId(simulated.addWorkspace(name)['id']! as String),
  ];
}

Future<ProjectRig> openProjectRig(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  _addWorkspaces(simulated);
  final int projectCount = random.nextInt(_largestSeededRecordCount);
  for (int i = 0; i < projectCount; i += 1) {
    addProjectElsewhere(random, simulated);
  }
  final RefusingCatalogNode refusing = RefusingCatalogNode(simulated);
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    refusing.channel,
  );
  final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
    channel: refusing.channel,
    workspaceRepository: workspaces,
  );
  await projects.load();
  final NotificationCounter notifications = NotificationCounter();
  projects.addListener(notifications.record);
  return (
    node: refusing,
    workspaces: workspaces,
    projects: projects,
    notifications: notifications,
  );
}

Future<RuleRig> openRuleRig(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<WorkspaceId> workspaceIds = _addWorkspaces(simulated);
  seedSimulatedRules(
    random: random,
    simulated: simulated,
    workspaceIds: workspaceIds,
    count: random.nextInt(_largestSeededRecordCount),
  );
  final RefusingCatalogNode refusing = RefusingCatalogNode(simulated);
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    refusing.channel,
  );
  final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
    channel: refusing.channel,
    workspaceRepository: workspaces,
  );
  await rules.load();
  final NotificationCounter notifications = NotificationCounter();
  rules.addListener(notifications.record);
  return (
    node: refusing,
    workspaces: workspaces,
    workspaceIds: workspaceIds,
    rules: rules,
    notifications: notifications,
  );
}

void closeProjectRig(ProjectRig rig) {
  rig.projects.dispose();
  rig.workspaces.dispose();
}

void closeRuleRig(RuleRig rig) {
  rig.rules.dispose();
  rig.workspaces.dispose();
}
