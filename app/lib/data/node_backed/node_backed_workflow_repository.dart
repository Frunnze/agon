import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/workflow_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

const String _workflowKind = 'workflow';
const String _workflowChangeKind = 'workflow change';
const Set<node.ChangeArea> _workflowAreas = <node.ChangeArea>{
  node.ChangeArea.workflows,
};

final class NodeBackedWorkflowRepository extends ChangeNotifier
    implements WorkflowRepository, NodeSynchronized {
  NodeBackedWorkflowRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
    required Duration draftPollInterval,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository,
       _drafting = NodeWorkflowDrafting(
         channel: channel,
         pollInterval: draftPollInterval,
       ) {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final NodeWorkflowDrafting _drafting;
  final FetchSequence _fetches = FetchSequence();
  List<Workflow> _workflows = const <Workflow>[];
  List<WorkflowChange> _changes = const <WorkflowChange>[];

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final List<node.WorkflowView> views = await _loadViews();
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _workflows = List<Workflow>.unmodifiable(<Workflow>[
      for (final node.WorkflowView view in views) mapWorkflowFromNode(view),
    ]);
    _changes = List<WorkflowChange>.unmodifiable(<WorkflowChange>[
      for (final node.WorkflowView view in views)
        ?mapPendingChangeFromNode(view),
    ]);
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _workflowAreas)) {
      await load();
    }
  }

  @override
  List<Workflow> listWorkflows() => _workflows;

  @override
  Workflow findWorkflow(WorkflowId workflowId) {
    return findRecord(
      _workflows,
      matches: (Workflow workflow) => workflow.id == workflowId,
      kind: _workflowKind,
      identifier: workflowId.value,
    );
  }

  @override
  WorkflowChange? findPendingChange(WorkflowId workflowId) {
    for (final WorkflowChange change in _changes) {
      if (change.workflowId == workflowId) {
        return change;
      }
    }
    return null;
  }

  @override
  Future<Workflow> createWorkflow(Workflow unsavedWorkflow) async {
    final node.Workflow planned = mapWorkflowToNode(unsavedWorkflow);
    final node.WorkflowView created = await executeNodeCommand(
      _channel,
      node.CreateWorkflowCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        workflowName: planned.name,
        availability: planned.availability,
        agents: planned.agents,
        connections: planned.connections,
      ),
    );
    return _storeView(created);
  }

  @override
  Future<Workflow> saveWorkflow(Workflow workflow) async {
    findWorkflow(workflow.id);
    final node.WorkflowView saved = await executeNodeCommand(
      _channel,
      node.SaveWorkflowCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        workflow: mapWorkflowToNode(workflow),
      ),
    );
    return _storeView(saved);
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) async {
    findWorkflow(workflowId);
    final node.WorkflowView signed = await executeNodeCommand(
      _channel,
      node.SignWorkflowCommand(workflowId: workflowId),
    );
    return _storeView(signed);
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) async {
    if (findPendingChange(workflowId) == null) {
      throw RecordNotFound(
        kind: _workflowChangeKind,
        identifier: workflowId.value,
      );
    }

    final node.WorkflowView kept = await executeNodeCommand(
      _channel,
      node.DiscardWorkflowChangeCommand(workflowId: workflowId),
    );
    return _storeView(kept);
  }

  @override
  Future<void> deleteWorkflow(WorkflowId workflowId) async {
    await executeNodeCommand(
      _channel,
      node.DeleteWorkflowCommand(workflowId: workflowId),
    );

    _fetches.recordLocalChange();
    _workflows = removeRecord(
      _workflows,
      matches: (Workflow workflow) => workflow.id == workflowId,
    );
    notifyListeners();
  }

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) async* {
    final String description = draft.description.trim();
    if (description.isEmpty) {
      throw ArgumentError.value(
        draft.description,
        'description',
        blankWorkflowDescriptionProblem,
      );
    }

    final node.DraftWorkflowCommand command = node.DraftWorkflowCommand(
      workspaceId: _workspaceRepository.currentWorkspace().id,
      description: description,
    );
    yield* _drafting.streamDraftProgress(
      draft: draft,
      command: command,
      storeDrafted: _storeView,
    );
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) {
    return _drafting.stopDrafting(draft);
  }

  @override
  Future<Workflow> changeWorkflow(
    WorkflowId workflowId,
    String request,
    AgentKind agent,
  ) async {
    final String trimmedRequest = request.trim();
    if (trimmedRequest.isEmpty) {
      throw ArgumentError.value(request, 'request', 'Say what to change');
    }
    findWorkflow(workflowId);

    final WorkspaceId workspaceId = _workspaceRepository.currentWorkspace().id;
    final node.WorkflowView changed = await _drafting.redraftWorkflow(
      workspaceId: workspaceId,
      command: node.ChangeWorkflowCommand(
        workspaceId: workspaceId,
        workflowId: workflowId,
        request: trimmedRequest,
        agent: mapAgentKindToNode(agent),
      ),
    );
    return _storeView(changed);
  }

  @override
  Future<Workflow> fillAgentSettings(
    WorkflowId workflowId,
    WorkflowAgentId agentId,
  ) async {
    findWorkflow(workflowId).findAgent(agentId);

    final WorkspaceId workspaceId = _workspaceRepository.currentWorkspace().id;
    final node.WorkflowView filled = await _drafting.redraftWorkflow(
      workspaceId: workspaceId,
      command: node.FillAgentSettingsCommand(
        workspaceId: workspaceId,
        workflowId: workflowId,
        agentId: agentId,
      ),
    );
    return _storeView(filled);
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(_loadAfterWorkspaceChange);
    super.dispose();
  }

  void _loadAfterWorkspaceChange() {
    startBackgroundNodeWork(load);
  }

  Future<List<node.WorkflowView>> _loadViews() async {
    final WorkspaceId? workspaceId = findCurrentWorkspaceId(
      _workspaceRepository,
    );
    if (workspaceId == null) {
      return const <node.WorkflowView>[];
    }
    return executeNodeCommand(
      _channel,
      node.ListWorkflowsCommand(workspaceId: workspaceId),
    );
  }

  Workflow _storeView(node.WorkflowView view) {
    final Workflow workflow = mapWorkflowFromNode(view);
    final WorkflowChange? change = mapPendingChangeFromNode(view);

    _fetches.recordLocalChange();
    _workflows = replaceOrAppendRecord(
      _workflows,
      matches: (Workflow candidate) => candidate.id == workflow.id,
      record: workflow,
    );
    _changes = List<WorkflowChange>.unmodifiable(<WorkflowChange>[
      for (final WorkflowChange existing in _changes)
        if (existing.workflowId != workflow.id) existing,
      ?change,
    ]);
    notifyListeners();
    return workflow;
  }
}
