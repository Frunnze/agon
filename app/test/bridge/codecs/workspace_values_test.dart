import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_catalog_json.dart';

const String _protectedFilesField = 'protected_files';

List<Object?> _readNodePatterns(Map<String, Object?> workspaceJson) {
  final Map<String, Object?> protectedFiles =
      workspaceJson[_protectedFilesField]! as Map<String, Object?>;
  return protectedFiles['patterns']! as List<Object?>;
}

void main() {
  test('test_workspace_from_json_property_keeps_patterns_in_order', () {
    final Random random = seededRandom(4951);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomWorkspaceJson(random);

      final Workspace decoded = Workspace.fromJson(json);

      expect(decoded.protectedFiles, equals(_readNodePatterns(json)));
    }
  });

  test('test_workspace_to_json_property_round_trips_protected_files', () {
    final Random random = seededRandom(4952);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomWorkspaceJson(random);

      final JsonObject encoded = Workspace.fromJson(json).toJson();

      expect(jsonDecode(jsonEncode(encoded)), equals(json));
    }
  });

  test('test_workspace_from_json_property_patterns_are_frozen', () {
    final Random random = seededRandom(4953);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace decoded = Workspace.fromJson(
        randomWorkspaceJson(random),
      );

      expect(
        () => decoded.protectedFiles.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_workspace_from_json_property_requires_protected_files', () {
    final Random random = seededRandom(4954);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = <String, Object?>{
        ...randomWorkspaceJson(random),
      }..remove(_protectedFilesField);

      expect(() => Workspace.fromJson(json), throwsFormatException);
    }
  });

  test('test_workspace_from_json_property_rejects_non_text_patterns', () {
    final Random random = seededRandom(4955);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = <String, Object?>{
        ...randomWorkspaceJson(random),
        _protectedFilesField: <String, Object?>{
          'patterns': <Object?>[randomText(random), random.nextInt(9)],
        },
      };

      expect(() => Workspace.fromJson(json), throwsFormatException);
    }
  });
}
