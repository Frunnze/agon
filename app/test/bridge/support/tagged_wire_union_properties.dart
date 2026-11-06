import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';
import 'hostile_texts.dart';
import 'node_shapes.dart' show NodeValueDecoder;
import 'wire_json_edits.dart';

typedef TaggedWireJsonBuilder = JsonObject Function(Random random);

typedef VariantTagReader = String Function(JsonEncodable value);

const String _wordSeparator = '_';

final class TaggedWireUnion {
  const TaggedWireUnion({
    required this.typeName,
    required this.seed,
    required this.tagField,
    required this.nodeTags,
    required this.buildJson,
    required this.decode,
    required this.readVariantTag,
  });

  final String typeName;
  final int seed;
  final String tagField;
  final List<String> nodeTags;
  final TaggedWireJsonBuilder buildJson;
  final NodeValueDecoder decode;
  final VariantTagReader readVariantTag;
}

void testTaggedWireUnionProperties(TaggedWireUnion union) {
  test('test_${union.typeName}_from_json_property_tag_picks_the_variant', () {
    final Random random = seededRandom(union.seed);
    final Set<String> reachedTags = <String>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = union.buildJson(random);

      final JsonEncodable decoded = union.decode(wireJson);

      expect(union.readVariantTag(decoded), wireJson[union.tagField]);
      reachedTags.add(union.readVariantTag(decoded));
    }

    expect(reachedTags, equals(union.nodeTags.toSet()));
  });

  test('test_${union.typeName}_from_json_property_rejects_unknown_tags', () {
    final Random random = seededRandom(union.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = union.buildJson(random);
      final String knownTag = pickOne(random, union.nodeTags);
      final String unknownTag = pickOne(
        random,
        _listTagsNearTo(random, knownTag),
      );
      if (union.nodeTags.contains(unknownTag)) {
        continue;
      }

      final JsonObject brokenJson = replaceWireField(
        wireJson,
        union.tagField,
        unknownTag,
      );

      expect(() => union.decode(brokenJson), throwsFormatException);
    }
  });

  test('test_${union.typeName}_from_json_property_'
      'rejects_a_missing_or_non_text_tag', () {
    final Random random = seededRandom(union.seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = union.buildJson(random);
      final Object? arbitraryTag = randomArbitraryJson(random);
      final JsonObject untaggedJson = removeWireField(
        wireJson,
        union.tagField,
      );

      expect(() => union.decode(untaggedJson), throwsFormatException);
      if (arbitraryTag is String) {
        continue;
      }
      final JsonObject wronglyTaggedJson = replaceWireField(
        wireJson,
        union.tagField,
        arbitraryTag,
      );
      expect(() => union.decode(wronglyTaggedJson), throwsFormatException);
    }
  });
}

List<String> _listTagsNearTo(Random random, String knownTag) {
  return <String>[
    knownTag.toUpperCase(),
    ' $knownTag',
    '$knownTag ',
    '$knownTag​',
    '${knownTag}s',
    knownTag.substring(1),
    knownTag.replaceAll(_wordSeparator, '-'),
    knownTag.replaceAll(_wordSeparator, ''),
    '',
    randomHostileText(random),
  ];
}
