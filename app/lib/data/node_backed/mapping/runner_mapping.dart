import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping/agent_place_mapping.dart';

RunnerTarget mapRunnerTargetFromNode(node.RunnerTarget target) {
  return switch (target) {
    node.AnyFreeRunner() => const AnyFreeRunner(),
    node.SpecificRunner(:final DeviceId deviceId) => SpecificRunner(deviceId),
    node.RunnerWithLabels(:final List<String> labels) => RunnerWithLabels(
      labels,
    ),
  };
}

node.RunnerTarget mapRunnerTargetToNode(RunnerTarget target) {
  return switch (target) {
    AnyFreeRunner() => const node.AnyFreeRunner(),
    SpecificRunner(:final DeviceId deviceId) => node.SpecificRunner(
      deviceId: deviceId,
    ),
    RunnerWithLabels(:final List<String> labels) => node.RunnerWithLabels(
      labels: labels,
    ),
  };
}

RunnerLink mapRunnerLinkFromNode(node.RunnerLink link) {
  return switch (link) {
    node.RunnerLink.direct => RunnerLink.direct,
    node.RunnerLink.relay => RunnerLink.relay,
    node.RunnerLink.localNetwork => RunnerLink.localNetwork,
    node.RunnerLink.unreachable => RunnerLink.unreachable,
  };
}

Runner mapRunnerFromNode(node.Runner runner) {
  return Runner(
    deviceId: runner.deviceId,
    labels: runner.labels,
    slotsTotal: runner.slotsTotal,
    slotsBusy: runner.slotsBusy,
    link: mapRunnerLinkFromNode(runner.link),
    online: runner.online,
    acceptingNewRuns: runner.acceptingNewRuns,
    offers: mapAgentPlacesFromNode(runner.offers),
    allowedHosts: runner.allowedHosts,
  );
}
