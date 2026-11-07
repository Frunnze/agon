import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../support/node_enum_mapping_properties.dart';

node.SignedDecision _decodeRandomDecision(Random random) {
  return node.SignedDecision.fromJson(randomSignedDecisionJson(random));
}

node.ApprovalView _decodeRandomView(Random random) {
  return node.ApprovalView.fromJson(randomApprovalViewJson(random));
}

void main() {
  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.ApprovalDecision, ApprovalDecision>(
      functionName: 'map_approval_decision_from_node',
      seed: 71601,
      rustWireNames: nodeApprovalDecisions,
      decodeNode: node.ApprovalDecision.decode,
      modelValues: ApprovalDecision.values,
      mapFromNode: mapApprovalDecisionFromNode,
    ),
  );

  testEnumMappingToNodeProperties(
    const EnumMappingToNode<node.ApprovalDecision, ApprovalDecision>(
      functionName: 'map_approval_decision_to_node',
      rustWireNames: nodeApprovalDecisions,
      nodeValues: node.ApprovalDecision.values,
      modelValues: ApprovalDecision.values,
      mapToNode: mapApprovalDecisionToNode,
      mapFromNode: mapApprovalDecisionFromNode,
    ),
  );

  test('test_map_signed_decision_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(71603);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SignedDecision wire = _decodeRandomDecision(random);

      final SignedDecision decision = mapSignedDecisionFromNode(wire);

      expect(decision.decision.name, wire.decision.name);
      expect(decision.decidedBy, wire.decidedBy);
      expect(decision.decidedAt, wire.decidedAt);
      expect(decision.signature, orderedEquals(wire.signature));
    }
  });

  test('test_map_signed_decision_from_node_property_'
      'keeps_the_instant_of_offsets', () {
    final Random random = seededRandom(71604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> decisionJson = randomSignedDecisionJson(
        random,
      );
      final DateTime decidedAt = randomPreciseMoment(random);
      decisionJson['decided_at'] = writeMomentWithRandomOffset(
        random,
        decidedAt,
      );

      final SignedDecision decision = mapSignedDecisionFromNode(
        node.SignedDecision.fromJson(decisionJson),
      );

      expect(decision.decidedAt.isAtSameMomentAs(decidedAt), isTrue);
    }
  });

  test('test_map_signed_decision_from_node_property_'
      'signature_cannot_be_changed', () {
    final Random random = seededRandom(71605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final SignedDecision decision = mapSignedDecisionFromNode(
        _decodeRandomDecision(random),
      );

      expect(() => decision.signature.add(0), throwsUnsupportedError);
    }
  });

  test('test_map_approval_view_from_node_property_keeps_the_request', () {
    final Random random = seededRandom(71606);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalView view = _decodeRandomView(random);
      final node.ApprovalRequest wire = view.approval;

      final ApprovalRequest request = mapApprovalViewFromNode(view);

      expect(request.id, wire.id);
      expect(request.runId, wire.runId);
      expect(request.requestedBy, wire.requestedBy);
      expect(request.requestedAt, wire.requestedAt);
    }
  });

  test('test_map_approval_view_from_node_property_'
      'pending_exactly_without_a_decision', () {
    final Random random = seededRandom(71607);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalView view = _decodeRandomView(random);
      final node.SignedDecision? wireDecision = view.approval.decision;

      final ApprovalRequest request = mapApprovalViewFromNode(view);

      expect(request.isPending, wireDecision == null);
      expect(request.decision?.decidedBy, wireDecision?.decidedBy);
      expect(request.decision?.decision.name, wireDecision?.decision.name);
    }
  });

  test('test_map_approval_view_from_node_property_'
      'preview_only_for_improve_skill_with_a_change', () {
    final Random random = seededRandom(71608);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalView view = _decodeRandomView(random);

      final ApprovalAction action = mapApprovalViewFromNode(view).action;

      final bool isImproveSkill = view.approval.action is node.ImproveSkill;
      expect(action is ImproveSkillAction, isImproveSkill);
      if (action is ImproveSkillAction) {
        expect(action.preview == null, view.skillChange == null);
        expect(action.preview?.skillName, view.skillChange?.skillName);
      }
    }
  });
}
