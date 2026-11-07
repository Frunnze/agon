import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

const String _runnerKind = 'runner';
const String _notARunnerProblem = 'this device cannot run tasks';
const String _noOffersProblem =
    'a runner offers at least one place for agents to run';
const List<AgentPlace> _placesInNodeOrder = <AgentPlace>[
  AgentPlace.localProcess,
  AgentPlace.container,
];

final class FakeRunnerRepository extends ChangeNotifier
    implements RunnerRepository {
  FakeRunnerRepository({
    required List<Runner> runners,
    required List<PlaceOffer>? thisDeviceOffers,
    required String? thisRunnerProblem,
  }) : _runners = List<Runner>.unmodifiable(runners),
       _thisDeviceOffers = _copyOffers(thisDeviceOffers),
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
    if (offers.isEmpty) {
      throw StateError(_noOffersProblem);
    }

    final List<PlaceOffer> chosenOffers = <PlaceOffer>[
      for (final AgentPlace place in _placesInNodeOrder)
        if (offers.contains(place))
          PlaceOffer(
            place: place,
            problem: _findPreviousProblem(previousOffers, place),
          ),
    ];
    _thisDeviceOffers = List<PlaceOffer>.unmodifiable(chosenOffers);
    _thisRunnerProblem = _findBlockingProblem(chosenOffers);
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

String? _findBlockingProblem(List<PlaceOffer> offers) {
  for (final PlaceOffer offer in offers) {
    if (offer.problem == null) {
      return null;
    }
  }
  return offers.first.problem;
}

List<PlaceOffer>? _copyOffers(List<PlaceOffer>? offers) {
  if (offers == null) {
    return null;
  }
  return List<PlaceOffer>.unmodifiable(offers);
}
