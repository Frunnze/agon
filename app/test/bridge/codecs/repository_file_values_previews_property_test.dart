import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/file_preview_checks.dart';
import '../support/random_file_json.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const String _hostileTextMiddle = '\n\t"\\\u{1F600}e\u0301\u200b';
const Set<String> _onlyKind = <String>{previewKindField};

const WireFields _textFields = WireFields(
  requiredFields: <String>[previewKindField, 'text'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _imageFields = WireFields(
  requiredFields: <String>[
    previewKindField,
    'width',
    'height',
    'base64_content',
  ],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _kindOnlyFields = WireFields(
  requiredFields: <String>[previewKindField],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

WireFields _readPreviewFields(JsonObject json) {
  return switch (json[previewKindField]) {
    TextPreview.kind => _textFields,
    ImagePreview.kind => _imageFields,
    _ => _kindOnlyFields,
  };
}

String _readExpectedKind(FilePreview preview) {
  return switch (preview) {
    TextPreview() => 'text',
    ImagePreview() => 'image',
    TooLargePreview() => 'too_large',
    BinaryPreview() => 'binary',
    LinkPreview() => 'link',
  };
}

ImagePreview _randomImagePreview(Random random) {
  return ImagePreview(
    width: randomWholeNumber(random),
    height: randomWholeNumber(random),
    base64Content: base64Encode(randomBytes(random)),
  );
}

void main() {
  test('test_file_preview_from_json_property_kind_picks_the_variant', () {
    final Random random = seededRandom(52601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomFilePreviewJson(random);

      final FilePreview preview = FilePreview.fromJson(
        withUnknownFields(random, json),
      );

      expect(_readExpectedKind(preview), json[previewKindField]);
      switch (preview) {
        case TextPreview():
          expect(preview.text, json['text']);
        case ImagePreview():
          expect(preview.width, json['width']);
          expect(preview.height, json['height']);
          expect(preview.base64Content, json['base64_content']);
        case TooLargePreview() || BinaryPreview() || LinkPreview():
          expect(decodeObject(preview.toJson()).keys.toSet(), _onlyKind);
      }
    }
  });

  test('test_file_preview_from_json_property_unknown_kinds_raise_format', () {
    final Random random = seededRandom(52602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomFilePreviewJson(random);
      final String kind = json[previewKindField]!.toString();

      for (final String nearMiss in nearMissWireNames(random, kind, 'Text')) {
        if (filePreviewKinds.contains(nearMiss)) {
          continue;
        }
        final JsonObject renamed = withFieldValue(
          json,
          previewKindField,
          nearMiss,
        );
        expect(() => FilePreview.fromJson(renamed), throwsFormatException);
      }
    }
  });

  test('test_file_preview_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomFilePreviewJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _readPreviewFields(json),
        FilePreview.fromJson,
      );
    }
  });

  test('test_file_preview_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52604);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomFilePreviewJson(random),
        FilePreview.fromJson,
      );
    }
  });

  test('test_text_preview_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = TextPreview(text: randomText(random))
          .toJson();

      expect(encoded.keys.toSet(), equals(_textFields.everyField));
      expect(encoded[previewKindField], TextPreview.kind);
    }
  });

  test('test_text_preview_to_json_property_keeps_the_text_exactly', () {
    final Random random = seededRandom(52606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text =
          randomText(random) + _hostileTextMiddle + randomText(random);

      final JsonObject encoded = TextPreview(text: text).toJson();

      expect(encoded['text'], text);
    }
  });

  test('test_text_preview_to_json_property_decodes_back_to_text', () {
    final Random random = seededRandom(52607);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectDecodesToSameFilePreview(
        random,
        TextPreview(text: randomText(random)),
      );
    }
  });

  test('test_image_preview_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomImagePreview(random).toJson();

      expect(encoded.keys.toSet(), equals(_imageFields.everyField));
      expect(encoded[previewKindField], ImagePreview.kind);
    }
  });

  test('test_image_preview_to_json_property_keeps_size_and_content', () {
    final Random random = seededRandom(52609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ImagePreview preview = _randomImagePreview(random);

      final JsonObject encoded = decodeObject(preview.toJson());

      expect(encoded['width'], preview.width);
      expect(encoded['height'], preview.height);
      expect(encoded['base64_content'], preview.base64Content);
    }
  });

  test('test_image_preview_to_json_property_decodes_back_to_an_image', () {
    final Random random = seededRandom(52610);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectDecodesToSameFilePreview(random, _randomImagePreview(random));
    }
  });
}
