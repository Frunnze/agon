import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/workspace_choice_store.dart';

const String _workspaceKind = 'workspace';
const Set<node.ChangeArea> _workspaceAreas = <node.ChangeArea>{
  node.ChangeArea.account,
  node.ChangeArea.workspaces,
  node.ChangeArea.serverGroup,
};

final class NodeBackedWorkspaceRepository extends ChangeNotifier
    implements WorkspaceRepository, NodeSynchronized {
  NodeBackedWorkspaceRepository({
    required NodeCommandChannel channel,
    required Clock clock,
    required Duration retryInterval,
    required WorkspaceChoiceStore choiceStore,
  }) : _channel = channel,
       _clock = clock,
       _retryInterval = retryInterval,
       _choiceStore = choiceStore;

  final NodeCommandChannel _channel;
  final Clock _clock;
  final Duration _retryInterval;
  final WorkspaceChoiceStore _choiceStore;
  final FetchSequence _fetches = FetchSequence();
  List<Workspace> _workspaces = const <Workspace>[];
  WorkspaceId? _chosenWorkspaceId;
  AppServerStatus? _appServerStatus;
  AppServerGroup? _appServerGroup;

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final node.StatusView status = await executeNodeCommand(
      _channel,
      const node.StatusCommand(),
    );
    final List<Workspace> workspaces = await _loadWorkspaces(status);
    final WorkspaceId? rememberedWorkspaceId = await _choiceStore
        .readChosenWorkspaceId();
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _workspaces = workspaces;
    _chosenWorkspaceId ??= rememberedWorkspaceId;
    _appServerStatus = mapAppServerStatusFromNode(
      status,
      previous: _appServerStatus,
      observedAt: _clock.now(),
      retryInterval: _retryInterval,
    );
    _appServerGroup = mapAppServerGroupFromNode(status.appServers);
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _workspaceAreas)) {
      await load();
    }
  }

  @override
  List<Workspace> listWorkspaces() => _workspaces;

  @override
  Workspace currentWorkspace() {
    if (_workspaces.isEmpty) {
      throw StateError('This device has no workspace yet');
    }

    for (final Workspace workspace in _workspaces) {
      if (workspace.id == _chosenWorkspaceId) {
        return workspace;
      }
    }
    return _workspaces.first;
  }

  @override
  Future<Workspace> switchWorkspace(WorkspaceId workspaceId) async {
    final Workspace workspace = findRecord(
      _workspaces,
      matches: (Workspace candidate) => candidate.id == workspaceId,
      kind: _workspaceKind,
      identifier: workspaceId.value,
    );

    await _choiceStore.saveChosenWorkspaceId(workspace.id);
    _chosenWorkspaceId = workspace.id;
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

    final node.Workspace created = await executeNodeCommand(
      _channel,
      node.CreateWorkspaceCommand(workspaceName: trimmedName),
    );
    final Workspace workspace = mapWorkspaceFromNode(created);

    _fetches.recordLocalChange();
    _workspaces = replaceOrAppendRecord(
      _workspaces,
      matches: (Workspace candidate) => candidate.id == workspace.id,
      record: workspace,
    );
    notifyListeners();
    return workspace;
  }

  @override
  Future<void> deleteWorkspace(WorkspaceId workspaceId) async {
    final bool isCurrent = currentWorkspace().id == workspaceId;
    await executeNodeCommand(
      _channel,
      node.DeleteWorkspaceCommand(workspaceId: workspaceId),
    );

    _fetches.recordLocalChange();
    _workspaces = removeRecord(
      _workspaces,
      matches: (Workspace workspace) => workspace.id == workspaceId,
    );
    if (isCurrent) {
      await switchWorkspace(_workspaces.first.id);
      return;
    }
    notifyListeners();
  }

  @override
  AppServerStatus findAppServerStatus() {
    final AppServerStatus? status = _appServerStatus;
    if (status == null) {
      throw StateError('This device has no app server yet');
    }
    return status;
  }

  @override
  Future<AppServerStatus> retryAppServer() async {
    final AppServerStatus previous = findAppServerStatus();
    final node.ServerHealthView health = await executeNodeCommand(
      _channel,
      const node.RetryServerCommand(),
    );
    final AppServerStatus next = applyServerHealthFromNode(previous, health);

    _appServerStatus = next;
    notifyListeners();
    return next;
  }

  @override
  AppServerGroup findAppServerGroup() {
    final AppServerGroup? group = _appServerGroup;
    if (group == null) {
      throw StateError('This device has not loaded its app servers yet');
    }
    return group;
  }

  @override
  Future<AppServerGroup> startServerBackup() {
    return _changeServerBackup(const node.StartServerBackupCommand());
  }

  @override
  Future<AppServerGroup> stopServerBackup() {
    return _changeServerBackup(const node.StopServerBackupCommand());
  }

  Future<AppServerGroup> _changeServerBackup(
    NodeCommand<node.AppServersView> command,
  ) async {
    final node.AppServersView view = await executeNodeCommand(
      _channel,
      command,
    );
    final AppServerGroup group = mapAppServerGroupFromNode(view);

    _fetches.recordLocalChange();
    _appServerGroup = group;
    notifyListeners();
    return group;
  }

  Future<List<Workspace>> _loadWorkspaces(node.StatusView status) async {
    if (status.account == null) {
      return const <Workspace>[];
    }

    final List<node.WorkspaceView> views = await executeNodeCommand(
      _channel,
      const node.ListWorkspacesCommand(),
    );
    return List<Workspace>.unmodifiable(<Workspace>[
      for (final node.WorkspaceView view in views)
        mapWorkspaceFromNode(view.workspace),
    ]);
  }
}
