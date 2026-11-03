import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/approvals/approval_review.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const List<String> _columnLabels = <String>['Request', 'From', 'Asked', ''];

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({
    required this.approvalRepository,
    required this.taskRepository,
    required this.workflowRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final ApprovalRepository approvalRepository;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        approvalRepository,
        taskRepository,
        workflowRepository,
        deviceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final List<ApprovalRequest> pending = approvalRepository
        .listPendingApprovals();
    if (pending.isEmpty) {
      return const AppPage(
        children: <Widget>[
          PageHeader(title: 'Approvals'),
          EmptyState(
            title: 'No approvals waiting',
            message:
                'When an agent asks to do something that needs your approval, '
                'the request waits here.',
            action: null,
          ),
        ],
      );
    }

    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Approvals',
          summary: <TextSegment>[
            TextSegment(describeWaitingApprovals(pending.length)),
          ],
        ),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[
            for (final ApprovalRequest request in pending)
              _buildRow(context, request, deviceNames),
          ],
        ),
      ],
    );
  }

  ListRowData _buildRow(
    BuildContext context,
    ApprovalRequest request,
    DeviceNames deviceNames,
  ) {
    final List<Workflow> workflows = workflowRepository.listWorkflows();
    final ApprovalAction action = request.action;
    final WorkflowChange? change = action is SignWorkflowAction
        ? workflowRepository.findPendingChange(action.workflowId)
        : null;

    return ListRowData(
      key: ValueKey<ApprovalId>(request.id),
      main: MixedListRowMain(
        title: describeApprovalTitleSegments(action, workflows),
        subtitle: describeApprovalContext(
          action: action,
          runLabel: _describeRunLabel(request.runId, workflows),
          change: change,
        ),
      ),
      meta: <Widget>[
        MixedText(<TextSegment>[
          TextSegment.monospace(deviceNames.nameOf(request.requestedBy)),
        ]),
        Text(describeTimeSince(request.requestedAt, clock.now())),
      ],
      end: const RowAction(label: 'Review'),
      onTap: () => _openRequest(context, request),
    );
  }

  String? _describeRunLabel(RunId? runId, List<Workflow> workflows) {
    if (runId == null) {
      return null;
    }

    final Run run;
    final Task task;
    try {
      run = taskRepository.findRun(runId);
      task = taskRepository.findTask(run.taskId);
    } on RecordNotFound {
      return null;
    }

    return describeRunLabel(
      task: task,
      workflow: findWorkflowForDoer(task.doer, workflows),
      run: run,
    );
  }

  void _openRequest(BuildContext context, ApprovalRequest request) {
    final RunId? runId = request.runId;
    final ApprovalAction action = request.action;

    if (action is SignWorkflowAction) {
      navigation.openRoute(WorkflowChangeRoute(action.workflowId));
    } else if (runId != null) {
      navigation.openRoute(ChatRoute(runId));
    } else {
      unawaited(_reviewWithoutRun(context, request));
    }
  }

  Future<void> _reviewWithoutRun(
    BuildContext context,
    ApprovalRequest request,
  ) {
    final ApprovalReview review = ApprovalReview(
      approvalRepository: approvalRepository,
      workflowRepository: workflowRepository,
      deviceRepository: deviceRepository,
      clock: clock,
    );
    return review.review(context: context, request: request, runLabel: null);
  }
}
