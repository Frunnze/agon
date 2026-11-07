import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_work_json.dart';
import '../../support/random_inputs.dart';

const String _changedState = 'changed_not_signed';
const String _signedState = 'signed';
const String _notSignedState = 'not_signed_yet';

Map<String, Object?> _randomConsistentViewJson(Random random) {
  final Map<String, Object?> json = randomWorkflowViewJson(random);
  final Map<String, Object?> workflow =
      json['workflow']! as Map<String, Object?>;
  if (workflow['signature'] == null) {
    json['signature_state'] = _notSignedState;
  } else if (json['signature_state'] == _notSignedState) {
    json['signature_state'] = _signedState;
  }
  if (workflow['signature'] != null) {
    json['signed_at'] = randomMomentText(random);
  }
  if (json['signature_state'] == _changedState) {
    json['changed_at'] = randomMomentText(random);
    json['changed_by'] = randomDeviceIdText(random);
  }
  return json;
}

node.WorkflowView _randomWorkflowView(Random random) {
  return node.WorkflowView.fromJson(_randomConsistentViewJson(random));
}

List<String> _readLines(String document) {
  final List<String> lines = document.split('\n');
  if (lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

void main() {
  test('test_map_canvas_position_to_node_property_round_trips', () {
    final Random random = seededRandom(9303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.CanvasPosition wire = node.CanvasPosition.fromJson(
        randomCanvasPositionJson(random),
      );
      final CanvasPosition position = mapCanvasPositionFromNode(wire);
      expect(mapCanvasPositionToNode(position).toJson(), wire.toJson());
    }
  });

  test('test_map_canvas_position_from_node_property_keeps_point', () {
    final Random random = seededRandom(9304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.CanvasPosition wire = node.CanvasPosition.fromJson(
        randomCanvasPositionJson(random),
      );
      final CanvasPosition position = mapCanvasPositionFromNode(wire);
      expect(position.horizontal, wire.horizontal);
      expect(position.vertical, wire.vertical);
    }
  });

  test('test_map_workflow_agent_to_node_property_round_trips', () {
    final Random random = seededRandom(9305);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowAgent wire = node.WorkflowAgent.fromJson(
        randomWorkflowAgentJson(random),
      );
      final WorkflowAgent agent = mapWorkflowAgentFromNode(wire);
      expect(mapWorkflowAgentToNode(agent).toJson(), wire.toJson());
    }
  });

  test('test_map_workflow_agent_from_node_property_keeps_task', () {
    final Random random = seededRandom(9306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowAgent wire = node.WorkflowAgent.fromJson(
        randomWorkflowAgentJson(random),
      );
      final WorkflowAgent agent = mapWorkflowAgentFromNode(wire);
      expect(agent.id, wire.id);
      expect(agent.task, wire.task);
      expect(agent.skills, wire.skills);
    }
  });

  test('test_map_agent_connection_to_node_property_round_trips', () {
    final Random random = seededRandom(9307);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentConnection wire = node.AgentConnection.fromJson(
        randomAgentConnectionJson(random),
      );
      final AgentConnection connection = mapAgentConnectionFromNode(wire);
      expect(mapAgentConnectionToNode(connection).toJson(), wire.toJson());
    }
  });

  test('test_map_agent_connection_from_node_property_keeps_ends', () {
    final Random random = seededRandom(9308);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentConnection wire = node.AgentConnection.fromJson(
        randomAgentConnectionJson(random),
      );
      final AgentConnection connection = mapAgentConnectionFromNode(wire);
      expect(connection.from, wire.from);
      expect(connection.to, wire.to);
    }
  });

  test('test_map_workflow_to_node_property_round_trips_unsigned', () {
    final Random random = seededRandom(9309);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomWorkflowView(random);
      final Workflow workflow = mapWorkflowFromNode(view);
      final Map<String, Object?> expected = <String, Object?>{
        ...view.workflow.toJson(),
        'signature': null,
      };
      expect(mapWorkflowToNode(workflow).toJson(), expected);
    }
  });

  test('test_map_workflow_from_node_property_signature_is_opened', () {
    final Random random = seededRandom(9310);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomWorkflowView(random);
      final WorkflowSignature? signature = mapWorkflowFromNode(view).signature;
      final node.WorkflowSignature? wireSignature = view.workflow.signature;
      expect(signature == null, wireSignature == null);
      if (signature != null && wireSignature != null) {
        expect(signature.signedBy, wireSignature.signedBy);
        expect(signature.signature, wireSignature.signature);
        expect(signature.signedDocument, readSignedDocument(view));
        expect(signature.signedAt, view.signedAt);
      }
    }
  });

  test('test_map_workflow_from_node_property_unknown_sign_moment_is_kept', () {
    final Random random = seededRandom(9315);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = _randomConsistentViewJson(random);
      json['signed_at'] = null;
      json['changed_at'] = null;
      final node.WorkflowView view = node.WorkflowView.fromJson(json);
      final bool isSigned = view.workflow.signature != null;
      final WorkflowSignature? signature = mapWorkflowFromNode(view).signature;

      expect(signature == null, !isSigned);
      expect(signature?.signedAt, isNull);
      final WorkflowChange? change = mapPendingChangeFromNode(view);
      final bool isChanged =
          view.signatureState == node.SignatureState.changedNotSigned;
      expect(change != null, isChanged);
      expect(change?.changedAt, isNull);
    }
  });

  test('test_read_signed_document_property_drops_only_added_lines', () {
    final Random random = seededRandom(9311);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomWorkflowView(random);
      final String signedDocument = readSignedDocument(view);
      if (view.changes.isEmpty) {
        expect(signedDocument, view.document);
        continue;
      }
      final List<String> keptLines = <String>[
        for (final node.DiffLine line in view.changes)
          if (line.change != node.DiffLineChange.added) line.text,
      ];
      expect(signedDocument.split('\n'), <String>[...keptLines, '']);
    }
  });

  test('test_map_pending_change_from_node_property_only_when_changed', () {
    final Random random = seededRandom(9312);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomWorkflowView(random);
      final WorkflowChange? change = mapPendingChangeFromNode(view);
      final bool isChanged =
          view.signatureState == node.SignatureState.changedNotSigned &&
          view.workflow.signature != null;
      expect(change != null, isChanged);
      if (change != null) {
        expect(change.workflowId, view.workflow.id);
        expect(change.changedDocument, view.document);
        expect(change.changedAt, view.changedAt);
        expect(change.changedBy, view.changedBy);
        expect(change.signedDocument, readSignedDocument(view));
      }
    }
  });

  test('test_list_document_differences_property_one_per_changed_line', () {
    final Random random = seededRandom(9313);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = _randomWorkflowView(random).changes;
      final int changedCount = lines
          .where(
            (node.DiffLine line) =>
                line.change != node.DiffLineChange.unchanged,
          )
          .length;
      expect(listDocumentDifferences(lines).length, changedCount);
    }
  });

  test('test_summarize_document_changes_property_counts_both_sides', () {
    final Random random = seededRandom(9314);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DiffLine> lines = _randomWorkflowView(random).changes;
      int added = 0;
      int removed = 0;
      for (final node.DiffLine line in lines) {
        if (line.change == node.DiffLineChange.added) {
          added += 1;
        }
        if (line.change == node.DiffLineChange.removed) {
          removed += 1;
        }
      }
      expect(
        summarizeDocumentChanges(lines),
        'Lines added: $added, removed: $removed',
      );
    }
  });

  test('test_read_signed_document_property_line_count_matches_diff', () {
    final Random random = seededRandom(9315);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = _randomWorkflowView(random);
      if (view.changes.isEmpty) {
        continue;
      }
      final int addedCount = view.changes
          .where(
            (node.DiffLine line) => line.change == node.DiffLineChange.added,
          )
          .length;
      expect(
        _readLines(readSignedDocument(view)).length,
        view.changes.length - addedCount,
      );
    }
  });
}
