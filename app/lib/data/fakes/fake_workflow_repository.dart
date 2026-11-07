import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/current_workspace_records.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/fakes/fake_workflow_checks.dart';
import 'package:agent_orchestration/data/fakes/fake_workflow_drafting.dart';
import 'package:agent_orchestration/data/fakes/workflow_signed_content.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/scope_cleanup.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

const String _createdWorkflowPrefix = 'created-workflow-';
const String _noSignedVersionProblem = 'the workflow has no signed version';

WorkspaceScope _readAvailability(Workflow workflow) => workflow.availability;

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
    required WorkspaceRepository workspaceRepository,
  }) : _workflows = List<Workflow>.unmodifiable(workflows),
       _changes = List<WorkflowChange>.unmodifiable(changes),
       _clock = clock,
       _currentDeviceId = currentDeviceId,
       _signedVersions = collectSignedVersions(workflows),
       _drafting = FakeWorkflowDrafting(
         template: draftTemplate,
         drafterDeviceId: drafterDeviceId,
         stepDelay: draftStepDelay,
       ),
       _workspaceRepository = workspaceRepository {
    refuseDuplicateWorkflowRecords(workflows: workflows, changes: changes);
    _workspaceRepository.addListener(notifyListeners);
  }

  final Clock _clock;
  final DeviceId _currentDeviceId;
  final FakeWorkflowDrafting _drafting;
  final WorkspaceRepository _workspaceRepository;
  final Map<WorkflowId, Workflow> _signedVersions;
  int _createdWorkflowCount = 0;
  List<Workflow> _workflows;
  List<WorkflowChange> _changes;
  FakeTaskWork? _taskWork;
  FakeApprovalRepository? _approvalRepository;

  void linkWork({
    required FakeTaskWork taskWork,
    required FakeApprovalRepository approvalRepository,
  }) {
    _taskWork = taskWork;
    _approvalRepository = approvalRepository;
  }

  @override
  List<Workflow> listWorkflows() {
    return listRecordsInCurrentWorkspace(
      records: _workflows,
      workspaceRepository: _workspaceRepository,
      readWorkspaceScope: _readAvailability,
    );
  }

  @override
  Workflow findWorkflow(WorkflowId workflowId) {
    return findWorkflowIn(listWorkflows(), workflowId);
  }

  Workflow findWorkflowInAnyWorkspace(WorkflowId workflowId) {
    return findWorkflowIn(_workflows, workflowId);
  }

  @override
  WorkflowChange? findPendingChange(WorkflowId workflowId) {
    return findChangeOfListed(
      changes: _changes,
      listedWorkflows: listWorkflows(),
      workflowId: workflowId,
    );
  }

  WorkflowChange? findPendingChangeInAnyWorkspace(WorkflowId workflowId) {
    return findChangeOf(_changes, workflowId);
  }

  @override
  Future<Workflow> createWorkflow(Workflow unsavedWorkflow) async {
    refuseWorkflowUploadProblem(unsavedWorkflow);

    final Workflow created = Workflow(
      id: _claimCreatedWorkflowId(),
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
    return _storeEdit(workflow);
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) async {
    final Workflow workflow = findWorkflow(workflowId);
    refuseWorkflowProblem(workflow, describeWorkflowProblem(workflow));

    final Workflow signed = replaceSignature(
      workflow,
      signFakeWorkflow(
        workflow: workflow,
        pendingChange: findPendingChange(workflowId),
        signedBy: _currentDeviceId,
        signedAt: _clock.now(),
      ),
    );

    _storeWorkflow(signed);
    _signedVersions[workflowId] = signed;
    _removeChange(workflowId);
    notifyListeners();
    return signed;
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) async {
    refuseMissingChange(findPendingChange(workflowId), workflowId);
    final Workflow? signedVersion = _signedVersions[workflowId];
    if (signedVersion == null) {
      throw StateError(_noSignedVersionProblem);
    }

    _storeWorkflow(signedVersion);
    _removeChange(workflowId);
    notifyListeners();
    return signedVersion;
  }

  @override
  Future<void> deleteWorkflow(WorkflowId workflowId) async {
    final Workflow workflow = findWorkflowInAnyWorkspace(workflowId);
    if (_isInUse(workflowId)) {
      throw StateError(
        'workflow ${workflow.name} is still used by a task or job',
      );
    }

    _removeWorkflows(<WorkflowId>{workflowId});
  }

  void forgetUnseenWorkflows(Set<WorkspaceId> remainingWorkspaceIds) {
    final Set<WorkflowId> unseenWorkflowIds = <WorkflowId>{};
    for (final Workflow workflow in _workflows) {
      final bool isUnseen = isSeenInNoWorkspace(
        workflow.availability,
        remainingWorkspaceIds,
      );
      if (isUnseen && !_isInUse(workflow.id)) {
        unseenWorkflowIds.add(workflow.id);
      }
    }

    _removeWorkflows(unseenWorkflowIds);
  }

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    return _drafting.streamDraftProgress(
      draft: draft,
      listedWorkflows: _workflows,
      listDrafted: _listDraftedWorkflow,
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
    final String trimmedRequest = requireChangeRequest(request);

    final Workflow changed = appendRequestedAgent(
      findWorkflow(workflowId),
      trimmedRequest,
    );
    return _storeEdit(changed);
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
    return _storeEdit(replaceAgent(workflow, filled));
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(notifyListeners);
    super.dispose();
  }

  Workflow _storeEdit(Workflow edited) {
    final Workflow stored = findWorkflow(edited.id);
    refuseWorkflowUploadProblem(edited);

    final Workflow kept = replaceSignature(edited, stored.signature);
    _changes = recordUnsignedEdit(
      changes: _changes,
      stored: stored,
      edited: kept,
      changedBy: _currentDeviceId,
      changedAt: _clock.now(),
    );
    _storeWorkflow(kept);
    notifyListeners();
    return kept;
  }

  WorkflowId _claimCreatedWorkflowId() {
    WorkflowId candidate;
    do {
      _createdWorkflowCount += 1;
      candidate = WorkflowId('$_createdWorkflowPrefix$_createdWorkflowCount');
    } while (_workflows.any((Workflow listed) => listed.id == candidate));
    return candidate;
  }

  void _listDraftedWorkflow(Workflow drafted) {
    _workflows = appendRecord(_workflows, drafted);
    notifyListeners();
  }

  void _storeWorkflow(Workflow workflow) {
    _workflows = replaceRecord(
      _workflows,
      matches: (Workflow candidate) => candidate.id == workflow.id,
      replacement: workflow,
    );
  }

  bool _isInUse(WorkflowId workflowId) {
    return _taskWork?.isWorkflowInUse(workflowId) ?? false;
  }

  void _removeWorkflows(Set<WorkflowId> workflowIds) {
    _workflows = removeRecord(
      _workflows,
      matches: (Workflow workflow) => workflowIds.contains(workflow.id),
    );
    for (final WorkflowId workflowId in workflowIds) {
      _removeChange(workflowId);
      _approvalRepository?.forgetSigningRequests(workflowId);
    }
    notifyListeners();
  }

  void _removeChange(WorkflowId workflowId) {
    _changes = removeRecord(
      _changes,
      matches: (WorkflowChange change) => change.workflowId == workflowId,
    );
  }
}
