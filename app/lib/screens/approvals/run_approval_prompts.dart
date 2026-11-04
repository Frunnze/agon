import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/approvals/approval_review.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';

class RunApprovalPrompts extends StatefulWidget {
  const RunApprovalPrompts({
    required this.runId,
    required this.taskRepository,
    required this.workflowRepository,
    required this.approvalRepository,
    required this.deviceRepository,
    required this.clock,
    required this.child,
    super.key,
  });

  final RunId runId;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final ApprovalRepository approvalRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final Widget child;

  @override
  State<RunApprovalPrompts> createState() => _RunApprovalPromptsState();
}

class _RunApprovalPromptsState extends State<RunApprovalPrompts> {
  final Set<ApprovalId> _reviewedApprovalIds = <ApprovalId>{};
  bool _isReviewing = false;

  @override
  void initState() {
    super.initState();
    widget.approvalRepository.addListener(_scheduleApprovalReview);
    _scheduleApprovalReview();
  }

  @override
  void dispose() {
    widget.approvalRepository.removeListener(_scheduleApprovalReview);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _scheduleApprovalReview() {
    WidgetsBinding.instance.addPostFrameCallback(_startApprovalReview);
  }

  void _startApprovalReview(Duration _) {
    unawaited(_reviewNextApproval());
  }

  ApprovalRequest? _findUnreviewedApproval() {
    for (final ApprovalRequest request
        in widget.approvalRepository.listPendingApprovals()) {
      final bool isForThisRun = request.runId == widget.runId;
      if (isForThisRun && !_reviewedApprovalIds.contains(request.id)) {
        return request;
      }
    }
    return null;
  }

  Future<void> _reviewNextApproval() async {
    if (!mounted || _isReviewing) {
      return;
    }
    final ApprovalRequest? request = _findUnreviewedApproval();
    if (request == null) {
      return;
    }

    _isReviewing = true;
    _reviewedApprovalIds.add(request.id);
    final ApprovalReview review = ApprovalReview(
      approvalRepository: widget.approvalRepository,
      workflowRepository: widget.workflowRepository,
      deviceRepository: widget.deviceRepository,
      clock: widget.clock,
    );
    final ApprovalDecision? decision = await review.askForDecision(
      context: context,
      request: request,
      runLabel: findRunLabel(
        runId: widget.runId,
        taskRepository: widget.taskRepository,
        workflows: widget.workflowRepository.listWorkflows(),
      ),
    );
    _isReviewing = false;
    if (decision == null) {
      return;
    }

    await widget.approvalRepository.decideApproval(request.id, decision);
  }
}
