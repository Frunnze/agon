import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class Workspace {
  Workspace({
    required this.id,
    required this.name,
    required this.appServerAddress,
    required List<String> protectedFiles,
    required this.approvalPolicy,
  }) : protectedFiles = List<String>.unmodifiable(protectedFiles);

  final WorkspaceId id;
  final String name;
  final String appServerAddress;
  final List<String> protectedFiles;
  final ApprovalPolicy approvalPolicy;

  Workspace withApprovalPolicy(ApprovalPolicy nextApprovalPolicy) {
    return Workspace(
      id: id,
      name: name,
      appServerAddress: appServerAddress,
      protectedFiles: protectedFiles,
      approvalPolicy: nextApprovalPolicy,
    );
  }
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
