import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/simulated_workflow_node.dart';

const WorkspaceId _workspaceId = WorkspaceId('drafting-workspace');
const int _draftIterations = 30;
const int _pollsOfALongDraft = 1000000;
const int _pollsOfAShortDraft = 40;
const String _description = 'Ship it';

NodeWorkflowDrafting _buildDrafting(SimulatedWorkflowNode simulated) {
  return NodeWorkflowDrafting(
    channel: simulated.channel,
    pollInterval: Duration.zero,
  );
}

WorkflowDraft _buildDraft(String label) {
  return WorkflowDraft(description: '$_description $label');
}

Stream<WorkflowDraftProgress> _streamDraft({
  required NodeWorkflowDrafting drafting,
  required WorkflowDraft draft,
  required List<node.WorkflowView> stored,
}) {
  return drafting.streamDraftProgress(
    draft: draft,
    command: node.DraftWorkflowCommand(
      workspaceId: _workspaceId,
      description: draft.description,
    ),
    storeDrafted: (node.WorkflowView view) => _storeView(stored, view),
  );
}

Workflow _storeView(List<node.WorkflowView> stored, node.WorkflowView view) {
  stored.add(view);
  return mapWorkflowFromNode(view);
}

Future<void> _waitForProgress(
  List<WorkflowDraftProgress> received,
  int count,
) async {
  await Future<void>.delayed(Duration.zero);
  while (received.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('test_stream_draft_progress_property_finishes_once_stored', () async {
    final Random random = seededRandom(9951);
    for (int i = 0; i < _draftIterations; i += 1) {
      final int polls = random.nextInt(4);
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: polls,
      );
      final List<node.WorkflowView> stored = <node.WorkflowView>[];

      final List<WorkflowDraftProgress> progress = await _streamDraft(
        drafting: _buildDrafting(simulated),
        draft: _buildDraft('drafted-$i'),
        stored: stored,
      ).toList();

      expect(stored.length, 1);
      expect(progress.length, polls + 1);
      expect(
        <bool>[
          for (final WorkflowDraftProgress step in progress) step.isFinished,
        ],
        <bool>[for (int j = 0; j < polls; j += 1) false, true],
      );
      expect(progress.last.workflow.id, stored.single.workflow.id);
    }
  });

  test(
    'test_stop_drafting_property_cancels_the_run_and_saves_nothing',
    () async {
      final Random random = seededRandom(9953);
      for (int i = 0; i < _draftIterations; i += 1) {
        final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
          pollsBeforeDraftIsDone: _pollsOfALongDraft,
        );
        final NodeWorkflowDrafting drafting = _buildDrafting(simulated);
        final WorkflowDraft draft = _buildDraft('stopped-$i');
        final List<node.WorkflowView> stored = <node.WorkflowView>[];
        final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
        final Future<void> streaming = _streamDraft(
          drafting: drafting,
          draft: draft,
          stored: stored,
        ).forEach(received.add);
        await _waitForProgress(received, random.nextInt(4));

        await drafting.stopDrafting(draft);
        await streaming;

        expect(stored, isEmpty);
        expect(simulated.cancelledRunIds, hasLength(1));
        expect(simulated.cancelledRunIds.single, startsWith('run-of-task-'));
        expect(simulated.deletedTaskIds, hasLength(1));
        expect(
          received.any((WorkflowDraftProgress step) => step.isFinished),
          isFalse,
        );
        final int pollsAfterStop = simulated.draftStatusPollCount;
        await _waitForProgress(received, 0);
        expect(simulated.draftStatusPollCount, pollsAfterStop);
        await expectLater(drafting.stopDrafting(draft), throwsStateError);
      }
    },
  );

  test('test_stop_drafting_property_failed_cancel_keeps_drafting', () async {
    for (int i = 0; i < _draftIterations; i += 1) {
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: _pollsOfAShortDraft,
      );
      simulated.failingCommands.add('cancel_run');
      final NodeWorkflowDrafting drafting = _buildDrafting(simulated);
      final WorkflowDraft draft = _buildDraft('kept-$i');
      final List<node.WorkflowView> stored = <node.WorkflowView>[];
      final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
      final Future<void> streaming = _streamDraft(
        drafting: drafting,
        draft: draft,
        stored: stored,
      ).forEach(received.add);
      await _waitForProgress(received, 1);

      await expectLater(drafting.stopDrafting(draft), throwsStateError);
      await streaming;

      expect(stored, hasLength(1));
      expect(received.last.isFinished, isTrue);
      expect(simulated.cancelledRunIds, isEmpty);
      expect(simulated.deletedTaskIds, isEmpty);
    }
  });

  test('test_stop_drafting_property_fuzz_unknown_drafts_rejected', () async {
    final Random random = seededRandom(9954);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    final NodeWorkflowDrafting drafting = _buildDrafting(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        drafting.stopDrafting(_buildDraft(randomText(random))),
        throwsStateError,
      );
    }
    expect(simulated.cancelledRunIds, isEmpty);
  });

  test('test_redraft_workflow_property_returns_the_done_view', () async {
    final Random random = seededRandom(9952);
    for (int i = 0; i < _draftIterations; i += 1) {
      final int polls = random.nextInt(4);
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: polls,
      );
      final Map<String, Object?> seeded = simulated.addWorkflow(
        name: 'flow',
        state: signedState,
      );
      final String workflowId =
          (seeded['workflow'] as Map<String, Object?>)['id'] as String;

      final node.WorkflowView changed = await _buildDrafting(simulated)
          .redraftWorkflow(
            workspaceId: _workspaceId,
            command: node.ChangeWorkflowCommand(
              workspaceId: _workspaceId,
              workflowId: WorkflowId(workflowId),
              request: 'Add a step',
              agent: node.AgentKind.codex,
            ),
          );

      expect(changed.workflow.id.value, workflowId);
      expect(changed.workflow.agents.length, 2);
      expect(simulated.draftStatusPollCount, polls + 1);
    }
  });
}
