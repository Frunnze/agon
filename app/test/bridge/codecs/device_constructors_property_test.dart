import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import 'support/codec_rows.dart';
import 'support/device_codec_rows.dart';

const int _firstSeed = 9350000;
const int _markdownSeed = 9359000;
const String _markdownField = 'markdown';
const String _strayField = 'stray';

void main() {
  testConstructorRows(rows: deviceConstructorRows, firstSeed: _firstSeed);

  test(
    'test_agents_markdown_view_to_json_property_edits_never_reach_the_view',
    () {
      final Random random = seededRandom(_markdownSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String markdown = randomHostileText(random);
        final AgentsMarkdownView view = AgentsMarkdownView(markdown: markdown);
        final JsonObject firstJson = view.toJson();

        firstJson[_markdownField] = randomHostileText(random);
        firstJson[_strayField] = randomHostileText(random);

        expect(view.markdown, markdown);
        expect(
          view.toJson(),
          equals(<String, Object?>{_markdownField: markdown}),
        );
      }
    },
  );
}
