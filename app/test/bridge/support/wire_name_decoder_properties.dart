import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';

typedef WireNamedDecoder = WireNamed Function(Object? json);

final class WireNameDecoderFamily {
  const WireNameDecoderFamily({
    required this.typeName,
    required this.choices,
    required this.nodeNames,
    required this.decode,
  });

  final String typeName;
  final List<WireNamed> choices;
  final List<String> nodeNames;
  final WireNamedDecoder decode;
}

const String _wordSeparator = '_';

void testDecodeReadsEveryNodeName(WireNameDecoderFamily family) {
  test('test_${family.typeName}_decode_property_reads_every_node_name', () {
    final Set<WireNamed> reachedChoices = <WireNamed>{};

    for (final String nodeName in family.nodeNames) {
      final WireNamed decoded = family.decode(nodeName);

      expect(decoded.wireName, nodeName);
      reachedChoices.add(decoded);
    }

    for (final WireNamed choice in family.choices) {
      expect(family.decode(choice.wireName), same(choice));
    }
    expect(reachedChoices, equals(family.choices.toSet()));
  });
}

void testDecodeRejectsNearMissNames(WireNameDecoderFamily family, int seed) {
  test('test_${family.typeName}_decode_property_rejects_near_miss_names', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeName = pickOne(random, family.nodeNames);
      final String nearMiss = pickOne(random, _nearMissesOf(nodeName));
      if (family.nodeNames.contains(nearMiss)) {
        continue;
      }

      expect(() => family.decode(nearMiss), throwsFormatException);
    }
  });
}

void testDecodeRejectsAnythingButANodeName(
  WireNameDecoderFamily family,
  int seed,
) {
  test(
    'test_${family.typeName}_decode_property_rejects_anything_but_a_name',
    () {
      final Random random = seededRandom(seed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? arbitraryJson = randomArbitraryJson(random);
        final String nodeName = pickOne(random, family.nodeNames);
        final List<Object?> wrappedName = <Object?>[nodeName];
        final Map<String, Object?> namedObject = <String, Object?>{
          'name': nodeName,
        };

        expect(() => family.decode(wrappedName), throwsFormatException);
        expect(() => family.decode(namedObject), throwsFormatException);
        if (family.nodeNames.contains(arbitraryJson)) {
          continue;
        }
        expect(() => family.decode(arbitraryJson), throwsFormatException);
      }
    },
  );
}

List<String> _nearMissesOf(String nodeName) {
  return <String>[
    nodeName.toUpperCase(),
    ' $nodeName',
    '$nodeName ',
    '$nodeName\n',
    '\t$nodeName',
    '$nodeName\u200b',
    '"$nodeName"',
    '${nodeName}s',
    nodeName.substring(1),
    nodeName.replaceAll(_wordSeparator, '-'),
    nodeName.replaceAll(_wordSeparator, ' '),
    _joinWordsInCamelCase(nodeName),
  ];
}

String _joinWordsInCamelCase(String snakeCaseName) {
  final List<String> words = snakeCaseName.split(_wordSeparator);
  final StringBuffer camelCaseName = StringBuffer(words.first);

  for (final String word in words.skip(1)) {
    camelCaseName.write(word[0].toUpperCase());
    camelCaseName.write(word.substring(1));
  }

  return camelCaseName.toString();
}
