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
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
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
  final TextEditingController _askController = TextEditingController();
  late final Workflow _openedVersion;
  BuilderSelection? _selection;
  String? _notice;
  bool _isAsking = false;

  @override
  void initState() {
    super.initState();
    _openedVersion = _readWorkflow();
  }

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
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
          onCancel: _cancel,
          onSigned: _signAndSave,
        ),
        if (widget.opening == BuilderOpening.afterDrafting)
          const DraftedNote(),
        BuilderToolbar(
          askController: _askController,
          onAgentAdded: () => _addStep(buildBlankAgent(_readWorkflow())),
          onPersonStepAdded: () =>
              _addStep(buildBlankPersonStep(_readWorkflow())),
          onAsked: _isAsking ? null : _askAgent,
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
          onAgentMoved: _moveAgent,
          onAgentsConnected: _connectAgents,
        ),
        panel: _buildPanel(workflow, deviceNames),
      ),
    );
  }

  Widget? _buildPanel(Workflow workflow, DeviceNames deviceNames) {
    return buildBuilderPanel(
      workflow: workflow,
      selection: _selection,
      sources: BuilderPanelSources(
        runners: widget.runnerRepository.listRunners(),
        skills: widget.skillRepository.listSkills(),
        deviceNames: deviceNames,
      ),
      actions: BuilderPanelActions(
        onAgentChanged: _changeAgent,
        onFillInRequested: (WorkflowAgentId agentId) => widget
            .workflowRepository
            .fillAgentSettings(widget.workflowId, agentId),
        onAgentRemoved: _removeAgent,
        onConnectionChanged: _changeConnection,
        onConnectionRemoved: _removeConnection,
        onLoopAdded: _addLoop,
        onDone: () => _select(null),
      ),
    );
  }

  void _select(BuilderSelection? selection) {
    setState(() => _selection = selection);
  }

  Future<void> _addStep(WorkflowAgent blank) async {
    setState(() {
      _selection = SelectedStep(blank.id);
      _notice = null;
    });
    await widget.workflowRepository.saveWorkflow(
      addAgent(_readWorkflow(), blank),
    );
  }

  Future<void> _changeAgent(WorkflowAgent agent) async {
    final Workflow changed = replaceAgent(_readWorkflow(), agent);

    await widget.workflowRepository.saveWorkflow(changed);
  }

  Future<void> _moveAgent(
    WorkflowAgentId agentId,
    CanvasPosition position,
  ) async {
    final Workflow workflow = _readWorkflow();
    final WorkflowAgent moved = workflow
        .findAgent(agentId)
        .copyWith(position: position);

    await widget.workflowRepository.saveWorkflow(
      replaceAgent(workflow, moved),
    );
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
      await widget.workflowRepository.saveWorkflow(
        connectAgents(workflow, connection),
      );
    }
  }

  Future<void> _addLoop(AgentConnection loop) async {
    _select(SelectedConnection(loop));
    await widget.workflowRepository.saveWorkflow(
      connectAgents(_readWorkflow(), loop),
    );
  }

  Future<void> _changeConnection(AgentConnection connection) async {
    await widget.workflowRepository.saveWorkflow(
      replaceConnection(_readWorkflow(), connection),
    );
  }

  Future<void> _removeConnection(AgentConnection connection) async {
    _select(null);
    await widget.workflowRepository.saveWorkflow(
      removeConnection(_readWorkflow(), connection),
    );
  }

  Future<void> _removeAgent(WorkflowAgentId agentId) async {
    _select(null);
    await widget.workflowRepository.saveWorkflow(
      removeAgent(_readWorkflow(), agentId),
    );
  }

  Future<void> _askAgent() async {
    final String request = _askController.text.trim();
    if (request.isEmpty) {
      setState(() => _notice = 'Say what the agent should change');
      return;
    }

    setState(() {
      _isAsking = true;
      _notice = null;
    });
    await widget.workflowRepository.changeWorkflow(widget.workflowId, request);
    _askController.clear();
    if (mounted) {
      setState(() => _isAsking = false);
    }
  }

  Future<void> _cancel() async {
    final bool isEdited = !hasSameDesign(_readWorkflow(), _openedVersion);
    if (isEdited) {
      await widget.workflowRepository.saveWorkflow(_openedVersion);
    }
    widget.navigation.closeRoute();
  }

  Future<void> _signAndSave() async {
    final Workflow workflow = _readWorkflow();
    final String? problem = describeSigningProblem(workflow);
    setState(() => _notice = problem);
    if (problem != null) {
      return;
    }

    await widget.workflowRepository.signWorkflow(workflow.id);
    widget.navigation.openSection(_workflowsRoute);
  }
}
