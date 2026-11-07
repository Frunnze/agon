import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import '../support/simulated_workflow_node.dart';
import '../support/workflow_repository_harness.dart';
import 'support/workflow_view_values.dart';

const List<String> _fieldsOldRecordsLack = <String>[
  'signed_at',
  'changed_at',
  'changed_by',
  'changed_by_name',
];
const List<String> _simulatedStates = <String>[
  signedState,
  changedState,
  unsignedState,
];
const int _largestWorkflowCount = 6;
const int _repositoryIterations = 40;

Map<String, Object?> _forgetFieldsLikeOldState(
  Random random,
  Map<String, Object?> viewJson,
) {
  final Map<String, Object?> oldViewJson = <String, Object?>{...viewJson};
  for (final String field in _fieldsOldRecordsLack) {
    if (random.nextBool()) {
      continue;
    }
    if (random.nextBool()) {
      oldViewJson[field] = null;
    } else {
      oldViewJson.remove(field);
    }
  }
  return oldViewJson;
}

node.WorkflowView _randomOldRecordView(
  Random random,
  node.SignatureState state,
) {
  final Map<String, Object?> viewJson = buildNodeRuleViewJson(random, state);
  return node.WorkflowView.fromJson(
    _forgetFieldsLikeOldState(random, viewJson),
  );
}

void main() {
  test('test_map_workflow_from_node_property_accepts_old_records', () {
    final Random random = seededRandom(75101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SignatureState state = pickOne(
        random,
        node.SignatureState.values,
      );
      final node.WorkflowView view = _randomOldRecordView(random, state);

      final Workflow workflow = mapWorkflowFromNode(view);

      final WorkflowSignature? signature = workflow.signature;
      expect(signature == null, state == node.SignatureState.notSignedYet);
      expect(signature?.signedAt, view.signedAt);
      expect(signature?.signedBy, view.workflow.signature?.signedBy);
      expect(workflow.id, view.workflow.id);
    }
  });

  test('test_map_pending_change_from_node_property_old_change_is_unknown', () {
    final Random random = seededRandom(75102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomOldRecordView(
        random,
        node.SignatureState.changedNotSigned,
      );

      final WorkflowChange? change = mapPendingChangeFromNode(view);

      expect(change, isNotNull);
      expect(change?.changedAt, view.changedAt);
      expect(change?.changedBy, view.changedBy);
      expect(change?.changedDocument, view.document);
      expect(change?.signedDocument, expectSignedDocument(view));
    }
  });

  test('test_node_backed_workflow_repository_load_property_old_records_'
      'never_break_the_list', () async {
    final Random random = seededRandom(75103);
    for (int i = 0; i < _repositoryIterations; i += 1) {
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: 0,
      );
      final int workflowCount = 1 + random.nextInt(_largestWorkflowCount);
      for (int index = 0; index < workflowCount; index += 1) {
        final Map<String, Object?> view = simulated.addWorkflow(
          name: 'workflow $index ${randomText(random)}',
          state: pickOne(random, _simulatedStates),
        );
        final Map<String, Object?> oldView = _forgetFieldsLikeOldState(
          random,
          view,
        );
        simulated.views[index] = oldView;
      }
      final NodeBackedWorkflowRepository repository =
          buildSimulatedWorkflowRepository(simulated);

      await repository.load();

      final List<Workflow> workflows = repository.listWorkflows();
      expect(workflows.length, workflowCount);
      for (int index = 0; index < workflowCount; index += 1) {
        final Map<String, Object?> view = simulated.views[index];
        final bool isChanged = view['signature_state'] == changedState;
        final WorkflowChange? change = repository.findPendingChange(
          workflows[index].id,
        );
        expect(change != null, isChanged);
      }
      repository.dispose();
    }
  });
}
