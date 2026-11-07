import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/commands/run_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_run_json.dart';
import '../support/wire_contract_checks.dart';

const int _firstSeed = 6069200;
const String _linkField = 'link';
const String _linkLostAtField = 'link_lost_at';
const String _runField = 'run';

ShowRunCommand _randomShowRunCommand(Random random) {
  return ShowRunCommand(runId: RunId(randomHostileText(random)));
}

RunView _decodeRunView(ShowRunCommand command, Object? replyJson) {
  return command.decodeReply(rereadThroughWire(replyJson));
}

void main() {
  test('test_show_run_command_decode_reply_property_'
      'takes_the_live_link_over_the_stored_one', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomRunViewJson(random);
      final JsonObject storedRunJson = replyJson[_runField]! as JsonObject;
      storedRunJson[_linkField] = pickOne(random, nodeRunnerLinks);
      storedRunJson[_linkLostAtField] = randomOptional(
        random,
        randomMomentText,
      );

      final RunView runView = _decodeRunView(
        _randomShowRunCommand(random),
        replyJson,
      );
      final JsonObject viewJson = runView.toJson();

      expect(viewJson[_linkField], replyJson[_linkField]);
      expect(viewJson[_linkLostAtField], replyJson[_linkLostAtField]);
      expect(runView.run.link.wireName, storedRunJson[_linkField]);
    }
  });

  test('test_show_run_command_decode_reply_property_'
      'a_left_out_link_loss_means_the_link_was_never_lost', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomRunViewJson(random);
      final JsonObject trimmed = withoutField(replyJson, _linkLostAtField);
      final JsonObject nulled = withFieldValue(
        replyJson,
        _linkLostAtField,
        null,
      );
      final ShowRunCommand command = _randomShowRunCommand(random);

      expect(_decodeRunView(command, trimmed).linkLostAt, isNull);
      expect(_decodeRunView(command, nulled).linkLostAt, isNull);
    }
  });

  test('test_show_run_command_decode_reply_property_'
      'rejects_a_link_the_node_never_sends', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomRunViewJson(random);
      final String knownLink = pickOne(random, nodeRunnerLinks);
      final List<Object?> unknownLinks = <Object?>[
        knownLink.toUpperCase(),
        ' $knownLink',
        '$knownLink\n',
        randomHostileText(random),
        random.nextBool(),
      ];
      final Object? unknownLink = pickOne(random, unknownLinks);
      if (nodeRunnerLinks.contains(unknownLink)) {
        continue;
      }
      final JsonObject brokenReply = withFieldValue(
        replyJson,
        _linkField,
        unknownLink,
      );

      expect(
        () => _decodeRunView(_randomShowRunCommand(random), brokenReply),
        throwsFormatException,
        reason: '$unknownLink',
      );
    }
  });
}
