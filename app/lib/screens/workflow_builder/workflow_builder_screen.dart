import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

class WorkflowBuilderScreen extends StatefulWidget {
  const WorkflowBuilderScreen({
    required this.workflowId,
    required this.opening,
    required this.workflowRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.runnerRepository,
    required this.skillRepository,
    required this.navigation,
    super.key,
  });

  final WorkflowId workflowId;
  final BuilderOpening opening;
  final WorkflowRepository workflowRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final SkillRepository skillRepository;
  final AppNavigation navigation;

  @override
  State<WorkflowBuilderScreen> createState() => _WorkflowBuilderScreenState();
}

class _WorkflowBuilderScreenState extends State<WorkflowBuilderScreen> {
  late final Workflow _openedVersion;
  late final WorkflowChange? _openedChange;
  late final WorkflowChangeChat _chat = WorkflowChangeChat(
    workflowId: widget.workflowId,
    greeting: _isOpenedAfterDrafting()
        ? draftedWorkflowGreeting
        : openWorkflowGreeting,
    changeWorkflow: widget.workflowRepository.changeWorkflow,
  );
  late final WorkflowDiagramEditor _editor = WorkflowDiagramEditor(
    workflowRepository: widget.workflowRepository,
    workflowId: widget.workflowId,
  );
  bool? _isChatOpenByChoice;
  BuilderSelection? _selection;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _openedVersion = _readWorkflow();
    _openedChange = widget.workflowRepository.findPendingChange(
      widget.workflowId,
    );
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  bool _isOpenedAfterDrafting() {
    return widget.opening == BuilderOpening.afterDrafting;
  }

  bool _isChatOpen(BuildContext context) {
    final bool? choice = _isChatOpenByChoice;
    if (choice != null) {
      return choice;
    }
    return _isOpenedAfterDrafting() && LayoutSize.of(context).isLarge;
  }

  Workflow _readWorkflow() {
    return widget.workflowRepository.findWorkflow(widget.workflowId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.workflowRepository,
        widget.deviceRepository,
        widget.runnerRepository,
        widget.skillRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Workflow workflow = _readWorkflow();
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );
    final String? notice = _notice;

    return BuilderPageLayout(
      top: <Widget>[
        BuilderHeader(
          title: workflow.name,
          summary: describeBuilderSummary(
            workflow: workflow,
            state: findSignatureState(
              workflow,
              widget.workflowRepository.findPendingChange(workflow.id),
            ),
            workspaces: widget.workspaceRepository.listWorkspaces(),
          ),
          onBack: () => widget.navigation.returnTo(_workflowsRoute),
          onCancel: () => cancelBuilding(
            context: context,
            workflowRepository: widget.workflowRepository,
            openedVersion: _openedVersion,
            openedChange: _openedChange,
            navigation: widget.navigation,
          ),
          onSigned: _signAndSave,
        ),
        BuilderToolbar(
          onAgentAdded: () => _addStep(buildBlankAgent(_readWorkflow())),
          onPersonStepAdded: () =>
              _addStep(buildBlankPersonStep(_readWorkflow())),
          onChatOpened: _openChat,
        ),
        if (notice != null)
          StatusLabel(
            text: notice,
            tone: StatusTone.attention,
            icon: AppIconKind.alert,
          ),
      ],
      builder: BuilderFrame(
        canvas: EditableWorkflowDiagram(
          workflow: workflow,
          selection: _selection,
          deviceNames: deviceNames,
          onAgentSelected: (WorkflowAgentId agentId) =>
              _select(SelectedStep(agentId)),
          onConnectionSelected: (AgentConnection connection) =>
              _select(SelectedConnection(connection)),
          onSelectionCleared: () => _select(null),
          onAgentMoved: (WorkflowAgentId agentId, CanvasPosition position) =>
              _saveEdit(() => _editor.moveAgent(agentId, position)),
          onAgentsConnected: _connectAgents,
        ),
        panel: _buildPanel(context, workflow, deviceNames),
      ),
    );
  }

  Widget? _buildPanel(
    BuildContext context,
    Workflow workflow,
    DeviceNames deviceNames,
  ) {
    final Widget? selectionPanel = _buildSelectionPanel(workflow, deviceNames);
    if (selectionPanel != null || !_isChatOpen(context)) {
      return selectionPanel;
    }
    return WorkflowChatPanel(chat: _chat, onClosed: _closeChat);
  }

  Widget? _buildSelectionPanel(Workflow workflow, DeviceNames deviceNames) {
    return buildBuilderPanel(
      workflow: workflow,
      selection: _selection,
      sources: BuilderPanelSources(
        runners: widget.runnerRepository.listRunners(),
        skills: widget.skillRepository.listSkills(),
        deviceNames: deviceNames,
      ),
      actions: BuilderPanelActions(
        onAgentChanged: (WorkflowAgent agent) =>
            _saveEdit(() => _editor.changeAgent(agent)),
        onFillInRequested: (WorkflowAgentId agentId) => runShowingRefusal(
          context: context,
          title: workflow.name,
          actionLabel: fillInWithAgentLabel,
          action: () => widget.workflowRepository.fillAgentSettings(
            widget.workflowId,
            agentId,
          ),
        ),
        onAgentRemoved: _removeAgent,
        onConnectionChanged: (AgentConnection connection) =>
            _saveEdit(() => _editor.changeConnection(connection)),
        onConnectionRemoved: _removeConnection,
        onLoopAdded: _addLoop,
        onDone: () => _select(null),
      ),
    );
  }

  void _select(BuilderSelection? selection) {
    setState(() => _selection = selection);
  }

  void _openChat() {
    setState(() {
      _isChatOpenByChoice = true;
      _selection = null;
    });
  }

  void _closeChat() {
    setState(() => _isChatOpenByChoice = false);
  }

  Future<void> _addStep(WorkflowAgent blank) async {
    setState(() {
      _selection = SelectedStep(blank.id);
      _notice = null;
    });
    await _saveEdit(() => _editor.addStep(blank));
  }

  Future<void> _connectAgents(AgentConnection connection) async {
    final Workflow workflow = _readWorkflow();
    final ConnectionProblem? problem = findConnectionProblem(
      workflow,
      connection,
    );

    final bool isLoop = problem == null && pointsBack(workflow, connection);
    setState(() {
      _notice = problem?.message;
      if (isLoop) {
        _selection = DrawnLoop(connection);
      }
    });
    if (problem == null && !isLoop) {
      await _saveEdit(() => _editor.connect(connection));
    }
  }

  Future<void> _addLoop(AgentConnection loop) async {
    _select(SelectedConnection(loop));
    await _saveEdit(() => _editor.connect(loop));
  }

  Future<void> _removeConnection(AgentConnection connection) async {
    _select(null);
    await _saveEdit(() => _editor.removeConnection(connection));
  }

  Future<void> _removeAgent(WorkflowAgentId agentId) async {
    _select(null);
    await _saveEdit(() => _editor.removeAgent(agentId));
  }

  Future<void> _saveEdit(PersonAction edit) {
    return runShowingRefusal(
      context: context,
      title: _readWorkflow().name,
      actionLabel: changeSettingLabel,
      action: edit,
    );
  }

  Future<void> _signAndSave() async {
    final Workflow workflow = _readWorkflow();
    final String? problem = describeSigningProblem(workflow);
    setState(() => _notice = problem);
    if (problem != null) {
      return;
    }

    await signBuiltWorkflow(
      context: context,
      workflowRepository: widget.workflowRepository,
      workflow: workflow,
      navigation: widget.navigation,
    );
  }
}
