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
    required List<PlaceOffer>? thisDeviceOffers,
    required String? thisRunnerProblem,
  }) : _runners = List<Runner>.unmodifiable(runners),
       _thisDeviceOffers = thisDeviceOffers,
       _thisRunnerProblem = thisRunnerProblem;

  List<Runner> _runners;
  List<PlaceOffer>? _thisDeviceOffers;
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
  List<PlaceOffer>? findThisDeviceOffers() => _thisDeviceOffers;

  @override
  String? findThisRunnerProblem() => _thisRunnerProblem;

  @override
  Future<void> chooseAgentOffers(List<AgentPlace> offers) async {
    final List<PlaceOffer>? previousOffers = _thisDeviceOffers;
    if (previousOffers == null) {
      throw StateError(_notARunnerProblem);
    }

    _thisDeviceOffers = List<PlaceOffer>.unmodifiable(<PlaceOffer>[
      for (final AgentPlace place in offers)
        PlaceOffer(
          place: place,
          problem: _findPreviousProblem(previousOffers, place),
        ),
    ]);
    if (offers.contains(AgentPlace.localProcess)) {
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

String? _findPreviousProblem(
  List<PlaceOffer> previousOffers,
  AgentPlace place,
) {
  for (final PlaceOffer offer in previousOffers) {
    if (offer.place == place) {
      return offer.problem;
    }
  }
  return null;
}
