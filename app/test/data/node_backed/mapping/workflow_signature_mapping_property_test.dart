import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_work_json.dart';
import '../../../support/random_inputs.dart';
import 'support/workflow_view_values.dart';

const List<node.SignatureState> _signedStates = <node.SignatureState>[
  node.SignatureState.signed,
  node.SignatureState.changedNotSigned,
];

Map<String, Object?> _replaceSignature(
  Map<String, Object?> viewJson,
  Map<String, Object?>? signatureJson,
) {
  final Map<String, Object?> workflow =
      viewJson['workflow']! as Map<String, Object?>;
  return <String, Object?>{
    ...viewJson,
    'workflow': <String, Object?>{...workflow, 'signature': signatureJson},
  };
}

Map<String, Object?> _randomImpossibleViewJson(Random random) {
  final node.SignatureState state = pickOne(
    random,
    node.SignatureState.values,
  );
  final Map<String, Object?> json = buildNodeRuleViewJson(random, state);
  if (state == node.SignatureState.notSignedYet) {
    return _replaceSignature(json, randomWorkflowSignatureJson(random));
  }
  return _replaceSignature(json, null);
}

void main() {
  test('test_map_signature_from_node_property_keeps_signer_and_moment', () {
    final Random random = seededRandom(74301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SignatureState state = pickOne(random, _signedStates);
      final node.WorkflowView view = node.WorkflowView.fromJson(
        buildNodeRuleViewJson(random, state),
      );
      final node.WorkflowSignature wire = view.workflow.signature!;
      final WorkflowSignature signature = mapWorkflowFromNode(view).signature!;

      expect(signature.signedBy, wire.signedBy);
      expect(signature.signature, wire.signature);
      expect(signature.signedAt, view.signedAt);
      expect(signature.signedDocument, expectSignedDocument(view));
      expect(() => signature.signature.add(0), throwsUnsupportedError);
    }
  });

  test('test_map_signature_from_node_property_follows_the_node_state', () {
    final Random random = seededRandom(74302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = randomNodeRuleView(random);
      final WorkflowSignature? signature = mapWorkflowFromNode(view).signature;
      final bool isNotSignedYet =
          view.signatureState == node.SignatureState.notSignedYet;

      expect(signature == null, isNotSignedYet);
    }
  });

  test('test_map_signature_from_node_property_rejects_impossible_states', () {
    final Random random = seededRandom(74303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = node.WorkflowView.fromJson(
        _randomImpossibleViewJson(random),
      );

      expect(() => mapWorkflowFromNode(view), throwsFormatException);
    }
  });

  test('test_map_signature_from_node_property_unknown_moment_is_unknown', () {
    final Random random = seededRandom(74304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SignatureState state = pickOne(random, _signedStates);
      final Map<String, Object?> json = buildNodeRuleViewJson(random, state);
      json['signed_at'] = null;
      final node.WorkflowView view = node.WorkflowView.fromJson(json);

      final WorkflowSignature? signature = mapWorkflowFromNode(view).signature;

      expect(signature?.signedBy, view.workflow.signature?.signedBy);
      expect(signature?.signedAt, isNull);
    }
  });

  test('test_check_signature_matches_state_property_accepts_node_views', () {
    final Random random = seededRandom(74305);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = randomNodeRuleView(random);

      expect(() => checkSignatureMatchesState(view), returnsNormally);
    }
  });

  test('test_check_signature_matches_state_property_rejects_mismatches', () {
    final Random random = seededRandom(74306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = node.WorkflowView.fromJson(
        _randomImpossibleViewJson(random),
      );

      expect(() => checkSignatureMatchesState(view), throwsFormatException);
      expect(() => mapPendingChangeFromNode(view), throwsFormatException);
    }
  });

  test('test_check_signature_matches_state_property_ignores_the_diff', () {
    final Random random = seededRandom(74307);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkflowView view = randomNodeRuleView(random);
      final node.WorkflowView rediffed = replaceViewChanges(
        view,
        randomNodeDiffLines(random, leastCount: 0),
      );

      expect(() => checkSignatureMatchesState(rediffed), returnsNormally);
    }
  });
}
