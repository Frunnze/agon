import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

abstract interface class ApprovalRepository implements Listenable {
  List<ApprovalRequest> listApprovals();

  List<ApprovalRequest> listPendingApprovals();

  ApprovalRequest findApproval(ApprovalId approvalId);

  Future<ApprovalRequest> decideApproval(
    ApprovalId approvalId,
    ApprovalDecision decision,
  );
}
