import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/moment_offset_texts.dart';
import '../support/random_moments.dart';

const int _dateTextLength = 10;
const int _largestEpochMilliseconds = 1 << 32;

final RegExp _utcMomentShape = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?Z$',
);

void main() {
  test('test_decode_moment_property_rejects_text_without_a_zone_offset', () {
    final Random random = seededRandom(5101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomPreciseMoment(random).toUtc();
      final String zonelessText = textWithoutZone(moment);
      final String dateText = zonelessText.substring(0, _dateTextLength);

      expect(() => decodeMoment(zonelessText), throwsFormatException);
      expect(() => decodeMoment(dateText), throwsFormatException);
    }
  });

  test('test_decode_moment_property_offset_text_names_the_same_instant', () {
    final Random random = seededRandom(5102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomPreciseMoment(random).toUtc();
      final String offsetText = writeMomentWithRandomOffset(random, moment);

      final DateTime decoded = decodeMoment(offsetText);

      expect(decoded, equals(moment));
      expect(decoded.isUtc, isTrue);
    }
  });

  test('test_decode_moment_property_rejects_moments_that_are_not_text', () {
    final Random random = seededRandom(5103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int epochMilliseconds = random.nextInt(_largestEpochMilliseconds);
      final DateTime moment = randomPreciseMoment(random);
      final String momentText = encodeMoment(moment);
      final List<Object?> notText = <Object?>[
        epochMilliseconds,
        epochMilliseconds.toDouble(),
        null,
        <Object?>[momentText],
        <String, Object?>{'at': momentText},
      ];

      for (final Object? json in notText) {
        expect(() => decodeMoment(json), throwsFormatException);
      }
    }
  });

  test('test_encode_moment_property_same_instant_gives_same_text', () {
    final Random random = seededRandom(5104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomPreciseMoment(random).toUtc();
      final DateTime localMoment = moment.toLocal();

      expect(encodeMoment(localMoment), equals(encodeMoment(moment)));
    }
  });

  test('test_encode_moment_property_writes_rfc_3339_utc_text', () {
    final Random random = seededRandom(5105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomPreciseMoment(random).toLocal();

      expect(encodeMoment(moment), matches(_utcMomentShape));
    }
  });

  test('test_encode_optional_moment_property_round_trips_present_moments', () {
    final Random random = seededRandom(5106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomPreciseMoment(random).toLocal();

      final String? encoded = encodeOptionalMoment(moment);

      expect(encoded, isNotNull);
      expect(decodeMoment(encoded), equals(moment.toUtc()));
    }
  });

  test(
    'test_encode_optional_moment_property_same_instant_gives_same_text',
    () {
      final Random random = seededRandom(5107);

      for (int i = 0; i < propertyIterations; i += 1) {
        final DateTime moment = randomPreciseMoment(random).toUtc();

        expect(
          encodeOptionalMoment(moment.toLocal()),
          equals(encodeOptionalMoment(moment)),
        );
      }
    },
  );
}
