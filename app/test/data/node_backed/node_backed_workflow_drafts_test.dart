import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart' show harnessWorkspaceId;
import 'support/simulated_workflow_node.dart';
import 'support/workflow_repository_harness.dart';

const int _draftIterations = 30;
const int _pollsOfALongDraft = 1000000;

void main() {
  test('test_draft_workflow_property_blank_words_send_nothing', () async {
    final Random random = seededRandom(9904);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String blank = pickOne(random, <String>['', ' ', '\n\t ']);
      await expectLater(
        repository.draftWorkflow(WorkflowDraft(description: blank)),
        emitsError(isArgumentError),
      );
    }
    expect(simulated.draftCommands, isEmpty);
    repository.dispose();
  });

  test('test_draft_workflow_property_sends_only_the_words_here', () async {
    final Random random = seededRandom(9906);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();

    for (int i = 0; i < _draftIterations; i += 1) {
      final String words = 'Ship ${randomWordPhrase(random)}'.trim();
      await repository
          .draftWorkflow(WorkflowDraft(description: '  $words '))
          .last;

      expect(simulated.draftCommands.last, <String, Object?>{
        'command': 'draft_workflow',
        'workspace_id': harnessWorkspaceId.value,
        'description': words,
      });
    }
    expect(simulated.draftCommands.length, _draftIterations);
    expect(repository.listWorkflows().length, _draftIterations);
    repository.dispose();
  });

  test('test_draft_workflow_property_node_failure_reaches_listener', () async {
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 2,
    );
    simulated.failingCommands.add('workflow_draft_status');
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();

    for (int i = 0; i < _draftIterations; i += 1) {
      await expectLater(
        repository.draftWorkflow(const WorkflowDraft(description: 'Do it')),
        emitsError(isA<StateError>()),
      );
      expect(repository.listWorkflows(), isEmpty);
    }
    repository.dispose();
  });

  test('test_stop_drafting_property_repository_cancels_its_draft', () async {
    final Random random = seededRandom(9905);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: _pollsOfALongDraft,
    );
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();

    for (int i = 0; i < _draftIterations; i += 1) {
      final WorkflowDraft draft = WorkflowDraft(description: 'Do it $i');
      final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
      final Future<void> streaming = repository
          .draftWorkflow(draft)
          .forEach(received.add);
      final int waits = 1 + random.nextInt(4);
      for (int wait = 0; wait < waits; wait += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      await repository.stopDrafting(draft);
      await streaming;

      expect(simulated.cancelledRunIds, hasLength(i + 1));
      expect(simulated.deletedTaskIds, hasLength(i + 1));
      expect(repository.listWorkflows(), isEmpty);
      await expectLater(repository.stopDrafting(draft), throwsStateError);
    }
    repository.dispose();
  });
}
