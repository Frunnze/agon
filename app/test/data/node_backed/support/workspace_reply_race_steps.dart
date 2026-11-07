import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../support/random_inputs.dart';
import 'identifier_ordered_records.dart';
import 'simulated_protected_files.dart';
import 'workspace_reply_race.dart';

const String _otherServerKind = 'other-server';
const String _backupStanding = 'backup';
const List<String> _samplePatterns = <String>[
  '*.key',
  '.env',
  'secrets/**',
  '~/.aws',
];

List<String> _randomPatterns(Random random) {
  return <String>[
    for (final String pattern in _samplePatterns)
      if (random.nextBool()) pattern,
  ];
}

WorkspaceId? _pickListedWorkspaceId(Random random, WorkspaceReplyRace race) {
  final List<Workspace> listed = race.workspaces.listWorkspaces();
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed).id;
}

void createRaceWorkspace(Random random, WorkspaceReplyRace race) {
  final String name = race.node.nextIdentifier('made');
  race.pendingWork.start(race.workspaces.createWorkspace(name: name));
}

void saveRaceProtectedFiles(Random random, WorkspaceReplyRace race) {
  final WorkspaceId? workspaceId = _pickListedWorkspaceId(random, race);
  if (workspaceId == null) {
    return;
  }
  race.pendingWork.start(
    race.workspaces.saveProtectedFiles(
      workspaceId: workspaceId,
      patterns: _randomPatterns(random),
    ),
  );
}

void resetRaceProtectedFiles(Random random, WorkspaceReplyRace race) {
  final WorkspaceId? workspaceId = _pickListedWorkspaceId(random, race);
  if (workspaceId == null) {
    return;
  }
  race.pendingWork.start(race.workspaces.resetProtectedFiles(workspaceId));
}

void changeRaceApprovalPolicy(Random random, WorkspaceReplyRace race) {
  final WorkspaceId? workspaceId = _pickListedWorkspaceId(random, race);
  if (workspaceId == null) {
    return;
  }
  race.pendingWork.start(
    race.workspaces.changeApprovalPolicy(
      workspaceId: workspaceId,
      approvalPolicy: pickOne(random, ApprovalPolicy.values),
    ),
  );
}

void deleteRaceWorkspace(Random random, WorkspaceReplyRace race) {
  final WorkspaceId? workspaceId = _pickListedWorkspaceId(random, race);
  if (workspaceId == null) {
    return;
  }
  race.pendingWork.start(race.workspaces.deleteWorkspace(workspaceId));
}

void startRaceServerBackup(Random random, WorkspaceReplyRace race) {
  race.pendingWork.start(race.workspaces.startServerBackup());
}

void stopRaceServerBackup(Random random, WorkspaceReplyRace race) {
  race.pendingWork.start(race.workspaces.stopServerBackup());
}

void retryRaceAppServer(Random random, WorkspaceReplyRace race) {
  race.pendingWork.start(race.workspaces.retryAppServer());
}

void addWorkspaceElsewhere(Random random, WorkspaceReplyRace race) {
  addRandomWorkspaceTo(random, race.node);
  race.announceWorkspaceChange();
}

void editWorkspaceElsewhere(Random random, WorkspaceReplyRace race) {
  final Map<String, Object?> workspace = pickOne(random, race.node.workspaces);
  workspace['name'] = race.node.nextIdentifier('renamed');
  workspace['approval_policy'] = pickOne(random, nodeApprovalPolicies);
  workspace['protected_files'] = buildSimulatedProtectedFilesJson(
    _randomPatterns(random),
  );
  race.announceWorkspaceChange();
}

void deleteWorkspaceElsewhere(Random random, WorkspaceReplyRace race) {
  if (race.node.workspaces.length < 2) {
    return;
  }
  race.node.workspaces.remove(pickOne(random, race.node.workspaces));
  race.announceWorkspaceChange();
}

bool _isOtherServer(Map<String, Object?> server) {
  final String deviceId = server['device_id']! as String;
  return deviceId.startsWith(_otherServerKind);
}

void changeServerGroupElsewhere(Random random, WorkspaceReplyRace race) {
  final List<Map<String, Object?>> servers = race.node.serverGroup.servers;
  final Map<String, Object?> other = <String, Object?>{
    'device_id': randomRecordIdentifier(random, _otherServerKind),
    'standing': _backupStanding,
  };
  if (random.nextBool()) {
    servers.add(other);
  } else {
    servers.removeWhere(_isOtherServer);
  }
  race.announceWorkspaceChange();
}

void flipServerReachabilityElsewhere(Random random, WorkspaceReplyRace race) {
  race.node.isServerReachable = !race.node.isServerReachable;
  race.announceWorkspaceChange();
}
