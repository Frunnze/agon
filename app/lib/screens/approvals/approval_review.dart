import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

final class ApprovalReview {
  const ApprovalReview({
    required this.approvalRepository,
    required this.workflowRepository,
    required this.deviceRepository,
    required this.clock,
  });

  final ApprovalRepository approvalRepository;
  final WorkflowRepository workflowRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;

  Future<void> review({
    required BuildContext context,
    required ApprovalRequest request,
    required String? runLabel,
  }) async {
    final ApprovalDecision? decision = await askForDecision(
      context: context,
      request: request,
      runLabel: runLabel,
    );
    if (decision == null) {
      return;
    }

    await approvalRepository.decideApproval(request.id, decision);
  }

  Future<ApprovalDecision?> askForDecision({
    required BuildContext context,
    required ApprovalRequest request,
    required String? runLabel,
  }) {
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );
    final String requesterName = deviceNames.nameOf(request.requestedBy);
    final String askedAt = describeTimeSince(
      request.requestedAt,
      clock.now(),
    ).toLowerCase();

    return showAppDialog<ApprovalDecision>(
      context: context,
      builder: (BuildContext _) => ApprovalDialog(
        request: request,
        runLabel: runLabel,
        askedBy: 'Agent on $requesterName, $askedAt',
        workflows: workflowRepository.listWorkflows(),
        deviceNames: deviceNames,
      ),
    );
  }
}
