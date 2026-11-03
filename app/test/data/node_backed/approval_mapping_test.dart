import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/arbitrary_json.dart';
import '../../bridge/support/decoding_outcome.dart';
import '../../bridge/support/random_run_json.dart';
import '../../support/random_inputs.dart';

void _expectSameLines(List<DiffLine> lines, List<node.DiffLine> wire) {
  expect(lines.length, wire.length);
  for (int i = 0; i < lines.length; i += 1) {
    expect(lines[i].change.name, wire[i].change.name);
    expect(lines[i].text, wire[i].text);
  }
}

void _expectSamePreview(
  SkillChangePreview? preview,
  node.SkillChangeView? wire,
) {
  if (wire == null) {
    expect(preview, isNull);
    return;
  }
  expect(preview!.skillName, wire.skillName);
  _expectSameLines(preview.lines, wire.changes);
}

void _expectSameAction(
  ApprovalAction action,
  node.ApprovalAction wire,
  node.SkillChangeView? skillChange,
) {
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
    case node.RunCommand():
      final RunCommandAction command = action as RunCommandAction;
      expect(command.tool, wire.tool);
      expect(command.command, wire.command);
    case node.ImproveSkill():
      final ImproveSkillAction improvement = action as ImproveSkillAction;
      expect(improvement.skillId, wire.skillId);
      expect(improvement.summary, wire.summary);
      _expectSamePreview(improvement.preview, skillChange);
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
      final node.SkillChangeView? skillChange = wire is node.ImproveSkill
          ? node.SkillChangeView.fromJson(randomSkillChangeViewJson(random))
          : null;
      final ApprovalAction action = mapApprovalActionFromNode(
        wire,
        skillChange: skillChange,
      );
      _expectSameAction(action, wire, skillChange);
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

  test('test_map_approval_view_from_node_property_pending_iff_open', () {
    final Random random = seededRandom(9703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalView view = node.ApprovalView.fromJson(
        randomApprovalViewJson(random),
      );
      final node.ApprovalRequest wire = view.approval;
      final ApprovalRequest request = mapApprovalViewFromNode(view);

      expect(request.id, wire.id);
      expect(request.runId, wire.runId);
      expect(request.requestedBy, wire.requestedBy);
      expect(request.requestedAt, wire.requestedAt);
      expect(request.isPending, wire.decision == null);
      _expectSameAction(request.action, wire.action, view.skillChange);
    }
  });

  test('test_map_approval_view_from_node_property_gone_skill_no_preview', () {
    final Random random = seededRandom(9705);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomApprovalViewJson(random);
      final Map<String, Object?> approvalJson =
          json['approval']! as Map<String, Object?>;
      approvalJson['action'] = randomImproveSkillJson(random);
      json['skill_change'] = null;

      final ApprovalRequest request = mapApprovalViewFromNode(
        node.ApprovalView.fromJson(json),
      );

      final ImproveSkillAction action = request.action as ImproveSkillAction;
      expect(action.preview, isNull);
    }
  });

  test('test_map_approval_view_from_node_property_malformed_only_format', () {
    final Random random = seededRandom(9704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? mutated = mutateJson(
        random,
        randomApprovalViewJson(random),
      );
      expect(
        attemptDecoding(
          () => mapApprovalViewFromNode(node.ApprovalView.fromJson(mutated)),
        ),
        isIn(DecodingOutcome.values),
      );
    }
  });
}
