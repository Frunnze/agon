import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/file_preview_checks.dart';

void _expectKindOnlyEncoding(Random random, FilePreview preview, String kind) {
  final JsonObject encoded = decodeObject(preview.toJson());
  encoded[randomText(random)] = randomArbitraryJson(random);

  expect(preview.toJson(), equals(<String, Object?>{previewKindField: kind}));
}

void _expectKindDiffersFromOtherPreviews(FilePreview preview) {
  final List<FilePreview> previews = <FilePreview>[
    const TextPreview(text: ''),
    const ImagePreview(width: 1, height: 1, base64Content: ''),
    const TooLargePreview(),
    const BinaryPreview(),
    const LinkPreview(),
  ];
  final Object? kind = decodeObject(preview.toJson())[previewKindField];

  int sharingCount = 0;
  for (final FilePreview other in previews) {
    if (decodeObject(other.toJson())[previewKindField] == kind) {
      sharingCount += 1;
    }
  }

  expect(sharingCount, 1);
  expect(filePreviewKinds, contains(kind));
}

void main() {
  test('test_too_large_preview_to_json_property_writes_only_its_kind', () {
    final Random random = seededRandom(52611);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectKindOnlyEncoding(random, const TooLargePreview(), 'too_large');
    }
  });

  test(
    'test_too_large_preview_to_json_property_decodes_back_to_too_large',
    () {
      final Random random = seededRandom(52614);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectDecodesToSameFilePreview(random, const TooLargePreview());
      }
    },
  );

  test('test_too_large_preview_to_json_property_kind_differs_from_others', () {
    _expectKindDiffersFromOtherPreviews(const TooLargePreview());
  });

  test('test_binary_preview_to_json_property_writes_only_its_kind', () {
    final Random random = seededRandom(52612);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectKindOnlyEncoding(random, const BinaryPreview(), 'binary');
    }
  });

  test('test_binary_preview_to_json_property_decodes_back_to_binary', () {
    final Random random = seededRandom(52615);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectDecodesToSameFilePreview(random, const BinaryPreview());
    }
  });

  test('test_binary_preview_to_json_property_kind_differs_from_others', () {
    _expectKindDiffersFromOtherPreviews(const BinaryPreview());
  });

  test('test_link_preview_to_json_property_writes_only_its_kind', () {
    final Random random = seededRandom(52613);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectKindOnlyEncoding(random, const LinkPreview(), 'link');
    }
  });

  test('test_link_preview_to_json_property_decodes_back_to_link', () {
    final Random random = seededRandom(52616);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectDecodesToSameFilePreview(random, const LinkPreview());
    }
  });

  test('test_link_preview_to_json_property_kind_differs_from_others', () {
    _expectKindDiffersFromOtherPreviews(const LinkPreview());
  });
}
