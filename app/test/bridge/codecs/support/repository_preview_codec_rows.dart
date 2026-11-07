import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_file_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> repositoryPreviewConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'file_preview',
      buildJson: randomFilePreviewJson,
      decode: FilePreview.fromJson,
    ),
    rebuild: _rebuildFilePreview,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'text_preview',
      buildJson: randomTextPreviewJson,
      decode: FilePreview.fromJson,
    ),
    rebuild: _rebuildFilePreview,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'image_preview',
      buildJson: randomImagePreviewJson,
      decode: FilePreview.fromJson,
    ),
    rebuild: _rebuildFilePreview,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'too_large_preview',
      buildJson: randomTooLargePreviewJson,
      decode: FilePreview.fromJson,
    ),
    rebuild: _rebuildFilePreview,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'binary_preview',
      buildJson: randomBinaryPreviewJson,
      decode: FilePreview.fromJson,
    ),
    rebuild: _rebuildFilePreview,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'link_preview',
      buildJson: randomLinkPreviewJson,
      decode: FilePreview.fromJson,
    ),
    rebuild: _rebuildFilePreview,
  ),
];

Object? randomTextPreviewJson(Random random) {
  return randomJsonOfKind<TextPreview>(
    random: random,
    buildJson: randomFilePreviewJson,
    decode: FilePreview.fromJson,
  );
}

Object? randomImagePreviewJson(Random random) {
  return randomJsonOfKind<ImagePreview>(
    random: random,
    buildJson: randomFilePreviewJson,
    decode: FilePreview.fromJson,
  );
}

Object? randomTooLargePreviewJson(Random random) {
  return randomJsonOfKind<TooLargePreview>(
    random: random,
    buildJson: randomFilePreviewJson,
    decode: FilePreview.fromJson,
  );
}

Object? randomBinaryPreviewJson(Random random) {
  return randomJsonOfKind<BinaryPreview>(
    random: random,
    buildJson: randomFilePreviewJson,
    decode: FilePreview.fromJson,
  );
}

Object? randomLinkPreviewJson(Random random) {
  return randomJsonOfKind<LinkPreview>(
    random: random,
    buildJson: randomFilePreviewJson,
    decode: FilePreview.fromJson,
  );
}

JsonEncodable _rebuildFilePreview(JsonEncodable value) {
  final FilePreview preview = value as FilePreview;
  return switch (preview) {
    TextPreview(:final String text) => TextPreview(text: text),
    ImagePreview(
      :final int width,
      :final int height,
      :final String base64Content,
    ) =>
      ImagePreview(width: width, height: height, base64Content: base64Content),
    TooLargePreview() => const TooLargePreview(),
    BinaryPreview() => const BinaryPreview(),
    LinkPreview() => const LinkPreview(),
  };
}
