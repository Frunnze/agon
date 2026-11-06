import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/node_wire_names.dart';
import '../support/random_work_json.dart';
import '../support/wire_json_edits.dart';

const String _wordSeparator = '_';

DiffLine _buildDiffLine(Random random) {
  return DiffLine(
    change: pickOne(random, DiffLineChange.values),
    text: randomHostileText(random),
  );
}

List<String> _listNamesNearTo(String changeName) {
  return <String>[
    changeName.toUpperCase(),
    ' $changeName',
    '$changeName ',
    '${changeName}s',
    changeName.substring(1),
    changeName.replaceAll(_wordSeparator, '-'),
    'change',
    'text',
    '',
  ];
}

void main() {
  test('test_diff_line_from_json_property_reads_every_change_and_text', () {
    final Random random = seededRandom(53850);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String changeName = pickOne(random, nodeDiffChanges);
      final String text = randomHostileText(random);

      final DiffLine line = DiffLine.fromJson(<String, Object?>{
        changeName: text,
      });

      expect(line.change.wireName, changeName);
      expect(line.text, text);
    }
  });

  test('test_diff_line_from_json_property_rejects_anything_but_one_field', () {
    final Random random = seededRandom(53851);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject lineJson = randomDiffLineJson(random);
      final String secondField = pickOne(random, <String>[
        ...nodeDiffChanges,
        randomHostileText(random),
      ]);
      final JsonObject widenedJson = <String, Object?>{
        ...lineJson,
        secondField: randomHostileText(random),
      };

      expect(
        () => DiffLine.fromJson(<String, Object?>{}),
        throwsFormatException,
      );
      if (widenedJson.length == lineJson.length) {
        continue;
      }
      expect(() => DiffLine.fromJson(widenedJson), throwsFormatException);
    }
  });

  test('test_diff_line_from_json_property_rejects_unknown_changes', () {
    final Random random = seededRandom(53852);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String changeName = pickOne(random, nodeDiffChanges);
      final String unknownName = pickOne(random, _listNamesNearTo(changeName));
      if (nodeDiffChanges.contains(unknownName)) {
        continue;
      }

      final JsonObject lineJson = <String, Object?>{
        unknownName: randomHostileText(random),
      };

      expect(() => DiffLine.fromJson(lineJson), throwsFormatException);
    }
  });

  test('test_diff_line_from_json_property_rejects_non_text_lines', () {
    final Random random = seededRandom(53853);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? nonText = randomArbitraryJson(random);
      if (nonText is String) {
        continue;
      }
      final JsonObject lineJson = <String, Object?>{
        pickOne(random, nodeDiffChanges): nonText,
      };

      expect(() => DiffLine.fromJson(lineJson), throwsFormatException);
    }
  });

  test('test_diff_line_to_json_property_round_trips_every_change', () {
    final Random random = seededRandom(53854);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DiffLine line = _buildDiffLine(random);

      final DiffLine decodedAgain = DiffLine.fromJson(
        reencodeAsJsonText(line),
      );

      expect(decodedAgain.change, line.change);
      expect(decodedAgain.text, line.text);
    }
  });

  test('test_diff_line_to_json_property_writes_one_field_named_by_change', () {
    final Random random = seededRandom(53855);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DiffLine line = _buildDiffLine(random);

      final JsonObject lineJson = line.toJson();

      expect(lineJson.keys, orderedEquals(<String>[line.change.wireName]));
      expect(lineJson[line.change.wireName], line.text);
    }
  });

  test('test_diff_line_to_json_property_reproduces_the_node_json', () {
    final Random random = seededRandom(53856);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject lineJson = randomDiffLineJson(random);

      final DiffLine line = DiffLine.fromJson(lineJson);

      expect(reencodeAsJsonText(line), equals(lineJson));
    }
  });
}
