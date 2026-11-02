import 'package:agent_orchestration/data/models/identifiers.dart';

final class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.appServerAddress,
  });

  final WorkspaceId id;
  final String name;
  final String appServerAddress;
}

enum AppServerState { online, unreachable }

final class AppServerStatus {
  const AppServerStatus({
    required this.address,
    required this.state,
    required this.lastConnectedAt,
    required this.retryInterval,
  });

  final String address;
  final AppServerState state;
  final DateTime lastConnectedAt;
  final Duration retryInterval;
}
