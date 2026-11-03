import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListApprovalsCommand implements NodeCommand<ApprovalsView> {
  const ListApprovalsCommand();

  @override
  String get name => 'list_approvals';

  @override
  JsonObject get arguments => noArguments;

  @override
  ApprovalsView decodeReply(Object? okValue) {
    return ApprovalsView.fromJson(okValue);
  }
}

final class CreateApprovalCommand implements NodeCommand<ApprovalRequest> {
  const CreateApprovalCommand({required this.runId, required this.action});

  final RunId? runId;
  final ApprovalAction action;

  @override
  String get name => 'create_approval';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'run_id': runId?.value,
      'action': action.toJson(),
    };
  }

  @override
  ApprovalRequest decodeReply(Object? okValue) {
    return ApprovalRequest.fromJson(okValue);
  }
}

final class DecideApprovalCommand implements NodeCommand<void> {
  const DecideApprovalCommand({
    required this.approvalId,
    required this.decision,
  });

  final ApprovalId approvalId;
  final ApprovalDecision decision;

  @override
  String get name => 'decide_approval';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'approval_id': approvalId.value,
      'decision': decision.wireName,
    };
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}
