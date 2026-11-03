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
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String workflowNameLabel = 'Workflow name';
const String workflowNameHint =
    'Lowercase letters, digits and dashes, like feature-pipeline.';
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
  WorkflowAgentId? _selectedAgentId;
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
        FormFieldBlock(
          label: workflowNameLabel,
          hint: workflowNameHint,
          children: <Widget>[
            TextField(
              controller: _nameController,
              style: AppTextStyles.body.merge(AppTextStyles.monospace),
              decoration: InputDecoration(errorText: _nameProblem),
              onChanged: (String _) => setState(() => _nameProblem = null),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: addAgentLabel,
            icon: AppIconKind.plus,
            onPressed: _addAgent,
          ),
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
      selectedAgentId: _selectedAgentId,
      deviceNames: deviceNames,
      onAgentSelected: _selectAgent,
      onSelectionCleared: () => setState(() => _selectedAgentId = null),
      onAgentMoved: _moveAgent,
      onAgentsConnected: _connectAgents,
    );
  }

  Widget? _buildPanel(DeviceNames deviceNames) {
    final WorkflowAgentId? selectedId = _selectedAgentId;
    if (selectedId == null) {
      return null;
    }

    final WorkflowAgent agent = _workflow.findAgent(selectedId);
    return AgentSettingsPanel(
      key: ValueKey<WorkflowAgentId>(agent.id),
      workflow: _workflow,
      agent: agent,
      runnerOptions: buildRunnerOptions(
        runners: widget.runnerRepository.listRunners(),
        deviceNames: deviceNames,
        chosenTarget: agent.runsOn,
      ),
      skills: widget.skillRepository.listSkills(),
      onAgentChanged: _changeAgent,
      onFillInRequested: null,
      onRemoved: () => _removeAgent(agent.id),
      onDone: () => setState(() => _selectedAgentId = null),
    );
  }

  void _selectAgent(WorkflowAgentId agentId) {
    setState(() => _selectedAgentId = agentId);
  }

  void _addAgent() {
    final WorkflowAgent blank = buildBlankAgent(_workflow);

    setState(() {
      _workflow = addAgent(_workflow, blank);
      _selectedAgentId = blank.id;
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

    setState(() {
      _notice = problem?.message;
      if (problem == null) {
        _workflow = connectAgents(_workflow, connection);
      }
    });
  }

  void _removeAgent(WorkflowAgentId agentId) {
    setState(() {
      _selectedAgentId = null;
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
