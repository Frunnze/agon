import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/domain_model_properties.dart';
import 'support/random_run_records.dart';

PendingAgent _randomPendingAgent(Random random) {
  return PendingAgent(
    name: randomHostileText(random),
    position: randomCanvasPosition(random),
  );
}

WorkflowDraftProgress _buildProgress(
  Random random,
  List<PendingAgent> pendingAgents,
) {
  return WorkflowDraftProgress(
    workflow: randomAcyclicWorkflow(random),
    pendingAgents: pendingAgents,
    drafterKind: pickOne(random, AgentKind.values),
    drafterDeviceId: randomDeviceId(random),
  );
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<WorkflowDraft>(
      testNamePrefix: 'test_workflow_draft_constructor_property',
      seed: 704101,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          WorkflowDraft(description: fieldValues[0]! as String),
      readFieldValues: (WorkflowDraft draft) => <Object?>[draft.description],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<PendingAgent>(
      testNamePrefix: 'test_pending_agent_constructor_property',
      seed: 704111,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomCanvasPosition(random),
      ],
      construct: (ModelFieldValues fieldValues) => PendingAgent(
        name: fieldValues[0]! as String,
        position: fieldValues[1]! as CanvasPosition,
      ),
      readFieldValues: (PendingAgent agent) => <Object?>[
        agent.name,
        agent.position,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<WorkflowDraftProgress>(
      testNamePrefix: 'test_workflow_draft_progress_constructor_property',
      seed: 704121,
      randomFieldValues: (Random random) => <Object?>[
        randomAcyclicWorkflow(random),
        randomRecordsOf(random, _randomPendingAgent),
        pickOne(random, AgentKind.values),
        randomDeviceId(random),
      ],
      construct: (ModelFieldValues fieldValues) => WorkflowDraftProgress(
        workflow: fieldValues[0]! as Workflow,
        pendingAgents: fieldValues[1]! as List<PendingAgent>,
        drafterKind: fieldValues[2]! as AgentKind,
        drafterDeviceId: fieldValues[3]! as DeviceId,
      ),
      readFieldValues: (WorkflowDraftProgress progress) => <Object?>[
        progress.workflow,
        progress.pendingAgents,
        progress.drafterKind,
        progress.drafterDeviceId,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<WorkflowDraftProgress, PendingAgent>(
      testNamePrefix:
          'test_workflow_draft_progress_constructor_property_'
          'pending_agents',
      seed: 704131,
      buildElement: _randomPendingAgent,
      construct: _buildProgress,
      readList: (WorkflowDraftProgress progress) => progress.pendingAgents,
    ),
  );

  test('test_is_finished_property_only_without_pending_agents', () {
    final Random random = seededRandom(704141);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PendingAgent> pendingAgents = randomRecordsOf(
        random,
        _randomPendingAgent,
      );

      final WorkflowDraftProgress progress = _buildProgress(
        random,
        pendingAgents,
      );

      expect(progress.isFinished, pendingAgents.isEmpty);
    }
  });

  test('test_is_finished_property_ignores_the_workflow_and_drafter', () {
    final Random random = seededRandom(704151);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PendingAgent> pendingAgents = randomRecordsOf(
        random,
        _randomPendingAgent,
      );

      final WorkflowDraftProgress first = _buildProgress(
        random,
        pendingAgents,
      );
      final WorkflowDraftProgress second = _buildProgress(
        random,
        pendingAgents,
      );

      expect(first.isFinished, second.isFinished);
    }
  });

  test('test_is_finished_property_ignores_later_caller_changes', () {
    final Random random = seededRandom(704161);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PendingAgent> pendingAgents = randomRecordsOf(
        random,
        _randomPendingAgent,
      );
      final bool wasFinished = pendingAgents.isEmpty;
      final WorkflowDraftProgress progress = _buildProgress(
        random,
        pendingAgents,
      );

      if (wasFinished) {
        pendingAgents.add(_randomPendingAgent(random));
      } else {
        pendingAgents.clear();
      }

      expect(progress.isFinished, wasFinished);
    }
  });
}
