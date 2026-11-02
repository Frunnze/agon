import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';

final class _IdentifierDecoder {
  const _IdentifierDecoder(this.decoderName, this.decode);

  final String decoderName;
  final JsonValueDecoder<Object> decode;
}

const List<_IdentifierDecoder> _identifierDecoders = <_IdentifierDecoder>[
  _IdentifierDecoder('decode_workspace_id', decodeWorkspaceId),
  _IdentifierDecoder('decode_project_id', decodeProjectId),
  _IdentifierDecoder('decode_device_id', decodeDeviceId),
  _IdentifierDecoder('decode_workflow_id', decodeWorkflowId),
  _IdentifierDecoder('decode_workflow_agent_id', decodeWorkflowAgentId),
  _IdentifierDecoder('decode_skill_id', decodeSkillId),
  _IdentifierDecoder('decode_rule_id', decodeRuleId),
  _IdentifierDecoder('decode_task_id', decodeTaskId),
  _IdentifierDecoder('decode_run_id', decodeRunId),
  _IdentifierDecoder('decode_approval_id', decodeApprovalId),
];

void main() {
  for (final _IdentifierDecoder decoder in _identifierDecoders) {
    test('test_${decoder.decoderName}_property_keeps_the_node_text', () {
      final Random random = seededRandom(4601);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String identifierText = randomText(random);
        final Object? arbitraryJson = randomArbitraryJson(random);

        expect(decoder.decode(identifierText), identifierText);
        if (arbitraryJson is! String) {
          expect(() => decoder.decode(arbitraryJson), throwsFormatException);
        }
      }
    });
  }
}
