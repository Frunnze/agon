import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/biometric_confirmation.dart';
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
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
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
    required this.biometricConfirmation,
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
  final BiometricConfirmation biometricConfirmation;
  final AppNavigation navigation;

  @override
  State<WorkflowBuilderScreen> createState() => _WorkflowBuilderScreenState();
}

class _WorkflowBuilderScreenState extends State<WorkflowBuilderScreen> {
  final TextEditingController _askController = TextEditingController();
  late final Workflow _openedVersion;
  WorkflowAgentId? _selectedAgentId;
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
          const DraftedBanner(),
        BuilderToolbar(
          askController: _askController,
          onAgentAdded: _addAgent,
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
          selectedAgentId: _selectedAgentId,
          deviceNames: deviceNames,
          onAgentSelected: _selectAgent,
          onSelectionCleared: () => setState(() => _selectedAgentId = null),
          onAgentMoved: _moveAgent,
          onAgentsConnected: _connectAgents,
        ),
        panel: _buildPanel(workflow, deviceNames),
      ),
    );
  }

  Widget? _buildPanel(Workflow workflow, DeviceNames deviceNames) {
    final WorkflowAgentId? selectedId = _selectedAgentId;
    final bool isSelectedPresent = workflow.agents.any(
      (WorkflowAgent agent) => agent.id == selectedId,
    );
    if (selectedId == null || !isSelectedPresent) {
      return null;
    }

    final WorkflowAgent agent = workflow.findAgent(selectedId);
    return AgentSettingsPanel(
      key: ValueKey<WorkflowAgentId>(agent.id),
      workflow: workflow,
      agent: agent,
      runnerOptions: buildRunnerOptions(
        runners: widget.runnerRepository.listRunners(),
        deviceNames: deviceNames,
        chosenTarget: agent.runsOn,
      ),
      skills: widget.skillRepository.listSkills(),
      onAgentChanged: _changeAgent,
      onFillInRequested: () => widget.workflowRepository.fillAgentSettings(
        widget.workflowId,
        agent.id,
      ),
      onRemoved: () => _removeAgent(agent.id),
      onDone: () => setState(() => _selectedAgentId = null),
    );
  }

  void _selectAgent(WorkflowAgentId agentId) {
    setState(() => _selectedAgentId = agentId);
  }

  Future<void> _addAgent() async {
    final Workflow workflow = _readWorkflow();
    final WorkflowAgent blank = buildBlankAgent(workflow);

    setState(() {
      _selectedAgentId = blank.id;
      _notice = null;
    });
    await widget.workflowRepository.saveWorkflow(addAgent(workflow, blank));
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

    setState(() => _notice = problem?.message);
    if (problem == null) {
      await widget.workflowRepository.saveWorkflow(
        connectAgents(workflow, connection),
      );
    }
  }

  Future<void> _removeAgent(WorkflowAgentId agentId) async {
    setState(() => _selectedAgentId = null);
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
    await widget.workflowRepository.saveWorkflow(_openedVersion);
    widget.navigation.closeRoute();
  }

  Future<void> _signAndSave() async {
    final Workflow workflow = _readWorkflow();
    final String? problem = describeSigningProblem(workflow);
    setState(() => _notice = problem);
    if (problem != null) {
      return;
    }

    final bool isConfirmed = await widget.biometricConfirmation.confirm(
      reason: 'Sign ${workflow.name}',
    );
    if (!isConfirmed) {
      return;
    }

    await widget.workflowRepository.signWorkflow(workflow.id);
    widget.navigation.openSection(_workflowsRoute);
  }
}
