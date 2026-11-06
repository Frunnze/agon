import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/identifier_decoders.dart';

void main() {
  for (final IdentifierDecoder decoder in identifierDecoders) {
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
