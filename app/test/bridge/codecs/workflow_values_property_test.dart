import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_typed_values.dart';
import '../support/random_wire_values.dart';
import '../support/random_work_json.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_decoder_properties.dart';

const int _firstFamilySeed = 53500;
const int _seedsPerFamily = 2;
const int _byteValueCount = 256;

const List<WireNameDecoderFamily> _workflowFamilies = <WireNameDecoderFamily>[
  WireNameDecoderFamily(
    typeName: 'agent_kind',
    choices: AgentKind.values,
    nodeNames: nodeAgentKinds,
    decode: AgentKind.decode,
  ),
  WireNameDecoderFamily(
    typeName: 'step_kind',
    choices: StepKind.values,
    nodeNames: nodeStepKinds,
    decode: StepKind.decode,
  ),
];

const List<WireCodec> _workflowPartCodecs = <WireCodec>[
  WireCodec(
    typeName: 'agent_connection',
    seed: 53510,
    buildJson: randomAgentConnectionJson,
    decode: AgentConnection.fromJson,
    requiredFields: <String>{'from', 'to'},
    optionalFields: <String>{'condition', 'round_limit'},
  ),
  WireCodec(
    typeName: 'workflow_signature',
    seed: 53520,
    buildJson: randomWorkflowSignatureJson,
    decode: WorkflowSignature.fromJson,
    requiredFields: <String>{'signed_by', 'signature', 'signed_document'},
    optionalFields: <String>{},
  ),
];

int _buildByte(Random random) => random.nextInt(_byteValueCount);

WorkflowSignature _buildSignature(Random random, List<int> signature) {
  return WorkflowSignature(
    signedBy: randomDeviceId(random),
    signature: signature,
    signedDocument: randomHostileText(random),
  );
}

List<int> _readSignature(WorkflowSignature signature) => signature.signature;

WorkflowAgentId _buildWorkflowAgentId(Random random) {
  return WorkflowAgentId(randomUuidText(random));
}

void main() {
  for (int index = 0; index < _workflowFamilies.length; index += 1) {
    final WireNameDecoderFamily family = _workflowFamilies[index];
    final int seed = _firstFamilySeed + index * _seedsPerFamily;

    testDecodeReadsEveryNodeName(family);
    testDecodeRejectsNearMissNames(family, seed);
    testDecodeRejectsAnythingButANodeName(family, seed + 1);
  }

  for (final WireCodec codec in _workflowPartCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<WorkflowSignature, int>(
      testNamePrefix: 'test_workflow_signature_constructor_property_signature',
      seed: 53530,
      buildElement: _buildByte,
      construct: _buildSignature,
      readList: _readSignature,
    ),
  );

  test('test_agent_connection_from_json_property_'
      'keeps_hostile_conditions_and_boundary_round_limits', () {
    final Random random = seededRandom(53540);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String condition = randomHostileText(random);
      final int roundLimit = randomWholeNumber(random);
      final JsonObject wireJson = <String, Object?>{
        ...randomAgentConnectionJson(random),
        'condition': condition,
        'round_limit': roundLimit,
      };

      final AgentConnection connection = AgentConnection.fromJson(wireJson);

      expect(connection.condition, condition);
      expect(connection.roundLimit, roundLimit);
    }
  });

  test('test_agent_connection_to_json_property_'
      'keeps_the_direction_of_every_connection', () {
    final Random random = seededRandom(53541);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId from = _buildWorkflowAgentId(random);
      final WorkflowAgentId to = random.nextBool()
          ? from
          : _buildWorkflowAgentId(random);
      final AgentConnection connection = AgentConnection(
        from: from,
        to: to,
        condition: randomOptionalText(random),
        roundLimit: null,
      );

      final AgentConnection decodedAgain = AgentConnection.fromJson(
        reencodeAsJsonText(connection),
      );

      expect(decodedAgain.from, from);
      expect(decodedAgain.to, to);
      expect(decodedAgain.condition, connection.condition);
      expect(decodedAgain.roundLimit, isNull);
    }
  });

  test(
    'test_agent_connection_from_json_property_rejects_fractional_rounds',
    () {
      final Random random = seededRandom(53542);

      for (int i = 0; i < propertyIterations; i += 1) {
        final int wholeRounds = randomWholeNumber(random);
        final JsonObject wireJson = replaceWireField(
          randomAgentConnectionJson(random),
          'round_limit',
          wholeRounds + random.nextDouble() + 0.5,
        );

        expect(
          () => AgentConnection.fromJson(wireJson),
          throwsFormatException,
        );
      }
    },
  );

  test('test_workflow_signature_from_json_property_'
      'keeps_the_signer_and_hostile_document', () {
    final Random random = seededRandom(53543);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String signedDocument = randomHostileText(random);
      final JsonObject wireJson = replaceWireField(
        randomWorkflowSignatureJson(random),
        'signed_document',
        signedDocument,
      );

      final WorkflowSignature signature = WorkflowSignature.fromJson(wireJson);

      final List<Object?> wireSignature =
          wireJson['signature']! as List<Object?>;
      expect(signature.signedDocument, signedDocument);
      expect(signature.signedBy.value, wireJson['signed_by']);
      expect(signature.signature, orderedEquals(wireSignature));
    }
  });
}
