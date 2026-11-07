import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_file_json.dart';
import '../../../bridge/support/random_wire_values.dart';
import '../../../support/random_inputs.dart';

const String _textWireKind = 'text';
const String _imageWireKind = 'image';
const Map<PreviewUnavailableReason, String> _unavailableWireKinds =
    <PreviewUnavailableReason, String>{
      PreviewUnavailableReason.tooLarge: 'too_large',
      PreviewUnavailableReason.binary: 'binary',
      PreviewUnavailableReason.link: 'link',
    };

String _describePreviewWireKind(FilePreview preview) {
  return switch (preview) {
    TextFilePreview() => _textWireKind,
    ImageFilePreview() => _imageWireKind,
    UnavailableFilePreview(:final PreviewUnavailableReason reason) =>
      _unavailableWireKinds[reason]!,
  };
}

node.FilePreview _randomNodePreview(Random random) {
  return node.FilePreview.fromJson(randomFilePreviewJson(random));
}

void main() {
  test('test_map_file_preview_from_node_property_image_bytes_round_trip', () {
    final Random random = seededRandom(72208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> sourceBytes = randomBytes(random);
      final String content = base64Encode(sourceBytes);

      final FilePreview preview = mapFilePreviewFromNode(
        node.ImagePreview(width: 1, height: 1, base64Content: content),
      );

      final ImageFilePreview image = preview as ImageFilePreview;
      expect(image.bytes, orderedEquals(sourceBytes));
      expect(base64Encode(image.bytes), content);
    }
  });

  test('test_map_file_preview_from_node_property_image_bytes_are_frozen', () {
    final Random random = seededRandom(72209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> sourceBytes = <int>[...randomBytes(random), 7];
      final FilePreview preview = mapFilePreviewFromNode(
        node.ImagePreview(
          width: 1 + random.nextInt(100),
          height: 1 + random.nextInt(100),
          base64Content: base64Encode(sourceBytes),
        ),
      );

      final ImageFilePreview image = preview as ImageFilePreview;
      expect(() => image.bytes[0] = 0, throwsUnsupportedError);
      expect(image.bytes, orderedEquals(sourceBytes));
    }
  });

  test('test_map_repository_file_from_node_property_round_trips_json', () {
    final Random random = seededRandom(72210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRepositoryFileJson(random);
      final node.RepositoryFileView view = node.RepositoryFileView.fromJson(
        json,
      );

      final RepositoryFile file = mapRepositoryFileFromNode(view);

      final JsonObject previewJson = decodeObject(json['preview']);
      expect(file.path, json['path']);
      expect(file.size, json['size']);
      expect(_describePreviewWireKind(file.preview), previewJson['kind']);
      final FilePreview preview = file.preview;
      if (preview is ImageFilePreview) {
        expect(base64Encode(preview.bytes), previewJson['base64_content']);
      }
    }
  });

  test('test_map_repository_file_from_node_property_keeps_hostile_paths', () {
    final Random random = seededRandom(72211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomHostileText(random);
      final int size = randomWholeNumber(random);
      final node.FilePreview wirePreview = _randomNodePreview(random);

      final RepositoryFile file = mapRepositoryFileFromNode(
        node.RepositoryFileView(path: path, size: size, preview: wirePreview),
      );

      expect(file.path, path);
      expect(file.size, size);
      expect(
        _describePreviewWireKind(file.preview),
        decodeObject(wirePreview.toJson())['kind'],
      );
    }
  });
}
