import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/compact_page_header.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String draftFailedTitle = 'The draft did not finish';
const String stopFailedTitle = 'The drafting did not stop';
const String backToDescriptionLabel = 'Back to the description';
const String _unexplainedDraftProblem =
    'The drafting agent stopped without saying why. Try again.';

class WorkflowDraftingScreen extends StatefulWidget {
  const WorkflowDraftingScreen({
    required this.draft,
    required this.workflowRepository,
    required this.deviceRepository,
    required this.skillRepository,
    required this.navigation,
    super.key,
  });

  final WorkflowDraft draft;
  final WorkflowRepository workflowRepository;
  final DeviceRepository deviceRepository;
  final SkillRepository skillRepository;
  final AppNavigation navigation;

  @override
  State<WorkflowDraftingScreen> createState() =>
      _WorkflowDraftingScreenState();
}

class _WorkflowDraftingScreenState extends State<WorkflowDraftingScreen> {
  late final StreamSubscription<WorkflowDraftProgress> _subscription;
  WorkflowDraftProgress? _progress;
  String? _problem;
  String? _stoppingProblem;

  @override
  void initState() {
    super.initState();
    final Stream<WorkflowDraftProgress> drafting = widget.workflowRepository
        .draftWorkflow(widget.draft);
    _subscription = drafting.listen(_showProgress, onError: _showProblem);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _showProgress(WorkflowDraftProgress progress) {
    if (!progress.isFinished) {
      setState(() => _progress = progress);
      return;
    }

    widget.navigation.openSection(const SectionRoute(AppSection.workflows));
    widget.navigation.openRoute(
      WorkflowBuilderRoute(
        progress.workflow.id,
        opening: BuilderOpening.afterDrafting,
      ),
    );
  }

  Future<void> _leaveDrafting() async {
    if (_problem != null) {
      _openWorkflows();
      return;
    }
    await _stopDrafting(afterStopping: _openWorkflows);
  }

  void _openWorkflows() {
    widget.navigation.openSection(const SectionRoute(AppSection.workflows));
  }

  Future<void> _stopDrafting({required VoidCallback afterStopping}) async {
    try {
      await widget.workflowRepository.stopDrafting(widget.draft);
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _stoppingProblem = explanation);
      }
      return;
    }

    if (mounted) {
      afterStopping();
    }
  }

  void _showProblem(Object problem) {
    setState(() {
      _problem = describeProblemForPeople(problem) ?? _unexplainedDraftProblem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final WorkflowDraftProgress? progress = _progress;
    final String? problem = _problem;
    final String? stoppingProblem = _stoppingProblem;
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );
    final AgentLoginPointer? loginPointer = pointToAgentLogin(
      reason: problem,
      runner: progress?.drafterDeviceId,
      deviceRepository: widget.deviceRepository,
      navigation: widget.navigation,
    );

    return BuilderPageLayout(
      top: <Widget>[
        CompactPageHeader(
          title: newWorkflowTitle,
          summary: 'Drafting from your description',
          backLink: BackLink(
            label: 'Workflows',
            onPressed: () => unawaited(_leaveDrafting()),
          ),
          actions: <Widget>[
            if (problem == null)
              AppButton.secondary(
                label: 'Stop drafting',
                onPressed: () => unawaited(
                  _stopDrafting(afterStopping: widget.navigation.closeRoute),
                ),
              )
            else
              AppButton.primary(
                label: backToDescriptionLabel,
                onPressed: widget.navigation.closeRoute,
              ),
          ],
        ),
        if (problem == null)
          StatusLabel(
            text: describeDrafter(
              progress: progress,
              deviceNames: deviceNames,
            ),
            tone: StatusTone.normal,
            icon: AppIconKind.spinner,
          )
        else
          NoticeBanner(
            tone: BannerTone.danger,
            icon: AppIconKind.alert,
            title: draftFailedTitle,
            body: <Widget>[
              Text(problem),
              ...describeAgentLoginPointer(loginPointer),
            ],
            actions: offerAgentLoginConnection(loginPointer),
          ),
        if (problem == null && stoppingProblem != null)
          NoticeBanner(
            tone: BannerTone.danger,
            icon: AppIconKind.alert,
            title: stopFailedTitle,
            body: <Widget>[Text(stoppingProblem)],
          ),
      ],
      builder: BuilderFrame(
        canvas: _buildDiagram(progress, deviceNames),
        panel: DraftProgressPanel(
          lines: describeDraftProgress(
            progress: progress,
            deviceNames: deviceNames,
            skills: widget.skillRepository.listSkills(),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagram(
    WorkflowDraftProgress? progress,
    DeviceNames deviceNames,
  ) {
    if (progress == null) {
      return const ReadOnlyWorkflowDiagram(
        nodes: <DiagramNode>[],
        edges: <DiagramEdge>[],
      );
    }

    final Workflow workflow = progress.workflow;
    final List<DiagramNode> nodes = <DiagramNode>[
      for (final WorkflowAgent agent in workflow.agents)
        describeAgentNode(
          agent: agent,
          workflow: workflow,
          deviceNames: deviceNames,
          look: NodeLook.normal,
        ),
      for (final PendingAgent pending in progress.pendingAgents)
        describePendingNode(pending),
    ];
    return ReadOnlyWorkflowDiagram(
      nodes: nodes,
      edges: describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: null,
      ),
    );
  }
}
