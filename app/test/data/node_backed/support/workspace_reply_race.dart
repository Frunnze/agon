import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../support/random_inputs.dart';
import 'identifier_ordered_records.dart';
import 'out_of_order_replies.dart';
import 'reply_race_properties.dart';
import 'simulated_catalog_node.dart';
import 'simulated_node_replies.dart';

const int _largestSeededWorkspaceCount = 4;
const String _workspaceKind = 'workspace';
const Set<String> _workspaceChangeCommands = <String>{
  'create_workspace',
  'change_workspace_approval_policy',
  'set_protected_files',
  'reset_protected_files',
  'delete_workspace',
  'start_server_backup',
  'stop_server_backup',
};
const node.AreaChanged _workspacesChanged = node.AreaChanged(
  area: node.ChangeArea.workspaces,
);

final class WorkspaceReplyRace implements ReplyRace {
  WorkspaceReplyRace._({
    required this.node,
    required this.transport,
    required this.announcements,
    required this.workspaces,
    required NodeCommandChannel reloadChannel,
  }) : _reloadChannel = reloadChannel;

  final SimulatedCatalogNode node;
  @override
  final OutOfOrderReplyTransport transport;
  final AnnouncingNodeAnswer announcements;
  final NodeBackedWorkspaceRepository workspaces;
  final NodeCommandChannel _reloadChannel;
  @override
  final PendingRaceWork pendingWork = PendingRaceWork();

  void announceWorkspaceChange() {
    pendingWork.start(workspaces.applyChange(_workspacesChanged));
  }

  @override
  void deliverWaitingAnnouncement() {
    if (announcements.waitingAnnouncements == 0) {
      return;
    }
    announcements.takeAnnouncement();
    announceWorkspaceChange();
  }

  Future<void> _releaseEverything() {
    return releaseRepliesAndAnnouncements(
      transport: transport,
      announcements: announcements,
      deliverAnnouncement: announceWorkspaceChange,
    );
  }

  @override
  Future<void> settle() async {
    await _releaseEverything();
    await pendingWork.finish();
    await _releaseEverything();
  }

  @override
  List<String> describeShown() => _describeWorkspaces(workspaces);

  @override
  List<String> listShownIdentifiers() {
    return <String>[
      for (final Workspace workspace in workspaces.listWorkspaces())
        workspace.id.value,
    ];
  }

  @override
  Future<List<String>> describeReload() async {
    final NodeBackedWorkspaceRepository reloaded = await openRaceWorkspaces(
      _reloadChannel,
    );
    final List<String> described = _describeWorkspaces(reloaded);
    reloaded.dispose();
    return described;
  }

  @override
  void close() {
    workspaces.dispose();
  }
}

String _describeServerGroup(AppServerGroup group) {
  final List<String> members = <String>[
    for (final AppServerMember member in group.members)
      '${member.deviceId.value}:${member.standing.name}',
  ];
  return 'group ${group.thisDeviceStanding.name} ${group.canKeepBackup} '
      '${members.join(',')}';
}

String _describeWorkspace(Workspace workspace) {
  final String protectedFiles = workspace.protectedFiles.join(',');
  return '${workspace.id.value}|${workspace.name}|$protectedFiles|'
      '${workspace.approvalPolicy.name}';
}

List<String> _describeWorkspaces(NodeBackedWorkspaceRepository workspaces) {
  return <String>[
    for (final Workspace workspace in workspaces.listWorkspaces())
      _describeWorkspace(workspace),
    _describeServerGroup(workspaces.findAppServerGroup()),
    'server ${workspaces.findAppServerStatus().state.name}',
  ];
}

void addRandomWorkspaceTo(Random random, SimulatedCatalogNode simulated) {
  final Map<String, Object?> workspace = simulated.addWorkspace(
    simulated.nextIdentifier('place'),
  );
  workspace['id'] = randomRecordIdentifier(random, _workspaceKind);
  workspace['approval_policy'] = pickOne(random, nodeApprovalPolicies);
}

Future<WorkspaceReplyRace> openWorkspaceReplyRace(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int seededCount = 1 + random.nextInt(_largestSeededWorkspaceCount);
  for (int i = 0; i < seededCount; i += 1) {
    addRandomWorkspaceTo(random, simulated);
  }
  simulated.serverGroup.foundGroup();
  simulated.serverGroup.canKeepBackup = true;
  final IdentifierOrderedCatalogNode ordered = IdentifierOrderedCatalogNode(
    simulated,
  );
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: ordered.answer,
    changeCommands: _workspaceChangeCommands,
  );
  final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
    answer: announcements.answerAndAnnounce,
    random: random,
  );
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    NodeCommandChannel(transport: transport),
  );
  transport.isHoldingReplies = true;
  return WorkspaceReplyRace._(
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    reloadChannel: buildSimulatedChannel(ordered.answer),
  );
}
