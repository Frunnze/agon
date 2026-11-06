import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder/builder_cancellation.dart';

import '../../data/node_backed/support/simulated_workflow_node.dart';
import '../../data/node_backed/support/workflow_repository_harness.dart';
import '../../support/random_inputs.dart';

const int _cancellationIterations = 20;
const int _mostEdits = 4;

final class _OpenedWorkflow {
  const _OpenedWorkflow({
    required this.repository,
    required this.openedVersion,
    required this.openedChange,
  });

  final NodeBackedWorkflowRepository repository;
  final Workflow openedVersion;
  final WorkflowChange? openedChange;

  WorkflowId get workflowId => openedVersion.id;
}

Future<_OpenedWorkflow> _openWorkflow(String state) async {
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: 1,
  );
  simulated.addWorkflow(name: 'flow', state: state);
  final NodeBackedWorkflowRepository repository =
      buildSimulatedWorkflowRepository(simulated);
  await repository.load();
  final WorkflowId workflowId = repository.listWorkflows().single.id;
  return _OpenedWorkflow(
    repository: repository,
    openedVersion: repository.findWorkflow(workflowId),
    openedChange: repository.findPendingChange(workflowId),
  );
}

Future<void> _editRandomly(Random random, _OpenedWorkflow opened) async {
  final int editCount = 1 + random.nextInt(_mostEdits);
  for (int i = 0; i < editCount; i += 1) {
    final Workflow current = opened.repository.findWorkflow(opened.workflowId);
    await opened.repository.saveWorkflow(
      addAgent(current, buildBlankAgent(current)),
    );
  }
}

Future<void> _restore(_OpenedWorkflow opened) {
  return restoreOpenedWorkflow(
    workflowRepository: opened.repository,
    openedVersion: opened.openedVersion,
    openedChange: opened.openedChange,
  );
}

void main() {
  test('test_restore_opened_workflow_property_edits_leave_no_change', () async {
    final Random random = seededRandom(7401);

    for (int i = 0; i < _cancellationIterations; i += 1) {
      final _OpenedWorkflow opened = await _openWorkflow(signedState);
      await _editRandomly(random, opened);
      expect(opened.repository.findPendingChange(opened.workflowId), isNotNull);

      await _restore(opened);

      final Workflow restored = opened.repository.findWorkflow(
        opened.workflowId,
      );
      expect(opened.repository.findPendingChange(opened.workflowId), isNull);
      expect(hasSameDesign(restored, opened.openedVersion), isTrue);
      expect(restored.signature, isNotNull);
      opened.repository.dispose();
    }
  });

  test('test_restore_opened_workflow_property_no_edit_saves_nothing', () async {
    for (final String state in <String>[signedState, changedState]) {
      for (int i = 0; i < _cancellationIterations; i += 1) {
        final _OpenedWorkflow opened = await _openWorkflow(state);
        int notifications = 0;
        opened.repository.addListener(() => notifications += 1);

        await _restore(opened);

        expect(notifications, 0, reason: state);
        expect(
          opened.repository.findWorkflow(opened.workflowId),
          same(opened.openedVersion),
        );
        opened.repository.dispose();
      }
    }
  });

  test('test_restore_opened_workflow_property_keeps_earlier_change', () async {
    final Random random = seededRandom(7403);

    for (int i = 0; i < _cancellationIterations; i += 1) {
      final _OpenedWorkflow opened = await _openWorkflow(changedState);
      expect(opened.openedChange, isNotNull);
      await _editRandomly(random, opened);

      await _restore(opened);

      final Workflow restored = opened.repository.findWorkflow(
        opened.workflowId,
      );
      expect(opened.repository.findPendingChange(opened.workflowId), isNotNull);
      expect(hasSameDesign(restored, opened.openedVersion), isTrue);
      opened.repository.dispose();
    }
  });

  test('test_restore_opened_workflow_property_unsigned_goes_back', () async {
    final Random random = seededRandom(7404);

    for (int i = 0; i < _cancellationIterations; i += 1) {
      final _OpenedWorkflow opened = await _openWorkflow(unsignedState);
      await _editRandomly(random, opened);

      await _restore(opened);

      final Workflow restored = opened.repository.findWorkflow(
        opened.workflowId,
      );
      expect(hasSameDesign(restored, opened.openedVersion), isTrue);
      expect(restored.signature, isNull);
      opened.repository.dispose();
    }
  });
}
