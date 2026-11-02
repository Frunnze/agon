import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _approvalKind = 'approval request';
const List<int> _fakeSignature = <int>[0];

final class FakeApprovalRepository extends ChangeNotifier
    implements ApprovalRepository {
  FakeApprovalRepository({
    required List<ApprovalRequest> approvals,
    required Clock clock,
    required DeviceId currentDeviceId,
  }) : _approvals = List<ApprovalRequest>.unmodifiable(approvals),
       _clock = clock,
       _currentDeviceId = currentDeviceId;

  final Clock _clock;
  final DeviceId _currentDeviceId;
  List<ApprovalRequest> _approvals;

  @override
  List<ApprovalRequest> listApprovals() => _approvals;

  @override
  List<ApprovalRequest> listPendingApprovals() {
    return List<ApprovalRequest>.unmodifiable(
      _approvals.where((ApprovalRequest request) => request.isPending),
    );
  }

  @override
  ApprovalRequest findApproval(ApprovalId approvalId) {
    return findRecord(
      _approvals,
      matches: (ApprovalRequest request) => request.id == approvalId,
      kind: _approvalKind,
      identifier: approvalId.value,
    );
  }

  @override
  Future<ApprovalRequest> decideApproval(
    ApprovalId approvalId,
    ApprovalDecision decision,
  ) async {
    final ApprovalRequest request = findApproval(approvalId);
    if (!request.isPending) {
      throw StateError('Approval ${approvalId.value} is already decided');
    }

    final ApprovalRequest decided = request.withDecision(
      SignedDecision(
        decision: decision,
        decidedBy: _currentDeviceId,
        decidedAt: _clock.now(),
        signature: _fakeSignature,
      ),
    );
    _approvals = replaceRecord(
      _approvals,
      matches: (ApprovalRequest candidate) => candidate.id == approvalId,
      replacement: decided,
    );
    notifyListeners();
    return decided;
  }
}
