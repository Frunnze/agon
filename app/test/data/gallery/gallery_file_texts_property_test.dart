import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
const String _headerChunkType = 'IHDR';
const String _endChunkType = 'IEND';
const int _chunkTypeOffset = 12;
const int _chunkTypeLength = 4;
const int _endChunkLength = 12;
const String _jsonExtension = '.json';
const String _lineEnding = '\n';

final List<String> _galleryTexts = <String>[
  galleryReadmeText,
  galleryRedirectText,
  galleryLoginText,
  gallerySessionText,
  galleryAppText,
  galleryIndexText,
  galleryIgnoreText,
  galleryPackageText,
  galleryTypeScriptSettingsText,
  galleryWorkflowText,
  galleryGradleText,
  galleryPodText,
  galleryButtonText,
  galleryHomeText,
];

String _readChunkType(Uint8List bytes, int offset) {
  final Uint8List typeBytes = Uint8List.sublistView(
    bytes,
    offset,
    offset + _chunkTypeLength,
  );
  return ascii.decode(typeBytes);
}

List<String> _listShownTexts() {
  return <String>[
    for (final FakeRepositoryFile file in galleryRepositoryFiles)
      if (file.preview case TextFilePreview(:final String text)) text,
  ];
}

void main() {
  test('test_gallery_icon_bytes_property_start_with_the_png_signature', () {
    final List<int> start = galleryIconBytes.sublist(0, _pngSignature.length);

    expect(start, _pngSignature);
  });

  test('test_gallery_icon_bytes_property_header_chunk_comes_first', () {
    final String firstChunk = _readChunkType(
      galleryIconBytes,
      _chunkTypeOffset,
    );

    expect(firstChunk, _headerChunkType);
  });

  test('test_gallery_icon_bytes_property_end_with_the_end_chunk', () {
    final int endChunkStart = galleryIconBytes.length - _endChunkLength;
    final String lastChunk = _readChunkType(
      galleryIconBytes,
      endChunkStart + _chunkTypeLength,
    );

    expect(lastChunk, _endChunkType);
  });

  test('test_gallery_texts_property_end_with_one_line_break', () {
    for (final String text in _galleryTexts) {
      expect(text, endsWith(_lineEnding));
      expect(text.trim(), isNotEmpty);
      expect(text.endsWith('$_lineEnding$_lineEnding'), isFalse);
    }
  });

  test('test_gallery_texts_property_json_files_hold_json', () {
    for (final FakeRepositoryFile file in galleryRepositoryFiles) {
      if (!file.path.endsWith(_jsonExtension)) {
        continue;
      }
      final FilePreview preview = file.preview;
      final String text = (preview as TextFilePreview).text;

      expect(jsonDecode(text), isA<Map<String, Object?>>(), reason: file.path);
    }
  });

  test('test_gallery_texts_property_every_text_is_shown_by_a_file', () {
    final List<String> shownTexts = _listShownTexts();

    for (final String text in _galleryTexts) {
      expect(shownTexts, contains(text));
    }
  });
}
