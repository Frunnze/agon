import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestByte = 256;
const int _largestSide = 1 << 14;
const int _largestSafeInteger = 9007199254740991;

const Map<String, node.FilePreview> _unavailableNodePreviews =
    <String, node.FilePreview>{
      node.TooLargePreview.kind: node.TooLargePreview(),
      node.BinaryPreview.kind: node.BinaryPreview(),
      node.LinkPreview.kind: node.LinkPreview(),
    };

Uint8List _randomImageBytes(Random random) {
  return Uint8List.fromList(randomBytes(random));
}

FilePreview _randomPreview(Random random) {
  return pickOne<FilePreview>(random, <FilePreview>[
    TextFilePreview(randomHostileText(random)),
    ImageFilePreview(
      width: random.nextInt(_largestSide),
      height: random.nextInt(_largestSide),
      bytes: _randomImageBytes(random),
    ),
    UnavailableFilePreview(pickOne(random, PreviewUnavailableReason.values)),
  ]);
}

ImageFilePreview _randomImagePreview(Random random, Uint8List bytes) {
  return ImageFilePreview(
    width: random.nextInt(_largestSide),
    height: random.nextInt(_largestSide),
    bytes: bytes,
  );
}

PreviewUnavailableReason _mapUnavailableReason(node.FilePreview preview) {
  final FilePreview mapped = mapFilePreviewFromNode(preview);
  return (mapped as UnavailableFilePreview).reason;
}

String _writeInSnakeCase(String camelCaseName) {
  final StringBuffer snakeCaseName = StringBuffer();
  for (final String letter in camelCaseName.split('')) {
    final String lowerLetter = letter.toLowerCase();
    if (letter != lowerLetter) {
      snakeCaseName.write('_');
    }
    snakeCaseName.write(lowerLetter);
  }
  return snakeCaseName.toString();
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<RepositoryFile>(
      testNamePrefix: 'test_repository_file_constructor_property',
      seed: 691601,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        pickOne(random, <int>[0, _largestSafeInteger, random.nextInt(99)]),
        _randomPreview(random),
      ],
      construct: (ModelFieldValues fieldValues) => RepositoryFile(
        path: fieldValues[0]! as String,
        size: fieldValues[1]! as int,
        preview: fieldValues[2]! as FilePreview,
      ),
      readFieldValues: (RepositoryFile file) => <Object?>[
        file.path,
        file.size,
        file.preview,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<TextFilePreview>(
      testNamePrefix: 'test_text_file_preview_constructor_property',
      seed: 691611,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          TextFilePreview(fieldValues[0]! as String),
      readFieldValues: (TextFilePreview preview) => <Object?>[preview.text],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ImageFilePreview>(
      testNamePrefix: 'test_image_file_preview_constructor_property',
      seed: 691621,
      randomFieldValues: (Random random) => <Object?>[
        random.nextInt(_largestSide),
        random.nextInt(_largestSide),
        _randomImageBytes(random),
      ],
      construct: (ModelFieldValues fieldValues) => ImageFilePreview(
        width: fieldValues[0]! as int,
        height: fieldValues[1]! as int,
        bytes: fieldValues[2]! as Uint8List,
      ),
      readFieldValues: (ImageFilePreview preview) => <Object?>[
        preview.width,
        preview.height,
        preview.bytes,
      ],
    ),
  );

  test('test_image_file_preview_constructor_property_bytes_are_a_copy', () {
    final Random random = seededRandom(691631);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Uint8List givenBytes = Uint8List.fromList(<int>[
        random.nextInt(_largestByte),
        ...randomBytes(random),
      ]);
      final List<int> bytesAtConstruction = List<int>.of(givenBytes);
      final ImageFilePreview preview = _randomImagePreview(random, givenBytes);

      givenBytes[0] = (givenBytes[0] + 1) % _largestByte;
      givenBytes.fillRange(0, givenBytes.length, random.nextInt(_largestByte));

      expect(preview.bytes, orderedEquals(bytesAtConstruction));
    }
  });

  test('test_image_file_preview_constructor_property_bytes_refuse_edits', () {
    final Random random = seededRandom(691632);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Uint8List givenBytes = Uint8List.fromList(<int>[
        random.nextInt(_largestByte),
        ...randomBytes(random),
      ]);
      final ImageFilePreview preview = _randomImagePreview(random, givenBytes);
      final Uint8List storedBytes = preview.bytes;

      expect(() => storedBytes[0] = 0, throwsUnsupportedError);
      expect(() => storedBytes.fillRange(0, 1, 0), throwsUnsupportedError);
      expect(storedBytes, orderedEquals(givenBytes));
    }
  });

  testModelConstructorProperties(
    ModelConstructor<UnavailableFilePreview>(
      testNamePrefix: 'test_unavailable_file_preview_constructor_property',
      seed: 691641,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, PreviewUnavailableReason.values),
      ],
      construct: (ModelFieldValues fieldValues) =>
          UnavailableFilePreview(fieldValues[0]! as PreviewUnavailableReason),
      readFieldValues: (UnavailableFilePreview preview) => <Object?>[
        preview.reason,
      ],
    ),
  );

  test('test_preview_unavailable_reason_values_property_each_has_its_own', () {
    final Set<PreviewUnavailableReason> reasons = <PreviewUnavailableReason>{};

    for (final node.FilePreview preview in _unavailableNodePreviews.values) {
      reasons.add(_mapUnavailableReason(preview));
    }

    expect(reasons, hasLength(_unavailableNodePreviews.length));
  });

  test(
    'test_preview_unavailable_reason_values_property_every_one_reached',
    () {
      final Set<PreviewUnavailableReason> reasons =
          <PreviewUnavailableReason>{};

      for (final node.FilePreview preview in _unavailableNodePreviews.values) {
        reasons.add(_mapUnavailableReason(preview));
      }

      expect(reasons, unorderedEquals(PreviewUnavailableReason.values));
    },
  );

  test('test_preview_unavailable_reason_values_property_keeps_node_kind', () {
    for (final MapEntry<String, node.FilePreview> entry
        in _unavailableNodePreviews.entries) {
      final PreviewUnavailableReason reason = _mapUnavailableReason(
        entry.value,
      );

      expect(_writeInSnakeCase(reason.name), entry.key);
    }
  });
}
