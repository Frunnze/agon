import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/wire_json_edits.dart';

const String _addressField = 'address';
const String _branchField = 'default_branch';
const String _startedGitField = 'has_started_git';
const List<String> _textFields = <String>[_addressField, _branchField];
const List<String> _everyField = <String>[
  _addressField,
  _branchField,
  _startedGitField,
];

JsonObject _randomCheckedFolderJson(Random random) {
  return <String, Object?>{
    _addressField: randomHostileText(random),
    _branchField: randomHostileText(random),
    _startedGitField: random.nextBool(),
  };
}

void main() {
  test('test_checked_local_folder_from_json_property_keeps_every_field', () {
    final Random random = seededRandom(54300);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _randomCheckedFolderJson(random);

      final CheckedLocalFolder folder = CheckedLocalFolder.fromJson(wireJson);

      expect(folder.address, wireJson[_addressField]);
      expect(folder.defaultBranch, wireJson[_branchField]);
      expect(folder.hasStartedGit, wireJson[_startedGitField]);
    }
  });

  test('test_checked_local_folder_from_json_property_needs_every_field', () {
    final Random random = seededRandom(54301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _randomCheckedFolderJson(random);
      final String field = pickOne(random, _everyField);

      final JsonObject shortenedJson = removeWireField(wireJson, field);
      final JsonObject nulledJson = replaceWireField(wireJson, field, null);

      expect(
        () => CheckedLocalFolder.fromJson(shortenedJson),
        throwsFormatException,
      );
      expect(
        () => CheckedLocalFolder.fromJson(nulledJson),
        throwsFormatException,
      );
    }
  });

  test('test_checked_local_folder_from_json_property_'
      'rejects_wrongly_typed_fields', () {
    final Random random = seededRandom(54302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _randomCheckedFolderJson(random);
      final Object? replacement = randomArbitraryJson(random);
      final String textField = pickOne(random, _textFields);

      if (replacement is! String) {
        final JsonObject brokenText = replaceWireField(
          wireJson,
          textField,
          replacement,
        );
        expect(
          () => CheckedLocalFolder.fromJson(brokenText),
          throwsFormatException,
        );
      }
      if (replacement is! bool) {
        final JsonObject brokenFlag = replaceWireField(
          wireJson,
          _startedGitField,
          replacement,
        );
        expect(
          () => CheckedLocalFolder.fromJson(brokenFlag),
          throwsFormatException,
        );
      }
    }
  });

  test('test_checked_local_folder_from_json_property_'
      'ignores_unknown_fields', () {
    final Random random = seededRandom(54303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = _randomCheckedFolderJson(random);
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final CheckedLocalFolder folder = CheckedLocalFolder.fromJson(
        widenedJson,
      );

      expect(folder.address, wireJson[_addressField]);
      expect(folder.defaultBranch, wireJson[_branchField]);
      expect(folder.hasStartedGit, wireJson[_startedGitField]);
    }
  });
}
