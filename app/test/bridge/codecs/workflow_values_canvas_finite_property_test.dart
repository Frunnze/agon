import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_work_json.dart';
import '../support/wire_json_edits.dart';

const List<String> _coordinateFields = <String>['horizontal', 'vertical'];
const List<double> _nonFiniteNumbers = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
];
const List<String> _tooLargeNumberTexts = <String>[
  '1e400',
  '-1e400',
  '1.8e308',
];

CanvasPosition _buildWithOneCoordinate(
  String field,
  double coordinate,
  double otherCoordinate,
) {
  if (field == 'horizontal') {
    return CanvasPosition(horizontal: coordinate, vertical: otherCoordinate);
  }
  return CanvasPosition(horizontal: otherCoordinate, vertical: coordinate);
}

void main() {
  test('test_canvas_position_constructor_property_'
      'rejects_a_non_finite_coordinate', () {
    final Random random = seededRandom(77501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = pickOne(random, _coordinateFields);
      final double nonFinite = pickOne(random, _nonFiniteNumbers);
      final double finite = randomCanvasCoordinate(random);

      expect(
        () => _buildWithOneCoordinate(field, nonFinite, finite),
        throwsArgumentError,
      );
    }
  });

  test('test_canvas_position_constructor_property_'
      'always_encodes_to_json_text', () {
    final Random random = seededRandom(77502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = CanvasPosition(
        horizontal: randomCanvasCoordinate(random),
        vertical: randomCanvasCoordinate(random),
      );

      final String positionText = jsonEncode(position.toJson());

      expect(jsonDecode(positionText), position.toJson());
    }
  });

  test('test_canvas_position_from_json_property_'
      'rejects_a_non_finite_coordinate_as_a_format_error', () {
    final Random random = seededRandom(77503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject brokenJson = replaceWireField(
        randomCanvasPositionJson(random),
        pickOne(random, _coordinateFields),
        pickOne(random, _nonFiniteNumbers),
      );

      expect(() => CanvasPosition.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_canvas_position_from_json_property_'
      'rejects_json_text_too_large_for_a_coordinate', () {
    final Random random = seededRandom(77504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = pickOne(random, _coordinateFields);
      final String numberText = pickOne(random, _tooLargeNumberTexts);
      final String otherField = field == 'horizontal'
          ? 'vertical'
          : 'horizontal';
      final String positionText =
          '{"$field": $numberText, "$otherField": '
          '${randomCanvasCoordinate(random)}}';

      expect(
        () => CanvasPosition.fromJson(jsonDecode(positionText)),
        throwsFormatException,
      );
    }
  });
}
