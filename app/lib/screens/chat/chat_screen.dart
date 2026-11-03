import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/approvals/approval_review.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/shared/live_run_watch.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.runId,
    required this.taskRepository,
    required this.workflowRepository,
    required this.chatRepository,
    required this.approvalRepository,
    required this.runnerRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final RunId runId;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final ChatRepository chatRepository;
  final ApprovalRepository approvalRepository;
  final RunnerRepository runnerRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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

  ChatRunContext _readRunContext() {
    final Run run = widget.taskRepository.findRun(widget.runId);
    final Task task = widget.taskRepository.findTask(run.taskId);

    return ChatRunContext(
      run: run,
      task: task,
      workflow: findWorkflowForDoer(
        task.doer,
        widget.workflowRepository.listWorkflows(),
      ),
      deviceNames: DeviceNames(widget.deviceRepository.listDevices()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveRunWatch(
      runId: widget.runId,
      taskRepository: widget.taskRepository,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          widget.taskRepository,
          widget.chatRepository,
          widget.runnerRepository,
          widget.deviceRepository,
        ]),
        builder: _buildPage,
      ),
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final ChatRunContext runContext = _readRunContext();
    final DeviceId? runnerId = runContext.runnerId;

    return ChatPageLayout(
      runContext: runContext,
      conversation: widget.chatRepository.findConversation(widget.runId),
      runner: runnerId == null
          ? null
          : widget.runnerRepository.findRunner(runnerId),
      thisDevice: widget.deviceRepository.currentDevice(),
      onBack: _returnToRun,
      onSend: _sendMessage,
    );
  }

  void _returnToRun() {
    widget.navigation.returnTo(TaskRunRoute(widget.runId));
  }

  Future<void> _sendMessage(String text) async {
    await widget.chatRepository.sendMessage(widget.runId, text);
  }

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
    final ApprovalRequest? request = _findUnreviewedApproval();
    if (!mounted || _isReviewing || request == null) {
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
      runLabel: _readRunContext().runLabel,
    );
    _isReviewing = false;
    if (decision == null) {
      return;
    }

    await widget.approvalRepository.decideApproval(request.id, decision);
  }
}
