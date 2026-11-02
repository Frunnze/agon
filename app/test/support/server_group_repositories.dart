import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import 'app_harness.dart';

typedef ServerBackupChange = Future<AppServerGroup> Function();

const String keepBackupLabel = 'Keep a backup of the server';

Finder findServerBackupToggle() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is SwitchToggle && widget.semanticLabel == keepBackupLabel,
  );
}

FakeWorkspaceRepository buildServerGroupRepository(AppServerGroup group) {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: group,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
}

AppDependencies buildDependenciesWithServerDown() {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    workspaceRepository: FakeWorkspaceRepository(
      workspaces: galleryWorkspaces,
      currentWorkspaceId: GalleryWorkspaceIds.acme,
      appServerStatus: AppServerStatus(
        address: 'relay.acme.dev',
        state: AppServerState.unreachable,
        lastConnectedAt: galleryToday(14, 12),
        retryInterval: const Duration(seconds: 10),
      ),
      appServerGroup: galleryAppServerGroup,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      clock: FixedClock(galleryNow),
    ),
  );
}

AppDependencies buildDependenciesWithServerGroup(AppServerGroup group) {
  return replaceRepositories(
    buildGalleryDependencies(),
    workspaceRepository: buildServerGroupRepository(group),
  );
}

final class ScriptedServerBackupRepository implements WorkspaceRepository {
  ScriptedServerBackupRepository({
    required FakeWorkspaceRepository inner,
    required ServerBackupChange startBackup,
  }) : _inner = inner,
       _startBackup = startBackup;

  final FakeWorkspaceRepository _inner;
  final ServerBackupChange _startBackup;
  int startCount = 0;

  @override
  void addListener(VoidCallback listener) => _inner.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    _inner.removeListener(listener);
  }

  @override
  List<Workspace> listWorkspaces() => _inner.listWorkspaces();

  @override
  Workspace currentWorkspace() => _inner.currentWorkspace();

  @override
  Future<Workspace> switchWorkspace(WorkspaceId workspaceId) {
    return _inner.switchWorkspace(workspaceId);
  }

  @override
  Future<Workspace> createWorkspace({required String name}) {
    return _inner.createWorkspace(name: name);
  }

  @override
  Future<void> deleteWorkspace(WorkspaceId workspaceId) {
    return _inner.deleteWorkspace(workspaceId);
  }

  @override
  AppServerStatus findAppServerStatus() => _inner.findAppServerStatus();

  @override
  Future<AppServerStatus> retryAppServer() => _inner.retryAppServer();

  @override
  AppServerGroup findAppServerGroup() => _inner.findAppServerGroup();

  @override
  Future<AppServerGroup> startServerBackup() {
    startCount += 1;
    return _startBackup();
  }

  @override
  Future<AppServerGroup> stopServerBackup() => _inner.stopServerBackup();
}
