import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/random_typed_values.dart';

const int _largestPatternCount = 6;

List<String> _randomPatterns(Random random) {
  final int patternCount = random.nextInt(_largestPatternCount);
  return <String>[
    for (int i = 0; i < patternCount; i += 1) randomText(random),
  ];
}

void main() {
  test(
    'test_set_protected_files_command_property_sends_patterns_in_order',
    () {
      final Random random = seededRandom(4961);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkspaceId workspaceId = randomWorkspaceId(random);
        final List<String> patterns = _randomPatterns(random);

        final JsonObject encoded = encodeNodeCommand(
          SetProtectedFilesCommand(
            workspaceId: workspaceId,
            patterns: patterns,
          ),
        );

        expect(encoded['workspace_id'], workspaceId.value);
        expect(encoded['patterns'], equals(patterns));
      }
    },
  );

  test('test_set_protected_files_command_property_keeps_its_own_copy', () {
    final Random random = seededRandom(4962);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random);
      final List<String> patternsBefore = List<String>.of(patterns);
      final SetProtectedFilesCommand command = SetProtectedFilesCommand(
        workspaceId: randomWorkspaceId(random),
        patterns: patterns,
      );

      patterns.add(randomText(random));

      expect(command.patterns, equals(patternsBefore));
      expect(
        () => command.patterns.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_reset_protected_files_command_property_sends_workspace', () {
    final Random random = seededRandom(4963);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = randomWorkspaceId(random);

      final JsonObject encoded = encodeNodeCommand(
        ResetProtectedFilesCommand(workspaceId: workspaceId),
      );

      expect(encoded['workspace_id'], workspaceId.value);
    }
  });
}
