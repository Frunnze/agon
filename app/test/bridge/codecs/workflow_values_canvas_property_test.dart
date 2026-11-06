import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/node_json_primitives.dart';
import '../support/random_wire_values.dart';
import '../support/random_work_json.dart';
import '../support/wire_json_edits.dart';

const List<String> _coordinateFields = <String>['horizontal', 'vertical'];

const List<double> _extremeCoordinates = <double>[
  0,
  -0.0,
  1,
  -1,
  0.1,
  double.minPositive,
  -double.minPositive,
  double.maxFinite,
  -double.maxFinite,
  1e-300,
  9007199254740992,
];

double _randomFiniteCoordinate(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _extremeCoordinates);
  }
  return randomCanvasCoordinate(random);
}

num _randomWireNumber(Random random) {
  if (random.nextBool()) {
    return randomWholeNumber(random) - randomWholeNumber(random);
  }
  return _randomFiniteCoordinate(random);
}

void main() {
  test('test_canvas_position_from_json_property_'
      'reads_whole_and_fractional_numbers_as_their_value', () {
    final Random random = seededRandom(53600);

    for (int i = 0; i < propertyIterations; i += 1) {
      final num horizontal = _randomWireNumber(random);
      final num vertical = _randomWireNumber(random);

      final CanvasPosition position = CanvasPosition.fromJson(
        <String, Object?>{'horizontal': horizontal, 'vertical': vertical},
      );

      expect(position.horizontal, horizontal.toDouble());
      expect(position.vertical, vertical.toDouble());
    }
  });

  test('test_canvas_position_from_json_property_rejects_non_numbers', () {
    final Random random = seededRandom(53601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = pickOne(random, _coordinateFields);
      final Object? replacement = randomArbitraryJson(random);
      if (replacement is num) {
        continue;
      }
      final JsonObject brokenJson = replaceWireField(
        randomCanvasPositionJson(random),
        field,
        replacement,
      );

      expect(() => CanvasPosition.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_canvas_position_from_json_property_needs_both_coordinates', () {
    final Random random = seededRandom(53602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = pickOne(random, _coordinateFields);
      final JsonObject shortenedJson = removeWireField(
        randomCanvasPositionJson(random),
        field,
      );

      expect(
        () => CanvasPosition.fromJson(shortenedJson),
        throwsFormatException,
      );
    }
  });

  test('test_canvas_position_from_json_property_ignores_unknown_fields', () {
    final Random random = seededRandom(53603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomCanvasPositionJson(random);
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final CanvasPosition position = CanvasPosition.fromJson(widenedJson);

      expect(reencodeAsJsonText(position), equals(wireJson));
    }
  });

  test('test_canvas_position_to_json_property_'
      'round_trips_every_finite_coordinate', () {
    final Random random = seededRandom(53604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = CanvasPosition(
        horizontal: _randomFiniteCoordinate(random),
        vertical: _randomFiniteCoordinate(random),
      );

      final CanvasPosition decodedAgain = CanvasPosition.fromJson(
        reencodeAsJsonText(position),
      );

      expect(decodedAgain.horizontal, position.horizontal);
      expect(decodedAgain.vertical, position.vertical);
    }
  });

  test('test_canvas_position_to_json_property_'
      'writes_exactly_the_two_coordinates', () {
    final Random random = seededRandom(53605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double horizontal = _randomFiniteCoordinate(random);
      final double vertical = _randomFiniteCoordinate(random);
      final CanvasPosition position = CanvasPosition(
        horizontal: horizontal,
        vertical: vertical,
      );

      final JsonObject positionJson = position.toJson();

      expect(positionJson.keys, unorderedEquals(_coordinateFields));
      expect(positionJson['horizontal'], horizontal);
      expect(positionJson['vertical'], vertical);
    }
  });

  test('test_canvas_position_to_json_property_never_swaps_the_axes', () {
    final Random random = seededRandom(53606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double coordinate = _randomFiniteCoordinate(random);
      final CanvasPosition position = CanvasPosition(
        horizontal: coordinate,
        vertical: coordinate + 1,
      );
      final CanvasPosition mirrored = CanvasPosition(
        horizontal: position.vertical,
        vertical: position.horizontal,
      );

      final JsonObject positionJson = position.toJson();
      final JsonObject mirroredJson = mirrored.toJson();

      expect(positionJson['horizontal'], mirroredJson['vertical']);
      expect(positionJson['vertical'], mirroredJson['horizontal']);
    }
  });
}
