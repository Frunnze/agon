import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';

import '../../support/random_inputs.dart';
import '../support/all_command_shapes.dart';
import '../support/arbitrary_json.dart';
import '../support/command_shape.dart';
import '../support/decoding_outcome.dart';
import '../support/random_typed_values.dart';

const int _firstSeed = 4700;

const Set<String> _nodeTaskArgumentFields = <String>{
  'workspace_id',
  'project_id',
  'title',
  'details',
  'doer',
  'runs_on',
  'skills',
  'uses_automatic_skills',
  'approval_policy',
};

void main() {
  test('test_command_shapes_property_cover_every_node_command', () {
    final List<String> shapeNames = <String>[];
    for (final CommandShape shape in allCommandShapes) {
      shapeNames.add(shape.commandName);
    }

    expect(shapeNames.toSet(), equals(nodeCommandNames.toSet()));
    expect(shapeNames.length, nodeCommandNames.length);
  });

  for (int index = 0; index < allCommandShapes.length; index += 1) {
    final CommandShape shape = allCommandShapes[index];
    final String commandName = shape.commandName;

    test('test_encode_${commandName}_property_sends_node_fields_only', () {
      final Random random = seededRandom(_firstSeed + index);

      for (int i = 0; i < propertyIterations; i += 1) {
        final NodeCommand<Object?> command = shape.buildCommand(random);
        final JsonObject encoded = encodeNodeCommand(command);
        final Set<String> argumentFields = encoded.keys.toSet()
          ..remove(commandNameField);

        expect(encoded[commandNameField], commandName);
        expect(argumentFields, equals(shape.argumentFields));
        expect(jsonDecode(jsonEncode(encoded)), equals(encoded));
      }
    });

    test(
      'test_decode_${commandName}_reply_property_round_trips_node_json',
      () {
        final Random random = seededRandom(_firstSeed + index);

        for (int i = 0; i < propertyIterations; i += 1) {
          final NodeCommand<Object?> command = shape.buildCommand(random);
          final Object? replyJson = shape.buildReplyJson(random);

          final Object? decoded = command.decodeReply(replyJson);
          final Object? encodedAgain = shape.encodeReply(decoded);

          expect(jsonDecode(jsonEncode(encodedAgain)), equals(replyJson));
        }
      },
    );

    test('test_decode_${commandName}_reply_property_fuzz_raises_format', () {
      final Random random = seededRandom(_firstSeed + index);

      for (int i = 0; i < propertyIterations; i += 1) {
        final NodeCommand<Object?> command = shape.buildCommand(random);
        final Object? mutatedReply = mutateJson(
          random,
          shape.buildReplyJson(random),
        );

        expect(
          attemptDecoding(() => command.decodeReply(mutatedReply)),
          isIn(DecodingOutcome.values),
        );
      }
    });
  }

  test('test_task_arguments_to_json_property_sends_node_task_fields', () {
    final Random random = seededRandom(4790);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskArguments arguments = randomTaskArguments(random);
      final JsonObject encoded = arguments.toJson();

      expect(encoded.keys.toSet(), equals(_nodeTaskArgumentFields));
      expect(encoded['workspace_id'], arguments.workspaceId.value);
      expect(encoded['skills'], equals(arguments.skills));
    }
  });
}
