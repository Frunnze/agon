import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';

final class WireNameCodec<Choice extends WireNamed> {
  const WireNameCodec({
    required this.typeName,
    required this.seed,
    required this.choices,
    required this.decode,
    required this.nodeNames,
  });

  final String typeName;
  final int seed;
  final List<Choice> choices;
  final JsonValueDecoder<Choice> decode;
  final List<String> nodeNames;
}

void testWireNameDecodeProperties<Choice extends WireNamed>(
  WireNameCodec<Choice> codec,
) {
  test('test_${codec.typeName}_decode_property_reads_every_node_name', () {
    final Set<Choice> decodedChoices = <Choice>{};

    for (final String nodeName in codec.nodeNames) {
      final Choice choice = codec.decode(nodeName);
      expect(choice.wireName, nodeName);
      decodedChoices.add(choice);
    }

    expect(decodedChoices, equals(codec.choices.toSet()));
    expect(codec.nodeNames.toSet().length, codec.nodeNames.length);
  });

  test('test_${codec.typeName}_decode_property_rejects_near_miss_names', () {
    final Random random = seededRandom(codec.seed);
    final Set<String> nodeNames = codec.nodeNames.toSet();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeName = pickOne(random, codec.nodeNames);
      final List<String> nearMisses = <String>[
        nodeName.toUpperCase(),
        ' $nodeName',
        '$nodeName ',
        '$nodeName\n',
        '$nodeName​',
        nodeName.replaceAll('_', ''),
        nodeName.replaceAll('_', '-'),
        nodeName.substring(1),
        '$nodeName${randomText(random)}?',
        '',
      ];
      final String nearMiss = pickOne(random, nearMisses);
      if (nodeNames.contains(nearMiss)) {
        continue;
      }

      expect(() => codec.decode(nearMiss), throwsFormatException);
    }
  });

  test('test_${codec.typeName}_decode_property_rejects_non_text_json', () {
    final Random random = seededRandom(codec.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeName = pickOne(random, codec.nodeNames);
      final List<Object?> nonTexts = <Object?>[
        null,
        random.nextBool(),
        random.nextInt(codec.choices.length),
        <Object?>[nodeName],
        <String, Object?>{nodeName: nodeName},
      ];
      final Object? nonText = pickOne(random, nonTexts);

      expect(() => codec.decode(nonText), throwsFormatException);
    }
  });
}
