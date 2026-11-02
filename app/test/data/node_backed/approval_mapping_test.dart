import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/arbitrary_json.dart';
import '../../bridge/support/decoding_outcome.dart';
import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';

void _expectSameAction(ApprovalAction action, node.ApprovalAction wire) {
  switch (wire) {
    case node.PushCommits():
      final PushCommitsAction push = action as PushCommitsAction;
      expect(push.repository, wire.repository);
      expect(push.branch, wire.branch);
      expect(push.commits, wire.commits);
    case node.Deploy():
      expect((action as DeployAction).target, wire.target);
    case node.DeleteBranchOrFiles():
      final DeleteBranchOrFilesAction deletion =
          action as DeleteBranchOrFilesAction;
      expect(deletion.repository, wire.repository);
      expect(deletion.what, wire.what);
    case node.SignWorkflow():
      expect((action as SignWorkflowAction).workflowId, wire.workflowId);
  }
}

void main() {
  test('test_map_approval_decision_to_node_property_round_trips', () {
    for (final node.ApprovalDecision wire in node.ApprovalDecision.values) {
      final ApprovalDecision decision = mapApprovalDecisionFromNode(wire);
      expect(mapApprovalDecisionToNode(decision), wire);
      expect(decision.name, wire.name);
    }
  });

  test('test_map_approval_action_from_node_property_keeps_fields', () {
    final Random random = seededRandom(9701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalAction wire = node.ApprovalAction.fromJson(
        randomApprovalActionJson(random),
      );
      _expectSameAction(mapApprovalActionFromNode(wire), wire);
    }
  });

  test('test_map_signed_decision_from_node_property_keeps_fields', () {
    final Random random = seededRandom(9702);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SignedDecision wire = node.SignedDecision.fromJson(
        randomSignedDecisionJson(random),
      );
      final SignedDecision decision = mapSignedDecisionFromNode(wire);

      expect(decision.decision.name, wire.decision.name);
      expect(decision.decidedBy, wire.decidedBy);
      expect(decision.decidedAt, wire.decidedAt);
      expect(decision.signature, wire.signature);
    }
  });

  test('test_map_approval_request_from_node_property_pending_iff_open', () {
    final Random random = seededRandom(9703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalRequest wire = node.ApprovalRequest.fromJson(
        randomApprovalRequestJson(random),
      );
      final ApprovalRequest request = mapApprovalRequestFromNode(wire);

      expect(request.id, wire.id);
      expect(request.runId, wire.runId);
      expect(request.requestedBy, wire.requestedBy);
      expect(request.requestedAt, wire.requestedAt);
      expect(request.isPending, wire.decision == null);
      _expectSameAction(request.action, wire.action);
    }
  });

  test(
    'test_map_approval_request_from_node_property_malformed_only_format',
    () {
      final Random random = seededRandom(9704);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? mutated = mutateJson(
          random,
          randomApprovalRequestJson(random),
        );
        expect(
          attemptDecoding(
            () => mapApprovalRequestFromNode(
              node.ApprovalRequest.fromJson(mutated),
            ),
          ),
          isIn(DecodingOutcome.values),
        );
      }
    },
  );
}
