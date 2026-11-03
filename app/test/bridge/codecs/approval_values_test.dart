import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';

const String _backendRunCommandText =
    '{"kind":"run_command","tool":"Bash","command":"npm test"}';

void main() {
  test('test_run_command_to_json_property_round_trips_through_from_json', () {
    final Random random = seededRandom(4301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> wireJson = randomRunCommandJson(random);
      final ApprovalAction decoded = ApprovalAction.fromJson(wireJson);
      final String encodedText = jsonEncode(decoded.toJson());

      expect(decoded, isA<RunCommand>());
      expect(jsonDecode(encodedText), equals(wireJson));
    }
  });

  test('test_approval_action_from_json_property_reads_backend_command', () {
    final Object? backendJson = jsonDecode(_backendRunCommandText);
    final ApprovalAction decoded = ApprovalAction.fromJson(backendJson);

    expect(decoded, isA<RunCommand>());
    final RunCommand command = decoded as RunCommand;
    expect(command.tool, 'Bash');
    expect(command.command, 'npm test');
    expect(jsonEncode(command.toJson()), _backendRunCommandText);
  });

  test('test_approval_action_from_json_property_command_needs_both_texts', () {
    final Random random = seededRandom(4302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> wireJson = randomRunCommandJson(random);
      final String missingField = pickOne(random, <String>['tool', 'command']);
      final Map<String, Object?> brokenJson = <String, Object?>{
        for (final MapEntry<String, Object?> field in wireJson.entries)
          if (field.key != missingField) field.key: field.value,
      };

      expect(
        () => ApprovalAction.fromJson(brokenJson),
        throwsFormatException,
      );
    }
  });
}
