import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const String _serverDownLead = 'Runners on this network still work.';

enum RunnerReach { reachable, offline, needsServer }

RunnerReach findRunnerReach(Runner runner, AppServerState serverState) {
  if (!runner.online) {
    return RunnerReach.offline;
  }

  final bool needsServer =
      serverState == AppServerState.unreachable &&
      runner.link == RunnerLink.relay;
  if (needsServer) {
    return RunnerReach.needsServer;
  }
  return RunnerReach.reachable;
}

int countFreeSlots(List<Runner> runners) {
  int freeSlots = 0;

  for (final Runner runner in runners) {
    if (runner.online && runner.acceptingNewRuns) {
      freeSlots += runner.slotsTotal - runner.slotsBusy;
    }
  }

  return freeSlots;
}

String describeRunnerFleet(List<Runner> runners) {
  final int onlineCount = runners
      .where((Runner runner) => runner.online)
      .length;
  final String freeSlots = describeCount(
    countFreeSlots(runners),
    singular: 'free slot',
    plural: 'free slots',
  );

  return '$onlineCount of ${runners.length} online · $freeSlots';
}

String describeReachableRunners(List<Runner> runners) {
  int reachableCount = 0;

  for (final Runner runner in runners) {
    final RunnerReach reach = findRunnerReach(
      runner,
      AppServerState.unreachable,
    );
    if (reach == RunnerReach.reachable) {
      reachableCount += 1;
    }
  }

  return '$reachableCount of ${runners.length} reachable';
}

String describeRunnerLink(RunnerLink link, AppServerState serverState) {
  final bool isServerDown = serverState == AppServerState.unreachable;

  switch (link) {
    case RunnerLink.direct:
      return isServerDown ? 'This network' : 'Direct';
    case RunnerLink.localNetwork:
      return isServerDown ? 'This network' : 'Same network';
    case RunnerLink.relay:
      return isServerDown ? 'Needs the server' : 'Relay';
    case RunnerLink.unreachable:
      return 'Unreachable';
  }
}

String describeRunnerSummary({
  required Runner runner,
  required RunnerReach reach,
  required String lastSeen,
}) {
  switch (reach) {
    case RunnerReach.reachable:
      final String state = runner.acceptingNewRuns ? 'Online' : 'Paused';
      return '$state · ${runner.slotsBusy} of ${runner.slotsTotal} '
          'slots busy';
    case RunnerReach.offline:
      return 'Offline · last seen $lastSeen';
    case RunnerReach.needsServer:
      return 'Unreachable · waits for the app server';
  }
}

String _joinNames(List<String> names) {
  if (names.length == 1) {
    return names.single;
  }

  final String leading = names.sublist(0, names.length - 1).join(', ');
  return '$leading and ${names.last}';
}

String describeServerDownNotice(List<String> waitingRunnerNames) {
  if (waitingRunnerNames.isEmpty) {
    return _serverDownLead;
  }

  final String names = _joinNames(waitingRunnerNames);
  return '$_serverDownLead Runs for $names wait until the server is back.';
}

String describeServerRetry(AppServerStatus status) {
  final String lastConnected = formatClockTime(status.lastConnectedAt);
  final int retrySeconds = status.retryInterval.inSeconds;

  return 'Last connected $lastConnected · trying every $retrySeconds seconds';
}
