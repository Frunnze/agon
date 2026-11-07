import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_workspace_contents.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';

const String _workspaceKind = 'workspace';
const String _createdWorkspacePrefix = 'created-workspace-';
const String _lastWorkspaceProblem = 'The last workspace cannot be deleted.';
const String _notClientProblem =
    'only a client device can keep a backup of the app server';
const String _noActiveServerProblem = 'the app server keeps no backups';
const String _alreadyHostingProblem =
    'this device already keeps the app server';
const String _activeServerProblem = 'this device is the active app server';
const String _notKeepingProblem = 'this device keeps no app server';

String _identifyWorkspace(Workspace workspace) => workspace.id.value;

final class FakeWorkspaceRepository extends ChangeNotifier
    implements WorkspaceRepository {
  FakeWorkspaceRepository({
    required List<Workspace> workspaces,
    required WorkspaceId currentWorkspaceId,
    required AppServerStatus appServerStatus,
    required AppServerGroup appServerGroup,
    required DeviceId currentDeviceId,
    required Clock clock,
  }) : _workspaces = List<Workspace>.unmodifiable(workspaces),
       _currentWorkspaceId = currentWorkspaceId,
       _appServerStatus = appServerStatus,
       _appServerGroup = appServerGroup,
       _currentDeviceId = currentDeviceId,
       _clock = clock {
    refuseDuplicateIdentifiers(
      workspaces,
      identify: _identifyWorkspace,
      kind: _workspaceKind,
    );
    _findWorkspace(currentWorkspaceId);
  }

  final Clock _clock;
  final DeviceId _currentDeviceId;
  List<Workspace> _workspaces;
  WorkspaceId _currentWorkspaceId;
  AppServerStatus _appServerStatus;
  AppServerGroup _appServerGroup;
  int _createdWorkspaceCount = 0;
  FakeWorkspaceContents? _contents;

  void linkContents(FakeWorkspaceContents contents) {
    _contents = contents;
  }

  @override
  List<Workspace> listWorkspaces() => _workspaces;

  @override
  Workspace currentWorkspace() => _findWorkspace(_currentWorkspaceId);

  @override
  Future<Workspace> switchWorkspace(WorkspaceId workspaceId) async {
    final Workspace workspace = _findWorkspace(workspaceId);

    _currentWorkspaceId = workspace.id;
    notifyListeners();
    return workspace;
  }

  @override
  Future<Workspace> createWorkspace({required String name}) async {
    final String trimmedName = name.trim();
    final String? nameProblem = describeNameProblem(trimmedName);
    if (nameProblem != null) {
      throw ArgumentError.value(name, 'name', nameProblem);
    }

    final Workspace workspace = Workspace(
      id: _claimCreatedWorkspaceId(),
      name: trimmedName,
      appServerAddress: _appServerStatus.address,
      protectedFiles: galleryDefaultProtectedFiles,
      approvalPolicy: ApprovalPolicy.neverAsk,
    );

    _workspaces = appendRecord(_workspaces, workspace);
    notifyListeners();
    return workspace;
  }

  @override
  Future<Workspace> saveProtectedFiles({
    required WorkspaceId workspaceId,
    required List<String> patterns,
  }) async {
    final String? problem = describeProtectedFilesProblem(patterns);
    if (problem != null) {
      throw ArgumentError.value(patterns, 'patterns', problem);
    }

    return _replaceProtectedFiles(
      workspaceId: workspaceId,
      patterns: patterns,
    );
  }

  @override
  Future<Workspace> resetProtectedFiles(WorkspaceId workspaceId) async {
    return _replaceProtectedFiles(
      workspaceId: workspaceId,
      patterns: galleryDefaultProtectedFiles,
    );
  }

  Workspace _replaceProtectedFiles({
    required WorkspaceId workspaceId,
    required List<String> patterns,
  }) {
    final Workspace stored = _findWorkspace(workspaceId);
    final Workspace changed = Workspace(
      id: stored.id,
      name: stored.name,
      appServerAddress: stored.appServerAddress,
      protectedFiles: patterns,
      approvalPolicy: stored.approvalPolicy,
    );

    return _storeChangedWorkspace(changed);
  }

  @override
  Future<Workspace> changeApprovalPolicy({
    required WorkspaceId workspaceId,
    required ApprovalPolicy approvalPolicy,
  }) async {
    final Workspace stored = _findWorkspace(workspaceId);

    return _storeChangedWorkspace(stored.withApprovalPolicy(approvalPolicy));
  }

  Workspace _storeChangedWorkspace(Workspace changed) {
    _workspaces = replaceRecord(
      _workspaces,
      matches: (Workspace workspace) => workspace.id == changed.id,
      replacement: changed,
    );
    notifyListeners();
    return changed;
  }

  @override
  Future<void> deleteWorkspace(WorkspaceId workspaceId) async {
    final Workspace deleted = _findWorkspace(workspaceId);
    if (_workspaces.length == 1) {
      throw StateError(_lastWorkspaceProblem);
    }
    _contents?.refuseRunningWork(deleted);

    _workspaces = removeRecord(
      _workspaces,
      matches: (Workspace workspace) => workspace.id == workspaceId,
    );
    if (_currentWorkspaceId == workspaceId) {
      _currentWorkspaceId = _workspaces.first.id;
    }
    await _contents?.removeContents(
      deletedWorkspaceId: workspaceId,
      remainingWorkspaceIds: <WorkspaceId>{
        for (final Workspace workspace in _workspaces) workspace.id,
      },
    );
    notifyListeners();
  }

  @override
  AppServerStatus findAppServerStatus() => _appServerStatus;

  @override
  Future<AppServerStatus> retryAppServer() async {
    _appServerStatus = AppServerStatus(
      address: _appServerStatus.address,
      state: AppServerState.online,
      lastConnectedAt: _clock.now(),
      retryInterval: _appServerStatus.retryInterval,
    );
    notifyListeners();
    return _appServerStatus;
  }

  @override
  AppServerGroup findAppServerGroup() => _appServerGroup;

  @override
  Future<AppServerGroup> startServerBackup() async {
    if (!_appServerGroup.canKeepBackup) {
      throw StateError(_notClientProblem);
    }
    if (_appServerGroup.thisDeviceStanding != ThisDeviceStanding.none) {
      throw StateError(_alreadyHostingProblem);
    }
    if (!_hasActiveServer()) {
      throw StateError(_noActiveServerProblem);
    }

    final AppServerMember thisBackup = AppServerMember(
      deviceId: _currentDeviceId,
      standing: ServerStanding.backup,
      copy: null,
    );
    return _replaceAppServerGroup(
      members: <AppServerMember>[..._appServerGroup.members, thisBackup],
      thisDeviceStanding: ThisDeviceStanding.backup,
    );
  }

  @override
  Future<AppServerGroup> stopServerBackup() async {
    if (_appServerGroup.thisDeviceStanding == ThisDeviceStanding.active) {
      throw StateError(_activeServerProblem);
    }
    if (_appServerGroup.thisDeviceStanding == ThisDeviceStanding.none) {
      throw StateError(_notKeepingProblem);
    }

    return _replaceAppServerGroup(
      members: <AppServerMember>[
        for (final AppServerMember member in _appServerGroup.members)
          if (member.deviceId != _currentDeviceId) member,
      ],
      thisDeviceStanding: ThisDeviceStanding.none,
    );
  }

  AppServerGroup _replaceAppServerGroup({
    required List<AppServerMember> members,
    required ThisDeviceStanding thisDeviceStanding,
  }) {
    _appServerGroup = AppServerGroup(
      members: members,
      thisDeviceStanding: thisDeviceStanding,
      canKeepBackup: _appServerGroup.canKeepBackup,
    );
    notifyListeners();
    return _appServerGroup;
  }

  bool _hasActiveServer() {
    return _appServerGroup.members.any(
      (AppServerMember member) => member.standing == ServerStanding.active,
    );
  }

  WorkspaceId _claimCreatedWorkspaceId() {
    WorkspaceId candidate;
    do {
      _createdWorkspaceCount += 1;
      candidate = WorkspaceId(
        '$_createdWorkspacePrefix$_createdWorkspaceCount',
      );
    } while (_isListed(candidate));
    return candidate;
  }

  bool _isListed(WorkspaceId workspaceId) {
    return _workspaces.any(
      (Workspace workspace) => workspace.id == workspaceId,
    );
  }

  Workspace _findWorkspace(WorkspaceId workspaceId) {
    return findRecord(
      _workspaces,
      matches: (Workspace workspace) => workspace.id == workspaceId,
      kind: _workspaceKind,
      identifier: workspaceId.value,
    );
  }
}
