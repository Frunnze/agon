import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/branching_node_shapes.dart';
import '../support/link_node_shapes.dart';
import '../support/node_shapes.dart';

const int _firstSeed = 4100;

void main() {
  final List<NodeShape> shapes = <NodeShape>[
    ...nodeShapes,
    ...linkNodeShapes,
    ...branchingNodeShapes,
  ];
  for (int index = 0; index < shapes.length; index += 1) {
    final NodeShape shape = shapes[index];

    test('test_${shape.decoderName}_property_round_trips_node_json', () {
      final Random random = seededRandom(_firstSeed + index);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? nodeJson = shape.buildJson(random);
        final JsonEncodable decoded = shape.decode(nodeJson);
        final String encodedText = jsonEncode(decoded.toJson());

        expect(jsonDecode(encodedText), equals(nodeJson));
      }
    });
  }
}
