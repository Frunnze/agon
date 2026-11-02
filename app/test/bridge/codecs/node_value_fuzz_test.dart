import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/decoding_outcome.dart';
import '../support/link_node_shapes.dart';
import '../support/node_shapes.dart';

const int _firstSeed = 4300;

void main() {
  final List<NodeShape> shapes = <NodeShape>[...nodeShapes, ...linkNodeShapes];
  for (int index = 0; index < shapes.length; index += 1) {
    final NodeShape shape = shapes[index];

    test(
      'test_${shape.decoderName}_property_malformed_json_only_raises_format',
      () {
        final Random random = seededRandom(_firstSeed + index);

        for (int i = 0; i < propertyIterations; i += 1) {
          final Object? arbitraryJson = randomArbitraryJson(random);
          final Object? mutatedJson = mutateJson(
            random,
            shape.buildJson(random),
          );

          expect(
            attemptDecoding(() => shape.decode(arbitraryJson)),
            isIn(DecodingOutcome.values),
          );
          expect(
            attemptDecoding(() => shape.decode(mutatedJson)),
            isIn(DecodingOutcome.values),
          );
        }
      },
    );
  }
}
