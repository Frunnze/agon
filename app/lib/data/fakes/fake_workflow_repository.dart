import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

const String _workflowKind = 'workflow';
const List<int> _fakeSignature = <int>[0];

final class FakeWorkflowRepository extends ChangeNotifier
    implements WorkflowRepository {
  FakeWorkflowRepository({
    required List<Workflow> workflows,
    required List<WorkflowChange> changes,
    required Clock clock,
    required DeviceId currentDeviceId,
    required Workflow draftTemplate,
    required DeviceId drafterDeviceId,
    required Duration draftStepDelay,
  }) : _workflows = List<Workflow>.unmodifiable(workflows),
       _changes = List<WorkflowChange>.unmodifiable(changes),
       _clock = clock,
       _currentDeviceId = currentDeviceId,
       _draftTemplate = draftTemplate,
       _drafterDeviceId = drafterDeviceId,
       _draftStepDelay = draftStepDelay;

  final Clock _clock;
  final DeviceId _currentDeviceId;
  final Workflow _draftTemplate;
  final DeviceId _drafterDeviceId;
  final Duration _draftStepDelay;
  final Set<WorkflowDraft> _runningDrafts = <WorkflowDraft>{};
  int _draftedWorkflowCount = 0;
  int _createdWorkflowCount = 0;
  List<Workflow> _workflows;
  List<WorkflowChange> _changes;

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
    _createdWorkflowCount += 1;
    final Workflow created = Workflow(
      id: WorkflowId('created-workflow-$_createdWorkflowCount'),
      name: unsavedWorkflow.name,
      availability: unsavedWorkflow.availability,
      agents: unsavedWorkflow.agents,
      connections: unsavedWorkflow.connections,
      signature: null,
    );

    _workflows = appendRecord(_workflows, created);
    notifyListeners();
    return created;
  }

  @override
  Future<Workflow> saveWorkflow(Workflow workflow) async {
    final bool isKnown = _workflows.any(
      (Workflow existing) => existing.id == workflow.id,
    );

    if (isKnown) {
      _storeWorkflow(workflow);
    } else {
      _workflows = appendRecord(_workflows, workflow);
    }
    notifyListeners();
    return workflow;
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) async {
    final Workflow workflow = findWorkflow(workflowId);
    final WorkflowChange? change = findPendingChange(workflowId);
    final String signedDocument =
        change?.changedDocument ??
        workflow.signature?.signedDocument ??
        'name: ${workflow.name}\n';
    final Workflow signed = Workflow(
      id: workflow.id,
      name: workflow.name,
      availability: workflow.availability,
      agents: workflow.agents,
      connections: workflow.connections,
      signature: WorkflowSignature(
        signedBy: _currentDeviceId,
        signature: _fakeSignature,
        signedDocument: signedDocument,
        signedAt: _clock.now(),
      ),
    );

    _storeWorkflow(signed);
    _removeChange(workflowId);
    notifyListeners();
    return signed;
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) async {
    if (findPendingChange(workflowId) == null) {
      throw RecordNotFound(
        kind: 'workflow change',
        identifier: workflowId.value,
      );
    }

    _removeChange(workflowId);
    notifyListeners();
    return findWorkflow(workflowId);
  }

  @override
  Future<void> deleteWorkflow(WorkflowId workflowId) async {
    findWorkflow(workflowId);

    _workflows = removeRecord(
      _workflows,
      matches: (Workflow workflow) => workflow.id == workflowId,
    );
    _removeChange(workflowId);
    notifyListeners();
  }

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) async* {
    if (draft.description.trim().isEmpty) {
      throw ArgumentError.value(
        draft.description,
        'description',
        blankWorkflowDescriptionProblem,
      );
    }
    if (_runningDrafts.contains(draft)) {
      throw StateError('This workflow is already being drafted');
    }

    _draftedWorkflowCount += 1;
    final Workflow drafted = buildDraftedWorkflow(
      template: _draftTemplate,
      chosenName: '${_draftTemplate.name}-$_draftedWorkflowCount',
      workflowId: WorkflowId('drafted-workflow-$_draftedWorkflowCount'),
    );

    _runningDrafts.add(draft);
    try {
      yield* _streamDraft(draft, drafted);
    } finally {
      _runningDrafts.remove(draft);
    }
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) async {
    final bool wasRunning = _runningDrafts.remove(draft);
    if (!wasRunning) {
      throw StateError('No workflow is being drafted from these words');
    }
  }

  Stream<WorkflowDraftProgress> _streamDraft(
    WorkflowDraft draft,
    Workflow drafted,
  ) async* {
    final int agentCount = drafted.agents.length;

    for (int added = 0; added <= agentCount; added += 1) {
      await Future<void>.delayed(_draftStepDelay);
      if (!_runningDrafts.contains(draft)) {
        return;
      }
      if (added == agentCount) {
        _workflows = appendRecord(_workflows, drafted);
        notifyListeners();
      }
      yield buildDraftProgress(
        drafted: drafted,
        addedAgentCount: added,
        drafterDeviceId: _drafterDeviceId,
      );
    }
  }

  @override
  Future<Workflow> changeWorkflow(
    WorkflowId workflowId,
    String request,
  ) async {
    final String trimmedRequest = request.trim();
    if (trimmedRequest.isEmpty) {
      throw ArgumentError.value(request, 'request', 'Say what to change');
    }

    final Workflow changed = appendRequestedAgent(
      findWorkflow(workflowId),
      trimmedRequest,
    );
    _storeWorkflow(changed);
    notifyListeners();
    return changed;
  }

  @override
  Future<Workflow> fillAgentSettings(
    WorkflowId workflowId,
    WorkflowAgentId agentId,
  ) async {
    final Workflow workflow = findWorkflow(workflowId);
    final WorkflowAgent filled = fillInAgent(
      workflow.findAgent(agentId),
      workflow.name,
    );
    final Workflow updated = replaceAgent(workflow, filled);

    _storeWorkflow(updated);
    notifyListeners();
    return updated;
  }

  void _storeWorkflow(Workflow workflow) {
    _workflows = replaceRecord(
      _workflows,
      matches: (Workflow candidate) => candidate.id == workflow.id,
      replacement: workflow,
    );
  }

  void _removeChange(WorkflowId workflowId) {
    _changes = List<WorkflowChange>.unmodifiable(
      _changes.where(
        (WorkflowChange change) => change.workflowId != workflowId,
      ),
    );
  }
}
