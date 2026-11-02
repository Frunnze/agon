import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

const String _runnerKind = 'runner';
const String _notARunnerProblem = 'this device cannot run tasks';

final class FakeRunnerRepository extends ChangeNotifier
    implements RunnerRepository {
  FakeRunnerRepository({
    required List<Runner> runners,
    required AgentPlace? thisAgentPlace,
    required String? thisRunnerProblem,
  }) : _runners = List<Runner>.unmodifiable(runners),
       _thisAgentPlace = thisAgentPlace,
       _thisRunnerProblem = thisRunnerProblem;

  List<Runner> _runners;
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
  Future<Runner> pauseRunner(DeviceId deviceId) async {
    return _storeRunner(findRunner(deviceId).asPaused());
  }

  @override
  Future<Runner> resumeRunner(DeviceId deviceId) async {
    return _storeRunner(findRunner(deviceId).asAcceptingNewRuns());
  }

  @override
  AgentPlace? findThisAgentPlace() => _thisAgentPlace;

  @override
  String? findThisRunnerProblem() => _thisRunnerProblem;

  @override
  Future<void> chooseAgentPlace(AgentPlace place) async {
    if (_thisAgentPlace == null) {
      throw StateError(_notARunnerProblem);
    }

    _thisAgentPlace = place;
    if (place == AgentPlace.localProcess) {
      _thisRunnerProblem = null;
    }
    notifyListeners();
  }

  Runner _storeRunner(Runner runner) {
    _runners = replaceRecord(
      _runners,
      matches: (Runner candidate) => candidate.deviceId == runner.deviceId,
      replacement: runner,
    );
    notifyListeners();
    return runner;
  }
}
