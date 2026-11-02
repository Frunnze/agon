import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/decoding_outcome.dart';
import '../../bridge/support/random_file_json.dart';
import '../../support/random_inputs.dart';

const String _malformedBase64 = 'not base64 %%';

const Map<String, PreviewUnavailableReason> _unavailableReasons =
    <String, PreviewUnavailableReason>{
      'too_large': PreviewUnavailableReason.tooLarge,
      'binary': PreviewUnavailableReason.binary,
      'link': PreviewUnavailableReason.link,
    };

void _expectAvailableSource(JsonObject json, FilesFromRunner source) {
  final JsonObject runner = decodeObject(json['runner']);
  expect(json['kind'], 'available');
  expect(source.runnerId.value, runner['device_id']);
  expect(source.runnerName, runner['name']);
  expect(source.branches, equals(json['branches']));
  expect(source.taskBranches, equals(json['task_branches']));
}

void _expectUnavailableSource(JsonObject json, FilesWithoutRunner source) {
  final List<Object?> holders = json['holders']! as List<Object?>;
  expect(json['kind'], 'unavailable');
  expect(source.holders.length, holders.length);
  for (int index = 0; index < holders.length; index += 1) {
    final JsonObject holder = decodeObject(holders[index]);
    final RepositoryHolder mapped = source.holders[index];
    expect(mapped.deviceId.value, holder['device_id']);
    expect(mapped.name, holder['name']);
    expect(mapped.lastSeen, decodeMoment(holder['last_seen']));
  }
}

void _expectPreview(JsonObject json, FilePreview preview) {
  switch (preview) {
    case TextFilePreview(:final String text):
      expect(json['kind'], 'text');
      expect(text, json['text']);
    case ImageFilePreview():
      expect(json['kind'], 'image');
      expect(preview.width, json['width']);
      expect(preview.height, json['height']);
      final String content = decodeText(json['base64_content']);
      expect(preview.bytes, equals(base64Decode(content)));
    case UnavailableFilePreview(:final PreviewUnavailableReason reason):
      expect(reason, _unavailableReasons[json['kind']]);
  }
}

void main() {
  test('test_map_repository_file_source_from_node_property_keeps_choice', () {
    final Random random = seededRandom(9601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRepositoryBranchesJson(random);
      final RepositoryFileSource source = mapRepositoryFileSourceFromNode(
        node.RepositoryBranchesView.fromJson(json),
      );
      switch (source) {
        case FilesFromRunner():
          _expectAvailableSource(json, source);
        case FilesWithoutRunner():
          _expectUnavailableSource(json, source);
      }
    }
  });

  test('test_map_repository_entry_from_node_property_keeps_fields', () {
    final Random random = seededRandom(9602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRepositoryEntryJson(random);
      final RepositoryEntry entry = mapRepositoryEntryFromNode(
        node.RepositoryEntry.fromJson(json),
      );
      expect(entry.name, json['name']);
      expect(entry.kind.name, json['kind']);
      expect(entry.size, json['size']);
    }
  });

  test('test_map_file_preview_from_node_property_keeps_content', () {
    final Random random = seededRandom(9603);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomFilePreviewJson(random);
      final FilePreview preview = mapFilePreviewFromNode(
        node.FilePreview.fromJson(json),
      );
      _expectPreview(json, preview);
    }
  });

  test('test_map_repository_file_from_node_property_keeps_path_size', () {
    final Random random = seededRandom(9604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRepositoryFileJson(random);
      final RepositoryFile file = mapRepositoryFileFromNode(
        node.RepositoryFileView.fromJson(json),
      );
      expect(file.path, json['path']);
      expect(file.size, json['size']);
      _expectPreview(decodeObject(json['preview']), file.preview);
    }
  });

  test('test_map_file_preview_from_node_property_bad_base64_is_format', () {
    final Random random = seededRandom(9605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.FilePreview preview = node.FilePreview.fromJson(
        <String, Object?>{
          'kind': 'image',
          'width': 1 + random.nextInt(100),
          'height': 1 + random.nextInt(100),
          'base64_content': '$_malformedBase64${randomText(random)}',
        },
      );
      expect(
        attemptDecoding(() => mapFilePreviewFromNode(preview)),
        DecodingOutcome.rejectedAsMalformed,
      );
    }
  });
}
