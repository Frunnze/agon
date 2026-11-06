import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/approval_wire_codecs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_run_json.dart';
import '../support/random_typed_values.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_properties.dart';

const int _byteValueCount = 256;

const List<String> _actionKinds = <String>[
  PushCommits.kind,
  Deploy.kind,
  DeleteBranchOrFiles.kind,
  SignWorkflow.kind,
  RunCommand.kind,
  ImproveSkill.kind,
];

void main() {
  testWireNameDecodeProperties(
    const WireNameCodec<ApprovalPolicy>(
      typeName: 'approval_policy',
      seed: 49300,
      choices: ApprovalPolicy.values,
      decode: ApprovalPolicy.decode,
      nodeNames: nodeApprovalPolicies,
    ),
  );
  testWireNameDecodeProperties(
    const WireNameCodec<ApprovalDecision>(
      typeName: 'approval_decision',
      seed: 49302,
      choices: ApprovalDecision.values,
      decode: ApprovalDecision.decode,
      nodeNames: nodeApprovalDecisions,
    ),
  );

  for (final WireCodec codec in approvalRecordCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  for (final WireCodec codec in approvalActionCodecs) {
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<PushCommits, String>(
      testNamePrefix: 'test_push_commits_constructor_property_commits',
      seed: 49310,
      buildElement: randomText,
      construct: _buildPushCommits,
      readList: _readCommits,
    ),
  );

  testListCopyProperties(
    const ListCopy<SignedDecision, int>(
      testNamePrefix: 'test_signed_decision_constructor_property_signature',
      seed: 49320,
      buildElement: _buildByte,
      construct: _buildSignedDecision,
      readList: _readSignature,
    ),
  );

  test('test_approval_action_from_json_property_kind_picks_the_type', () {
    final Random random = seededRandom(49330);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomApprovalActionJson(random);

      final ApprovalAction action = ApprovalAction.fromJson(wireJson);

      expect(_readActionKind(action), wireJson['kind']);
    }
  });

  test('test_approval_action_from_json_property_rejects_unknown_kinds', () {
    final Random random = seededRandom(49331);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomApprovalActionJson(random);
      final String knownKind = pickOne(random, _actionKinds);
      final List<String> unknownKinds = <String>[
        knownKind.toUpperCase(),
        ' $knownKind',
        knownKind.replaceAll('_', ''),
        '${knownKind}s',
        '',
        randomText(random),
      ];
      final String unknownKind = pickOne(random, unknownKinds);
      if (_actionKinds.contains(unknownKind)) {
        continue;
      }

      final JsonObject brokenJson = replaceWireField(
        wireJson,
        'kind',
        unknownKind,
      );

      expect(() => ApprovalAction.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_approval_action_from_json_property_'
      'rejects_wrongly_typed_fields', () {
    final Random random = seededRandom(49332);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomApprovalActionJson(random);

      expectWrongKindFieldsRejected(
        random,
        wireJson,
        ApprovalAction.fromJson,
      );
    }
  });

  test('test_approval_action_from_json_property_ignores_unknown_fields', () {
    final Random random = seededRandom(49333);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomApprovalActionJson(random);
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final ApprovalAction action = ApprovalAction.fromJson(widenedJson);

      expect(reencodeAsJsonText(action), equals(wireJson));
    }
  });

  test('test_signed_decision_to_json_property_'
      'writes_decided_at_as_utc_text', () {
    final Random random = seededRandom(49340);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime decidedAt = randomMicrosecondMoment(random);
      final SignedDecision decision = SignedDecision(
        decision: pickOne(random, ApprovalDecision.values),
        decidedBy: randomDeviceId(random),
        decidedAt: decidedAt,
        signature: randomBytes(random),
      );

      expectUtcMomentText(decision.toJson()['decided_at'], decidedAt);
    }
  });

  test('test_approval_request_to_json_property_'
      'writes_requested_at_as_utc_text', () {
    final Random random = seededRandom(49341);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime requestedAt = randomMicrosecondMoment(random);
      final ApprovalRequest request = ApprovalRequest(
        id: ApprovalId(randomUuidText(random)),
        runId: null,
        action: Deploy(target: randomText(random)),
        requestedBy: randomDeviceId(random),
        requestedAt: requestedAt,
        decision: null,
      );

      expectUtcMomentText(request.toJson()['requested_at'], requestedAt);
    }
  });
}

String _readActionKind(ApprovalAction action) {
  return switch (action) {
    PushCommits() => 'push_commits',
    Deploy() => 'deploy',
    DeleteBranchOrFiles() => 'delete_branch_or_files',
    SignWorkflow() => 'sign_workflow',
    RunCommand() => 'run_command',
    ImproveSkill() => 'improve_skill',
  };
}

int _buildByte(Random random) => random.nextInt(_byteValueCount);

PushCommits _buildPushCommits(Random random, List<String> commits) {
  return PushCommits(
    repository: randomText(random),
    branch: randomText(random),
    commits: commits,
  );
}

List<String> _readCommits(PushCommits push) => push.commits;

SignedDecision _buildSignedDecision(Random random, List<int> signature) {
  return SignedDecision(
    decision: pickOne(random, ApprovalDecision.values),
    decidedBy: randomDeviceId(random),
    decidedAt: randomUtcMoment(random),
    signature: signature,
  );
}

List<int> _readSignature(SignedDecision decision) => decision.signature;
