import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_catalog_json.dart';

const List<List<WireNamed>> _wireNameFamilies = <List<WireNamed>>[
  SkillUsage.values,
  SkillSource.values,
  SkillImprovement.values,
  StepStatus.values,
  RunnerLink.values,
];

final class _NumberedEncodable implements JsonEncodable {
  const _NumberedEncodable(this.number, this.encodingLog);

  final int number;
  final List<int> encodingLog;

  @override
  Object? toJson() {
    encodingLog.add(number);
    return number;
  }
}

List<String> _alteredWireNames(String wireName) {
  return <String>[
    wireName.toUpperCase(),
    ' $wireName',
    '$wireName ',
    wireName.replaceAll('_', '-'),
    wireName.replaceAll('_', ' '),
    '$wireName$wireName',
  ];
}

void main() {
  test('test_decode_list_property_one_bad_element_rejects_the_list', () {
    final Random random = seededRandom(5131);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> texts = List<Object?>.of(randomTexts(random));
      final int badIndex = random.nextInt(texts.length + 1);
      texts.insert(badIndex, pickOne(random, <Object?>[null, 7, true]));

      expect(() => decodeList(texts, decodeText), throwsFormatException);
    }
  });

  test('test_decode_list_property_is_a_copy_not_a_view', () {
    final Random random = seededRandom(5132);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> texts = List<Object?>.of(randomTexts(random));
      final List<Object?> snapshot = List<Object?>.of(texts);

      final List<String> decoded = decodeList(texts, decodeText);
      texts.add(randomText(random));
      if (snapshot.isNotEmpty) {
        texts[0] = '${snapshot.first}!';
      }

      expect(decoded, equals(snapshot));
    }
  });

  test('test_encode_list_property_text_joins_each_encoding_in_order', () {
    final Random random = seededRandom(5133);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> workspacesJson = randomListOf(
        random,
        randomWorkspaceJson,
      );
      final List<Workspace> workspaces = decodeList(
        workspacesJson,
        Workspace.fromJson,
      );
      final List<String> encodings = <String>[];
      for (final Workspace workspace in workspaces) {
        encodings.add(jsonEncode(workspace.toJson()));
      }

      final String encodedText = jsonEncode(encodeList(workspaces));

      expect(encodedText, '[${encodings.join(',')}]');
    }
  });

  test('test_encode_list_property_asks_each_value_once_in_order', () {
    final Random random = seededRandom(5134);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> encodingLog = <int>[];
      final int count = random.nextInt(propertyIterations);
      final List<int> numbers = <int>[];
      final List<JsonEncodable> values = <JsonEncodable>[];
      for (int number = 0; number < count; number += 1) {
        numbers.add(number);
        values.add(_NumberedEncodable(number, encodingLog));
      }

      final List<Object?> encoded = encodeList(values);

      expect(encoded, equals(numbers));
      expect(encodingLog, equals(numbers));
    }
  });

  test('test_decode_wire_name_property_matching_is_exact', () {
    final Random random = seededRandom(5135);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WireNamed> choices = pickOne(random, _wireNameFamilies);
      final WireNamed choice = pickOne(random, choices);
      final Set<String> wireNames = <String>{};
      for (final WireNamed knownChoice in choices) {
        wireNames.add(knownChoice.wireName);
      }

      for (final String altered in _alteredWireNames(choice.wireName)) {
        if (!wireNames.contains(altered)) {
          expect(
            () => decodeWireName(choices, altered),
            throwsFormatException,
          );
        }
      }
    }
  });
}
