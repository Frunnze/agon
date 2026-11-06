import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import 'wire_contract_checks.dart';

const String previewKindField = 'kind';

const List<String> filePreviewKinds = <String>[
  'text',
  'image',
  'too_large',
  'binary',
  'link',
];

void expectDecodesToSameFilePreview(Random random, FilePreview preview) {
  final JsonObject reencoded = decodeObject(reencodeThroughText(preview));
  final FilePreview reread = FilePreview.fromJson(
    withUnknownFields(random, reencoded),
  );

  expect(reread.runtimeType, preview.runtimeType);
  expectPlainJsonThatDecodesBack(preview, FilePreview.fromJson);
}
