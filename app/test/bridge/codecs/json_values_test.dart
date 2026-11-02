import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/node_json_primitives.dart';
import '../support/random_catalog_json.dart';

const int _nanosecondsPerMicrosecond = 1000;
const int _nanosecondDigits = 9;
const int _microsecondsPerSecond = 1000000;
const int _wholeSecondsTextLength = 19;

final class _PrimitiveDecoder {
  const _PrimitiveDecoder(this.decoderName, this.decode, this.accepts);

  final String decoderName;
  final JsonValueDecoder<Object?> decode;
  final bool Function(Object? json) accepts;
}

bool _isObject(Object? json) => json is Map<String, Object?>;

bool _isText(Object? json) => json is String;

bool _isWholeNumber(Object? json) => json is int;

bool _isNumber(Object? json) => json is num;

bool _isFlag(Object? json) => json is bool;

bool _isNothing(Object? json) => json == null;

const List<_PrimitiveDecoder> _primitiveDecoders = <_PrimitiveDecoder>[
  _PrimitiveDecoder('decode_object', decodeObject, _isObject),
  _PrimitiveDecoder('decode_text', decodeText, _isText),
  _PrimitiveDecoder('decode_integer', decodeInteger, _isWholeNumber),
  _PrimitiveDecoder('decode_number', decodeNumber, _isNumber),
  _PrimitiveDecoder('decode_flag', decodeFlag, _isFlag),
  _PrimitiveDecoder('decode_nothing', _decodeNothingValue, _isNothing),
];

Object? _decodeNothingValue(Object? json) {
  decodeNothing(json);
  return null;
}

String _chronoMomentText(DateTime moment, int extraNanoseconds) {
  final String secondsText = moment.toIso8601String().substring(
    0,
    _wholeSecondsTextLength,
  );
  final int microseconds =
      moment.millisecond * Duration.microsecondsPerMillisecond +
      moment.microsecond;
  final int nanoseconds =
      microseconds * _nanosecondsPerMicrosecond + extraNanoseconds;
  final String fraction = nanoseconds.toString().padLeft(
    _nanosecondDigits,
    '0',
  );
  return '$secondsText.${fraction}Z';
}

void main() {
  for (final _PrimitiveDecoder decoder in _primitiveDecoders) {
    test('test_${decoder.decoderName}_property_accepts_only_its_kind', () {
      final Random random = seededRandom(4501);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? json = randomArbitraryJson(random);

        if (decoder.accepts(json)) {
          expect(decoder.decode(json), equals(json));
        } else {
          expect(() => decoder.decode(json), throwsFormatException);
        }
      }
    });
  }

  test('test_decode_moment_property_reads_chrono_nanosecond_text', () {
    final Random random = seededRandom(4502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random)
          .add(Duration(microseconds: random.nextInt(_microsecondsPerSecond)));
      final int extraNanoseconds = random.nextInt(_nanosecondsPerMicrosecond);
      final String chronoText = _chronoMomentText(moment, extraNanoseconds);

      final DateTime decoded = decodeMoment(chronoText);

      expect(decoded, equals(moment));
      expect(decoded.isUtc, isTrue);
    }
  });

  test('test_encode_moment_property_round_trips_through_decode_moment', () {
    final Random random = seededRandom(4503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random)
          .add(Duration(microseconds: random.nextInt(_microsecondsPerSecond)));

      final DateTime decoded = decodeMoment(encodeMoment(moment));

      expect(decoded, equals(moment.toUtc()));
      expect(encodeMoment(moment), endsWith('Z'));
    }
  });

  test('test_encode_optional_moment_property_keeps_absence', () {
    final Random random = seededRandom(4504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);

      expect(encodeOptionalMoment(null), isNull);
      expect(encodeOptionalMoment(moment), encodeMoment(moment));
    }
  });

  test('test_decode_moment_property_rejects_text_that_is_no_moment', () {
    final Random random = seededRandom(4505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String notMoment = 'not a moment ${randomText(random)}';

      expect(() => decodeMoment(notMoment), throwsFormatException);
    }
  });

  test('test_decode_list_property_keeps_order_and_is_unmodifiable', () {
    final Random random = seededRandom(4506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> texts = randomTexts(random);

      final List<String> decoded = decodeList(texts, decodeText);

      expect(decoded, equals(texts));
      expect(() => decoded.add(randomText(random)), throwsUnsupportedError);
      expect(
        () => decodeList(randomText(random), decodeText),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('test_encode_list_property_encodes_each_value_in_order', () {
    final Random random = seededRandom(4507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> workspacesJson = randomListOf(
        random,
        randomWorkspaceJson,
      );
      final List<Workspace> workspaces = decodeList(
        workspacesJson,
        Workspace.fromJson,
      );

      expect(encodeList(workspaces), equals(workspacesJson));
    }
  });

  test('test_read_field_property_rejects_missing_fields', () {
    final Random random = seededRandom(4508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = randomText(random);
      final String value = randomText(random);
      final JsonObject present = <String, Object?>{field: value};
      final JsonObject missing = <String, Object?>{'$field!': value};

      expect(readField(present, field, decodeText), value);
      expect(
        () => readField(missing, field, decodeText),
        throwsA(
          isA<FormatException>().having(
            (FormatException problem) => problem.message,
            'message',
            contains(field),
          ),
        ),
      );
      expect(
        () => readListField(missing, field, decodeText),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('test_read_optional_field_property_treats_missing_as_null', () {
    final Random random = seededRandom(4509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = randomText(random);
      final String value = randomText(random);

      expect(readOptionalField(<String, Object?>{}, field, decodeText), null);
      expect(
        readOptionalField(<String, Object?>{field: null}, field, decodeText),
        isNull,
      );
      expect(
        readOptionalField(<String, Object?>{field: value}, field, decodeText),
        value,
      );
    }
  });

  test('test_read_list_field_property_decodes_present_lists', () {
    final Random random = seededRandom(4510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> texts = randomTexts(random);
      final JsonObject fields = <String, Object?>{'labels': texts};

      expect(readListField(fields, 'labels', decodeText), equals(texts));
    }
  });
}
