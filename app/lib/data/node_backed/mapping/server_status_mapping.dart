import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/models/workspace.dart';

AppServerState _describeReachability(bool isReachable) {
  if (isReachable) {
    return AppServerState.online;
  }
  return AppServerState.unreachable;
}

AppServerStatus? mapAppServerStatusFromNode(
  node.StatusView status, {
  required AppServerStatus? previous,
  required DateTime observedAt,
  required Duration retryInterval,
}) {
  final String? address = status.serverAddress;
  if (address == null) {
    return null;
  }

  final DateTime? lastConnectedAt = status.serverReachable
      ? observedAt
      : previous?.lastConnectedAt;
  return AppServerStatus(
    address: address,
    state: _describeReachability(status.serverReachable),
    lastConnectedAt: lastConnectedAt,
    retryInterval: retryInterval,
  );
}

AppServerStatus applyServerHealthFromNode(
  AppServerStatus previous,
  node.ServerHealthView health,
) {
  final DateTime? lastConnectedAt = health.reachable
      ? health.checkedAt
      : previous.lastConnectedAt;
  return AppServerStatus(
    address: previous.address,
    state: _describeReachability(health.reachable),
    lastConnectedAt: lastConnectedAt,
    retryInterval: previous.retryInterval,
  );
}
