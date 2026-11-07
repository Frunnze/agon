import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import 'planned_refusal.dart';

final class RefusingPairingRepository implements PairingRepository {
  RefusingPairingRepository({required this.stored, required this.refusal});

  final PairingRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  PairingSession? findActiveSession() => stored.findActiveSession();

  @override
  Future<PairingSession> startPairing() {
    return refusal.refuseOr(stored.startPairing);
  }

  @override
  PairingRequest? findPendingRequest() => stored.findPendingRequest();

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) {
    return refusal.refuseOr(() => stored.approvePairing(workspaces));
  }

  @override
  Future<void> rejectPairing() => refusal.refuseOr(stored.rejectPairing);

  @override
  Future<void> cancelPairing() => refusal.refuseOr(stored.cancelPairing);

  @override
  WaitingJoin? findWaitingJoin() => stored.findWaitingJoin();

  @override
  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  }) {
    return stored.joinWithCode(
      serverAddress: serverAddress,
      code: code,
      deviceName: deviceName,
      role: role,
    );
  }

  @override
  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  }) {
    return stored.createHostedAccount(
      workspaceName: workspaceName,
      deviceName: deviceName,
      role: role,
    );
  }
}

final class RefusingWorkspaceRepository implements WorkspaceRepository {
  RefusingWorkspaceRepository({required this.stored, required this.refusal});

  final WorkspaceRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Workspace> listWorkspaces() => stored.listWorkspaces();

  @override
  Workspace currentWorkspace() => stored.currentWorkspace();

  @override
  Future<Workspace> switchWorkspace(WorkspaceId workspaceId) {
    return refusal.refuseOr(() => stored.switchWorkspace(workspaceId));
  }

  @override
  Future<Workspace> createWorkspace({required String name}) {
    return refusal.refuseOr(() => stored.createWorkspace(name: name));
  }

  @override
  Future<void> deleteWorkspace(WorkspaceId workspaceId) {
    return stored.deleteWorkspace(workspaceId);
  }

  @override
  Future<Workspace> saveProtectedFiles({
    required WorkspaceId workspaceId,
    required List<String> patterns,
  }) {
    return stored.saveProtectedFiles(
      workspaceId: workspaceId,
      patterns: patterns,
    );
  }

  @override
  Future<Workspace> resetProtectedFiles(WorkspaceId workspaceId) {
    return stored.resetProtectedFiles(workspaceId);
  }

  @override
  Future<Workspace> changeApprovalPolicy({
    required WorkspaceId workspaceId,
    required ApprovalPolicy approvalPolicy,
  }) {
    return refusal.refuseOr(
      () => stored.changeApprovalPolicy(
        workspaceId: workspaceId,
        approvalPolicy: approvalPolicy,
      ),
    );
  }

  @override
  AppServerStatus findAppServerStatus() => stored.findAppServerStatus();

  @override
  Future<AppServerStatus> retryAppServer() {
    return refusal.refuseOr(stored.retryAppServer);
  }

  @override
  AppServerGroup findAppServerGroup() => stored.findAppServerGroup();

  @override
  Future<AppServerGroup> startServerBackup() => stored.startServerBackup();

  @override
  Future<AppServerGroup> stopServerBackup() => stored.stopServerBackup();
}

final class RefusingDeviceRepository implements DeviceRepository {
  RefusingDeviceRepository({required this.stored, required this.refusal});

  final DeviceRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Device> listDevices() => stored.listDevices();

  @override
  Device findDevice(DeviceId deviceId) => stored.findDevice(deviceId);

  @override
  Device currentDevice() => stored.currentDevice();

  @override
  String? findPeerAddressProblem() => stored.findPeerAddressProblem();

  @override
  Future<CheckedFolder> checkLocalFolder(String path) {
    return stored.checkLocalFolder(path);
  }

  @override
  Future<CheckedFolder> createLocalFolder({
    required String parent,
    required String name,
  }) {
    return stored.createLocalFolder(parent: parent, name: name);
  }

  @override
  Future<Device> revokeDevice(DeviceId deviceId) {
    return refusal.refuseOr(() => stored.revokeDevice(deviceId));
  }

  @override
  Future<Device> addDeviceToWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) {
    return refusal.refuseOr(
      () => stored.addDeviceToWorkspace(deviceId, workspaceId),
    );
  }

  @override
  Future<Device> removeDeviceFromWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) {
    return refusal.refuseOr(
      () => stored.removeDeviceFromWorkspace(deviceId, workspaceId),
    );
  }
}

final class RefusingProjectRepository implements ProjectRepository {
  RefusingProjectRepository({required this.stored, required this.refusal});

  final ProjectRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Project> listProjects(WorkspaceId workspaceId) {
    return stored.listProjects(workspaceId);
  }

  @override
  Project findProject(ProjectId projectId) => stored.findProject(projectId);

  @override
  Future<Project> createProject(ProjectDraft draft) {
    return refusal.refuseOr(() => stored.createProject(draft));
  }

  @override
  Future<Project> addRepository(ProjectId projectId, Repository repository) {
    return stored.addRepository(projectId, repository);
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) {
    return refusal.refuseOr(() => stored.removeRepository(projectId, address));
  }

  @override
  Future<void> deleteProject(ProjectId projectId) {
    return stored.deleteProject(projectId);
  }
}
