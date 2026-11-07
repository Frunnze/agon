import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestByte = 256;

SignedDecision _randomSignedDecision(Random random) {
  return SignedDecision(
    decision: pickOne(random, ApprovalDecision.values),
    decidedBy: randomDeviceId(random),
    decidedAt: randomPreciseMoment(random),
    signature: randomBytes(random),
  );
}

ApprovalAction _randomAction(Random random) {
  return pickOne<ApprovalAction>(random, <ApprovalAction>[
    DeployAction(target: randomHostileText(random)),
    RunCommandAction(
      tool: randomHostileText(random),
      summary: randomHostileText(random),
      command: randomHostileText(random),
    ),
    PushCommitsAction(
      repository: randomHostileText(random),
      branch: randomHostileText(random),
      commits: randomHostileTexts(random),
    ),
  ]);
}

ModelFieldValues _randomRequestFields(Random random) {
  return <Object?>[
    ApprovalId(randomUuidText(random)),
    if (random.nextBool()) null else randomRunId(random),
    _randomAction(random),
    randomDeviceId(random),
    randomPreciseMoment(random),
    if (random.nextBool()) null else _randomSignedDecision(random),
  ];
}

ApprovalRequest _buildRequest(ModelFieldValues fieldValues) {
  return ApprovalRequest(
    id: fieldValues[0]! as ApprovalId,
    runId: fieldValues[1] as RunId?,
    action: fieldValues[2]! as ApprovalAction,
    requestedBy: fieldValues[3]! as DeviceId,
    requestedAt: fieldValues[4]! as DateTime,
    decision: fieldValues[5] as SignedDecision?,
  );
}

ApprovalRequest _randomRequest(Random random) {
  return _buildRequest(_randomRequestFields(random));
}

ModelFieldValues _readRequestFieldsBesidesDecision(ApprovalRequest request) {
  return <Object?>[
    request.id,
    request.runId,
    request.action,
    request.requestedBy,
    request.requestedAt,
  ];
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<SignedDecision>(
      testNamePrefix: 'test_signed_decision_constructor_property',
      seed: 690401,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, ApprovalDecision.values),
        randomDeviceId(random),
        randomPreciseMoment(random),
        randomBytes(random),
      ],
      construct: (ModelFieldValues fieldValues) => SignedDecision(
        decision: fieldValues[0]! as ApprovalDecision,
        decidedBy: fieldValues[1]! as DeviceId,
        decidedAt: fieldValues[2]! as DateTime,
        signature: fieldValues[3]! as List<int>,
      ),
      readFieldValues: (SignedDecision decision) => <Object?>[
        decision.decision,
        decision.decidedBy,
        decision.decidedAt,
        decision.signature,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<SignedDecision, int>(
      testNamePrefix: 'test_signed_decision_constructor_property_signature',
      seed: 690411,
      buildElement: (Random random) => random.nextInt(_largestByte),
      construct: (Random random, List<int> signature) => SignedDecision(
        decision: pickOne(random, ApprovalDecision.values),
        decidedBy: randomDeviceId(random),
        decidedAt: randomPreciseMoment(random),
        signature: signature,
      ),
      readList: (SignedDecision decision) => decision.signature,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ApprovalRequest>(
      testNamePrefix: 'test_approval_request_constructor_property',
      seed: 690421,
      randomFieldValues: _randomRequestFields,
      construct: _buildRequest,
      readFieldValues: (ApprovalRequest request) => <Object?>[
        ..._readRequestFieldsBesidesDecision(request),
        request.decision,
      ],
    ),
  );

  testModelCopyProperties(
    ModelCopy<ApprovalRequest, SignedDecision>(
      testNamePrefix: 'test_with_decision_property',
      seed: 690431,
      randomModel: _randomRequest,
      randomChange: _randomSignedDecision,
      applyChange: (ApprovalRequest request, SignedDecision decision) =>
          request.withDecision(decision),
      readChangedField: (ApprovalRequest request) => request.decision,
      readOtherFields: _readRequestFieldsBesidesDecision,
    ),
  );

  test('test_is_pending_property_true_exactly_without_a_decision', () {
    final Random random = seededRandom(690441);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest request = _randomRequest(random);

      expect(request.isPending, request.decision == null);
    }
  });

  test('test_is_pending_property_false_after_any_decision', () {
    final Random random = seededRandom(690442);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest request = _randomRequest(random);

      final ApprovalRequest decided = request.withDecision(
        _randomSignedDecision(random),
      );

      expect(decided.isPending, isFalse);
    }
  });

  test('test_is_pending_property_denied_counts_as_decided', () {
    final Random random = seededRandom(690443);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SignedDecision denial = SignedDecision(
        decision: ApprovalDecision.denied,
        decidedBy: randomDeviceId(random),
        decidedAt: randomPreciseMoment(random),
        signature: const <int>[],
      );

      final ApprovalRequest denied = ApprovalRequest(
        id: ApprovalId(randomUuidText(random)),
        runId: null,
        action: _randomAction(random),
        requestedBy: randomDeviceId(random),
        requestedAt: randomPreciseMoment(random),
        decision: denial,
      );

      expect(denied.isPending, isFalse);
    }
  });

  const NodeEnumMapping<ApprovalPolicy, node.ApprovalPolicy> policyMapping =
      NodeEnumMapping<ApprovalPolicy, node.ApprovalPolicy>(
        testNamePrefix: 'test_approval_policy_values_property',
        choices: ApprovalPolicy.values,
        nodeChoices: node.ApprovalPolicy.values,
        mapFromNode: mapApprovalPolicyFromNode,
      );
  testNodeEnumMappingProperties(policyMapping);
  testNodeEnumRoundTripProperty(policyMapping, mapApprovalPolicyToNode);

  const NodeEnumMapping<ApprovalDecision, node.ApprovalDecision>
  decisionMapping = NodeEnumMapping<ApprovalDecision, node.ApprovalDecision>(
    testNamePrefix: 'test_approval_decision_values_property',
    choices: ApprovalDecision.values,
    nodeChoices: node.ApprovalDecision.values,
    mapFromNode: mapApprovalDecisionFromNode,
  );
  testNodeEnumMappingProperties(decisionMapping);
  testNodeEnumRoundTripProperty(decisionMapping, mapApprovalDecisionToNode);
}
