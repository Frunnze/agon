import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';

enum RunnerLink { direct, relay, localNetwork, unreachable }

enum AgentPlace { container, localProcess }

const AgentPlace defaultAgentPlace = AgentPlace.localProcess;

final class PlaceOffer {
  const PlaceOffer({required this.place, required this.problem});

  final AgentPlace place;
  final String? problem;

  @override
  bool operator ==(Object other) {
    return other is PlaceOffer &&
        other.place == place &&
        other.problem == problem;
  }

  @override
  int get hashCode => Object.hash(place, problem);
}

final class Runner {
  Runner({
    required this.deviceId,
    required List<String> labels,
    required this.slotsTotal,
    required this.slotsBusy,
    required this.link,
    required this.online,
    required this.acceptingNewRuns,
    required List<AgentPlace> offers,
    required List<String> allowedHosts,
  }) : labels = List<String>.unmodifiable(labels),
       offers = List<AgentPlace>.unmodifiable(offers),
       allowedHosts = List<String>.unmodifiable(allowedHosts);

  final DeviceId deviceId;
  final List<String> labels;
  final int slotsTotal;
  final int slotsBusy;
  final RunnerLink link;
  final bool online;
  final bool acceptingNewRuns;
  final List<AgentPlace> offers;
  final List<String> allowedHosts;

  Runner asPaused() {
    return Runner(
      deviceId: deviceId,
      labels: labels,
      slotsTotal: slotsTotal,
      slotsBusy: slotsBusy,
      link: link,
      online: online,
      acceptingNewRuns: false,
      offers: offers,
      allowedHosts: allowedHosts,
    );
  }

  Runner asAcceptingNewRuns() {
    return Runner(
      deviceId: deviceId,
      labels: labels,
      slotsTotal: slotsTotal,
      slotsBusy: slotsBusy,
      link: link,
      online: online,
      acceptingNewRuns: true,
      offers: offers,
      allowedHosts: allowedHosts,
    );
  }
}

sealed class RunnerTarget {
  const RunnerTarget();
}

final class AnyFreeRunner extends RunnerTarget {
  const AnyFreeRunner();

  @override
  bool operator ==(Object other) => other is AnyFreeRunner;

  @override
  int get hashCode => (AnyFreeRunner).hashCode;
}

final class SpecificRunner extends RunnerTarget {
  const SpecificRunner(this.deviceId);

  final DeviceId deviceId;

  @override
  bool operator ==(Object other) {
    return other is SpecificRunner && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}

final class RunnerWithLabels extends RunnerTarget {
  RunnerWithLabels(List<String> labels)
    : labels = List<String>.unmodifiable(labels);

  final List<String> labels;

  @override
  bool operator ==(Object other) {
    return other is RunnerWithLabels && listEquals(other.labels, labels);
  }

  @override
  int get hashCode => Object.hashAll(labels);
}
