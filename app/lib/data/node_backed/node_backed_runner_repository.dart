import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/runner_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

const String _runnerKind = 'runner';
const Set<node.ChangeArea> _runnerAreas = <node.ChangeArea>{
  node.ChangeArea.runners,
  node.ChangeArea.devices,
  node.ChangeArea.workspaces,
};

final class NodeBackedRunnerRepository extends ChangeNotifier
    implements RunnerRepository, NodeSynchronized {
  NodeBackedRunnerRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final FetchSequence _fetches = FetchSequence();
  List<Runner> _runners = const <Runner>[];
  AgentPlace? _thisAgentPlace;
  String? _thisRunnerProblem;

  @override
  List<Runner> listRunners() => _runners;

  @override
  Runner findRunner(DeviceId deviceId) {
    return findRecord(
      _runners,
      matches: (Runner runner) => runner.deviceId == deviceId,
      kind: _runnerKind,
      identifier: deviceId.value,
    );
  }

  @override
  AgentPlace? findThisAgentPlace() => _thisAgentPlace;

  @override
  String? findThisRunnerProblem() => _thisRunnerProblem;

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final node.RunnersView? view = await _fetchRunners();
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _runners = _mapRunners(view);
    _thisAgentPlace = _mapThisAgentPlace(view);
    _thisRunnerProblem = view?.thisDeviceProblem;
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _runnerAreas)) {
      await load();
    }
  }

  @override
  Future<Runner> pauseRunner(DeviceId deviceId) async {
    await executeNodeCommand(
      _channel,
      node.PauseRunnerCommand(deviceId: deviceId),
    );
    await load();
    return findRunner(deviceId);
  }

  @override
  Future<Runner> resumeRunner(DeviceId deviceId) async {
    await executeNodeCommand(
      _channel,
      node.ResumeRunnerCommand(deviceId: deviceId),
    );
    await load();
    return findRunner(deviceId);
  }

  @override
  Future<void> chooseAgentPlace(AgentPlace place) async {
    await executeNodeCommand(
      _channel,
      node.ChooseAgentPlaceCommand(place: mapAgentPlaceToNode(place)),
    );
    await load();
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(_loadAfterWorkspaceChange);
    super.dispose();
  }

  void _loadAfterWorkspaceChange() {
    startBackgroundNodeWork(load);
  }

  Future<node.RunnersView?> _fetchRunners() async {
    final WorkspaceId? workspaceId = findCurrentWorkspaceId(
      _workspaceRepository,
    );
    if (workspaceId == null) {
      return null;
    }

    return executeNodeCommand(
      _channel,
      node.ListRunnersCommand(workspaceId: workspaceId),
    );
  }
}

List<Runner> _mapRunners(node.RunnersView? view) {
  if (view == null) {
    return const <Runner>[];
  }

  final List<Runner> runners = <Runner>[
    for (final node.RunnerView runnerView in view.runners)
      mapRunnerFromNode(runnerView.runner),
  ];
  return List<Runner>.unmodifiable(runners);
}

AgentPlace? _mapThisAgentPlace(node.RunnersView? view) {
  final node.RunnerSettings? settings = view?.thisDeviceSettings;
  if (settings == null) {
    return null;
  }
  return mapAgentPlaceFromNode(settings.sandbox);
}
