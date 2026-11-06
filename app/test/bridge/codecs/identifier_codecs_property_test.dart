import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/identifier_decoders.dart';

const int _firstSeed = 50101;
const int _seedsPerDecoder = 3;

List<String> _collidingTexts(Random random) {
  final String baseText = randomHostileText(random);
  return <String>[
    baseText,
    '$baseText ',
    baseText.toUpperCase(),
    randomHostileText(random),
  ];
}

void main() {
  for (int index = 0; index < identifierDecoders.length; index += 1) {
    final IdentifierDecoder decoder = identifierDecoders[index];
    final int seed = _firstSeed + index * _seedsPerDecoder;

    test('test_${decoder.decoderName}_property_rejects_non_text_json', () {
      final Random random = seededRandom(seed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? arbitraryJson = randomArbitraryJson(random);
        final String identifierText = randomHostileText(random);
        final List<Object?> wrappedText = <Object?>[identifierText];
        final Map<String, Object?> textObject = <String, Object?>{
          'id': identifierText,
        };

        expect(() => decoder.decode(wrappedText), throwsFormatException);
        expect(() => decoder.decode(textObject), throwsFormatException);
        if (arbitraryJson is String) {
          continue;
        }
        expect(() => decoder.decode(arbitraryJson), throwsFormatException);
      }
    });

    test(
      'test_${decoder.decoderName}_property_keeps_hostile_text_exactly',
      () {
        final Random random = seededRandom(seed + 1);

        for (int i = 0; i < propertyIterations; i += 1) {
          final String identifierText = randomHostileText(random);

          final Object decoded = decoder.decode(identifierText);

          expect(decoded, isA<String>());
          expect((decoded as String).codeUnits, identifierText.codeUnits);
        }
      },
    );

    test('test_${decoder.decoderName}_property_equal_only_for_equal_text', () {
      final Random random = seededRandom(seed + 2);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<String> pool = _collidingTexts(random);
        final String firstText = pool[random.nextInt(pool.length)];
        final String secondText = pool[random.nextInt(pool.length)];

        final Object firstIdentifier = decoder.decode(firstText);
        final Object secondIdentifier = decoder.decode(secondText);

        expect(firstIdentifier == secondIdentifier, firstText == secondText);
      }
    });
  }
}
