import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/approval_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _approvalKind = 'approval request';

final class NodeBackedApprovalRepository extends ChangeNotifier
    implements ApprovalRepository, NodeSynchronized {
  NodeBackedApprovalRepository({required NodeCommandChannel channel})
    : _channel = channel;

  final NodeCommandChannel _channel;
  final FetchSequence _fetches = FetchSequence();
  List<ApprovalRequest> _approvals = const <ApprovalRequest>[];

  @override
  List<ApprovalRequest> listApprovals() => _approvals;

  @override
  List<ApprovalRequest> listPendingApprovals() {
    final List<ApprovalRequest> pending = <ApprovalRequest>[
      for (final ApprovalRequest request in _approvals)
        if (request.isPending) request,
    ];
    return List<ApprovalRequest>.unmodifiable(pending);
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
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final node.ApprovalsView view = await executeNodeCommand(
      _channel,
      const node.ListApprovalsCommand(),
    );
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    final List<ApprovalRequest> approvals = <ApprovalRequest>[
      for (final node.ApprovalView approvalView in view.approvals)
        mapApprovalViewFromNode(approvalView),
    ];

    _approvals = List<ApprovalRequest>.unmodifiable(approvals);
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    switch (topic) {
      case node.AreaChanged(area: node.ChangeArea.approvals):
        await load();
      case node.AreaChanged():
      case node.RunChanged():
        return;
    }
  }

  @override
  Future<ApprovalRequest> decideApproval(
    ApprovalId approvalId,
    ApprovalDecision decision,
  ) async {
    await executeNodeCommand(
      _channel,
      node.DecideApprovalCommand(
        approvalId: approvalId,
        decision: mapApprovalDecisionToNode(decision),
      ),
    );

    await load();
    return findApproval(approvalId);
  }
}
