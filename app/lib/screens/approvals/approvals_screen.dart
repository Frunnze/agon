import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/approvals/approval_review.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/shared/person_step_questions.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';
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
import 'package:agent_orchestration/widgets/page_section.dart';

const List<String> _columnLabels = <String>['Request', 'From', 'Asked', ''];
const String questionsSectionTitle = 'Questions for you';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({
    required this.approvalRepository,
    required this.personStepRepository,
    required this.taskRepository,
    required this.workflowRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final ApprovalRepository approvalRepository;
  final PersonStepRepository personStepRepository;
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
        personStepRepository,
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
    final List<OpenPersonStep> questions = personStepRepository
        .listOpenPersonSteps();
    if (pending.isEmpty && questions.isEmpty) {
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
            TextSegment(
              describeWaitingWork(
                approvalCount: pending.length,
                questionCount: questions.length,
              ),
            ),
          ],
        ),
        if (questions.isNotEmpty) _buildQuestions(questions),
        if (pending.isNotEmpty)
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

  Widget _buildQuestions(List<OpenPersonStep> questions) {
    final PersonStepQuestions builder = PersonStepQuestions(
      taskRepository: taskRepository,
      workflowRepository: workflowRepository,
      personStepRepository: personStepRepository,
    );
    final DateTime now = clock.now();

    return PageSection(
      title: questionsSectionTitle,
      children: <Widget>[
        for (final OpenPersonStep question in questions)
          builder.buildCardInApprovals(openStep: question, now: now),
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
    return findRunLabel(
      runId: runId,
      taskRepository: taskRepository,
      workflows: workflows,
    );
  }

  void _openRequest(BuildContext context, ApprovalRequest request) {
    final RunId? runId = request.runId;
    final ApprovalAction action = request.action;

    if (action is SignWorkflowAction) {
      navigation.openRoute(WorkflowChangeRoute(action.workflowId));
    } else if (action is ImproveSkillAction || runId == null) {
      unawaited(_reviewHere(context, request));
    } else {
      navigation.openRoute(ChatRoute(runId));
    }
  }

  Future<void> _reviewHere(BuildContext context, ApprovalRequest request) {
    final ApprovalReview review = ApprovalReview(
      approvalRepository: approvalRepository,
      workflowRepository: workflowRepository,
      deviceRepository: deviceRepository,
      clock: clock,
    );
    final String? runLabel = _describeRunLabel(
      request.runId,
      workflowRepository.listWorkflows(),
    );
    return review.review(
      context: context,
      request: request,
      runLabel: runLabel,
    );
  }
}
