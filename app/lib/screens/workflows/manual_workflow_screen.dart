import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const WorkflowId _unsavedWorkflowId = WorkflowId('unsaved');
const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

class ManualWorkflowScreen extends StatefulWidget {
  const ManualWorkflowScreen({
    required this.workflowRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.runnerRepository,
    required this.skillRepository,
    required this.navigation,
    super.key,
  });

  final WorkflowRepository workflowRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final SkillRepository skillRepository;
  final AppNavigation navigation;

  @override
  State<ManualWorkflowScreen> createState() => _ManualWorkflowScreenState();
}

class _ManualWorkflowScreenState extends State<ManualWorkflowScreen> {
  final TextEditingController _nameController = TextEditingController();
  late Workflow _workflow = Workflow(
    id: _unsavedWorkflowId,
    name: '',
    availability: OnlyWorkspaces(<WorkspaceId>[
      widget.workspaceRepository.currentWorkspace().id,
    ]),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
  BuilderSelection? _selection;
  String? _nameProblem;
  String? _notice;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.deviceRepository,
        widget.runnerRepository,
        widget.skillRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );
    final String? notice = _notice;

    return BuilderPageLayout(
      top: <Widget>[
        BuilderHeader(
          title: newWorkflowTitle,
          summary: describeBuilderSummary(
            workflow: _workflow,
            state: SignatureState.notSignedYet,
            workspaces: widget.workspaceRepository.listWorkspaces(),
          ),
          onBack: widget.navigation.closeRoute,
          onCancel: widget.navigation.closeRoute,
          onSigned: () => unawaited(_signAndSave()),
        ),
        WorkflowNameRow(
          controller: _nameController,
          problem: _nameProblem,
          onChanged: (String _) => setState(() => _nameProblem = null),
          onAgentAdded: () => _addStep(buildBlankAgent(_workflow)),
          onPersonStepAdded: () => _addStep(buildBlankPersonStep(_workflow)),
        ),
        if (notice != null)
          StatusLabel(
            text: notice,
            tone: StatusTone.attention,
            icon: AppIconKind.alert,
          ),
      ],
      builder: BuilderFrame(
        canvas: _buildCanvas(deviceNames),
        panel: _buildPanel(deviceNames),
      ),
    );
  }

  Widget _buildCanvas(DeviceNames deviceNames) {
    if (_workflow.agents.isEmpty) {
      return const EmptyWorkflowCanvas();
    }

    return EditableWorkflowDiagram(
      workflow: _workflow,
      selection: _selection,
      deviceNames: deviceNames,
      onAgentSelected: (WorkflowAgentId agentId) =>
          _select(SelectedStep(agentId)),
      onConnectionSelected: (AgentConnection connection) =>
          _select(SelectedConnection(connection)),
      onSelectionCleared: () => _select(null),
      onAgentMoved: _moveAgent,
      onAgentsConnected: _connectAgents,
    );
  }

  Widget? _buildPanel(DeviceNames deviceNames) {
    return buildBuilderPanel(
      workflow: _workflow,
      selection: _selection,
      sources: BuilderPanelSources(
        runners: widget.runnerRepository.listRunners(),
        skills: widget.skillRepository.listSkills(),
        deviceNames: deviceNames,
      ),
      actions: BuilderPanelActions(
        onAgentChanged: _changeAgent,
        onFillInRequested: null,
        onAgentRemoved: _removeAgent,
        onConnectionChanged: (AgentConnection connection) => setState(
          () => _workflow = replaceConnection(_workflow, connection),
        ),
        onConnectionRemoved: _removeConnection,
        onLoopAdded: _addLoop,
        onDone: () => _select(null),
      ),
    );
  }

  void _select(BuilderSelection? selection) {
    setState(() => _selection = selection);
  }

  void _addStep(WorkflowAgent blank) {
    setState(() {
      _workflow = addAgent(_workflow, blank);
      _selection = SelectedStep(blank.id);
      _notice = null;
    });
  }

  void _changeAgent(WorkflowAgent agent) {
    setState(() => _workflow = replaceAgent(_workflow, agent));
  }

  void _moveAgent(WorkflowAgentId agentId, CanvasPosition position) {
    final WorkflowAgent moved = _workflow
        .findAgent(agentId)
        .copyWith(position: position);

    setState(() => _workflow = replaceAgent(_workflow, moved));
  }

  void _connectAgents(AgentConnection connection) {
    final ConnectionProblem? problem = findConnectionProblem(
      _workflow,
      connection,
    );

    final bool isLoop = problem == null && pointsBack(_workflow, connection);
    setState(() {
      _notice = problem?.message;
      if (isLoop) {
        _selection = DrawnLoop(connection);
      } else if (problem == null) {
        _workflow = connectAgents(_workflow, connection);
      }
    });
  }

  void _addLoop(AgentConnection loop) {
    setState(() {
      _workflow = connectAgents(_workflow, loop);
      _selection = SelectedConnection(loop);
    });
  }

  void _removeConnection(AgentConnection connection) {
    setState(() {
      _selection = null;
      _workflow = removeConnection(_workflow, connection);
    });
  }

  void _removeAgent(WorkflowAgentId agentId) {
    setState(() {
      _selection = null;
      _workflow = removeAgent(_workflow, agentId);
    });
  }

  Future<void> _signAndSave() async {
    if (_isSaving) {
      return;
    }

    final String name = _nameController.text;
    final Workflow named = _workflow.withName(name);
    final String? nameProblem = describeNameProblem(name);
    final String? graphProblem = describeSigningProblem(named);
    setState(() {
      _nameProblem = nameProblem;
      _notice = graphProblem;
    });
    if (nameProblem != null || graphProblem != null) {
      return;
    }

    await _storeAndSign(named);
  }

  Future<void> _storeAndSign(Workflow named) async {
    setState(() => _isSaving = true);

    try {
      final Workflow stored = await _storeWorkflow(named);
      _workflow = stored;
      await widget.workflowRepository.signWorkflow(stored.id);
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() {
          _notice = explanation;
          _isSaving = false;
        });
      }
      return;
    }

    widget.navigation.openSection(_workflowsRoute);
  }

  Future<Workflow> _storeWorkflow(Workflow named) {
    if (named.id == _unsavedWorkflowId) {
      return widget.workflowRepository.createWorkflow(named);
    }
    return widget.workflowRepository.saveWorkflow(named);
  }
}
