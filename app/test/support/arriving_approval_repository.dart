import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';

const List<int> _testSignature = <int>[0];

final class ArrivingApprovalRepository extends ChangeNotifier
    implements ApprovalRepository {
  List<ApprovalRequest> _approvals = const <ApprovalRequest>[];

  void raiseApproval(ApprovalRequest request) {
    _approvals = List<ApprovalRequest>.unmodifiable(<ApprovalRequest>[
      ..._approvals,
      request,
    ]);
    notifyListeners();
  }

  @override
  List<ApprovalRequest> listApprovals() => _approvals;

  @override
  List<ApprovalRequest> listPendingApprovals() {
    return <ApprovalRequest>[
      for (final ApprovalRequest request in _approvals)
        if (request.isPending) request,
    ];
  }

  @override
  ApprovalRequest findApproval(ApprovalId approvalId) {
    return _approvals.singleWhere(
      (ApprovalRequest request) => request.id == approvalId,
    );
  }

  @override
  Future<ApprovalRequest> decideApproval(
    ApprovalId approvalId,
    ApprovalDecision decision,
  ) async {
    final ApprovalRequest decided = findApproval(approvalId).withDecision(
      SignedDecision(
        decision: decision,
        decidedBy: GalleryDeviceIds.airLaptop,
        decidedAt: galleryNow,
        signature: _testSignature,
      ),
    );

    _approvals = List<ApprovalRequest>.unmodifiable(<ApprovalRequest>[
      for (final ApprovalRequest request in _approvals)
        if (request.id == approvalId) decided else request,
    ]);
    notifyListeners();
    return decided;
  }
}
