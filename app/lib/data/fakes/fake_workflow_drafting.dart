import 'package:agent_orchestration/data/fakes/workflow_drafts.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

const String _draftedWorkflowPrefix = 'drafted-workflow-';

typedef DraftedWorkflowListing = void Function(Workflow drafted);

final class FakeWorkflowDrafting {
  FakeWorkflowDrafting({
    required Workflow template,
    required DeviceId drafterDeviceId,
    required Duration stepDelay,
  }) : _template = template,
       _drafterDeviceId = drafterDeviceId,
       _stepDelay = stepDelay;

  final Workflow _template;
  final DeviceId _drafterDeviceId;
  final Duration _stepDelay;
  final Set<WorkflowDraft> _runningDrafts = <WorkflowDraft>{};
  int _draftedWorkflowCount = 0;

  Stream<WorkflowDraftProgress> streamDraftProgress({
    required WorkflowDraft draft,
    required List<Workflow> listedWorkflows,
    required DraftedWorkflowListing listDrafted,
  }) async* {
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

    final Workflow drafted = _claimFreeDraft(listedWorkflows);

    _runningDrafts.add(draft);
    try {
      yield* _streamDraft(
        draft: draft,
        drafted: drafted,
        listDrafted: listDrafted,
      );
    } finally {
      _runningDrafts.remove(draft);
    }
  }

  Future<void> stopDrafting(WorkflowDraft draft) async {
    final bool wasRunning = _runningDrafts.remove(draft);
    if (!wasRunning) {
      throw StateError('No workflow is being drafted from these words');
    }
  }

  Workflow _claimFreeDraft(List<Workflow> listedWorkflows) {
    Workflow candidate;
    do {
      _draftedWorkflowCount += 1;
      candidate = buildDraftedWorkflow(
        template: _template,
        chosenName: '${_template.name}-$_draftedWorkflowCount',
        workflowId: WorkflowId(
          '$_draftedWorkflowPrefix$_draftedWorkflowCount',
        ),
      );
    } while (_isTaken(candidate, listedWorkflows));
    return candidate;
  }

  Stream<WorkflowDraftProgress> _streamDraft({
    required WorkflowDraft draft,
    required Workflow drafted,
    required DraftedWorkflowListing listDrafted,
  }) async* {
    final int agentCount = drafted.agents.length;

    for (int added = 0; added <= agentCount; added += 1) {
      await Future<void>.delayed(_stepDelay);
      if (!_runningDrafts.contains(draft)) {
        return;
      }
      if (added == agentCount) {
        listDrafted(drafted);
      }
      yield buildDraftProgress(
        drafted: drafted,
        addedAgentCount: added,
        drafterDeviceId: _drafterDeviceId,
      );
    }
  }
}

bool _isTaken(Workflow candidate, List<Workflow> listedWorkflows) {
  for (final Workflow listed in listedWorkflows) {
    if (listed.id == candidate.id || listed.name == candidate.name) {
      return true;
    }
  }
  return false;
}
