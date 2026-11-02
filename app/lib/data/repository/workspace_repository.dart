import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

abstract interface class WorkspaceRepository implements Listenable {
  List<Workspace> listWorkspaces();

  Workspace currentWorkspace();

  Future<Workspace> switchWorkspace(WorkspaceId workspaceId);

  Future<Workspace> createWorkspace({required String name});

  Future<void> deleteWorkspace(WorkspaceId workspaceId);

  AppServerStatus findAppServerStatus();

  Future<AppServerStatus> retryAppServer();

  AppServerGroup findAppServerGroup();

  Future<AppServerGroup> startServerBackup();

  Future<AppServerGroup> stopServerBackup();
}
