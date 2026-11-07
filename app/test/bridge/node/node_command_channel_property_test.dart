import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/all_command_shapes.dart';
import '../support/arbitrary_json.dart';
import '../support/command_shape.dart';
import '../support/hostile_texts.dart';
import '../support/scripted_node_transport.dart';

const int _firstSeed = 6274000;
const int _largestConcurrentCalls = 10;

String _echoTheCommand(String inputJson) {
  return encodeSuccessReply(jsonDecode(inputJson));
}

JsonObject _randomWireCommand(Random random) {
  return <String, Object?>{
    commandNameField: randomHostileText(random),
    'argument': randomArbitraryJson(random),
  };
}

List<String> _randomMalformedReplies(Random random) {
  return <String>[
    randomHostileText(random),
    jsonEncode(<Object?>[randomArbitraryJson(random)]),
    jsonEncode(<String, Object?>{'answer': randomArbitraryJson(random)}),
    jsonEncode(<String, Object?>{'error': random.nextInt(1 << 31)}),
  ];
}

void main() {
  test('test_node_command_channel_constructor_property_keeps_transport', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String reply = encodeSuccessReply(randomArbitraryJson(random));
      final NodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => reply,
      );

      final NodeCommandChannel channel = NodeCommandChannel(
        transport: transport,
      );

      expect(identical(channel.transport, transport), isTrue);
    }
  });

  test('test_node_command_channel_constructor_property_sends_nothing', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: _echoTheCommand,
      );

      NodeCommandChannel(transport: transport);

      expect(transport.exchanges, isEmpty);
      expect(transport.stopRequests, 0);
    }
  });

  test('test_node_command_channel_constructor_property_shares_transport', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: _echoTheCommand,
      );
      final int channelCount = 1 + random.nextInt(_largestConcurrentCalls);
      final List<NodeCommandChannel> channels = <NodeCommandChannel>[];
      for (int channel = 0; channel < channelCount; channel += 1) {
        channels.add(NodeCommandChannel(transport: transport));
      }

      for (final NodeCommandChannel channel in channels) {
        expect(identical(channel.transport, transport), isTrue);
      }
    }
  });

  test('test_send_property_concurrent_replies_stay_paired', () async {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(answer: _echoTheCommand),
      );
      final int callCount = 1 + random.nextInt(_largestConcurrentCalls);
      final List<JsonObject> commands = <JsonObject>[];
      for (int call = 0; call < callCount; call += 1) {
        commands.add(_randomWireCommand(random));
      }

      final List<Object?> replies = await Future.wait(<Future<Object?>>[
        for (final JsonObject command in commands) channel.send(command),
      ]);

      expect(replies, equals(rereadThroughWire(commands)));
    }
  });

  test('test_send_property_transport_problems_pass_through', () async {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(
          answer: (String inputJson) => throw StateError(problem),
        ),
      );

      await expectLater(
        channel.send(_randomWireCommand(random)),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            problem,
          ),
        ),
      );
    }
  });

  test('test_send_property_malformed_replies_raise_format_errors', () async {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String reply = pickOne(random, _randomMalformedReplies(random));
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(answer: (String inputJson) => reply),
      );

      await expectLater(
        channel.send(_randomWireCommand(random)),
        throwsFormatException,
        reason: reply,
      );
    }
  });

  test('test_execute_property_refusals_skip_decoding', () async {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CommandShape shape = pickOne(random, allCommandShapes);
      final String message = randomHostileText(random);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeErrorReply(message),
      );

      await expectLater(
        NodeCommandChannel(transport: transport)
            .execute(shape.buildCommand(random)),
        throwsA(
          isA<NodeCommandFailure>().having(
            (NodeCommandFailure failure) => failure.message,
            'message',
            message,
          ),
        ),
      );
      expect(transport.exchanges, hasLength(1));
    }
  });

  test(
    'test_execute_property_undecodable_replies_raise_format_errors',
    () async {
      final Random random = seededRandom(_firstSeed + 6);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CommandShape shape = pickOne(random, allCommandShapes);
        final NodeCommand<Object?> command = shape.buildCommand(random);
        final Object? replyJson = shape.buildReplyJson(random);
        final List<Object?> wrongReply = <Object?>[replyJson, replyJson];
        final ScriptedNodeTransport transport = ScriptedNodeTransport(
          answer: (String inputJson) => encodeSuccessReply(wrongReply),
        );

        await expectLater(
          NodeCommandChannel(transport: transport).execute(command),
          throwsFormatException,
          reason: shape.commandName,
        );
        expect(transport.exchanges, hasLength(1));
      }
    },
  );

  test('test_execute_property_concurrent_replies_stay_paired', () async {
    final Random random = seededRandom(_firstSeed + 7);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<CommandShape> shapes = <CommandShape>[];
      final List<Object?> replyJsons = <Object?>[];
      final int callCount = 1 + random.nextInt(_largestConcurrentCalls);
      for (int call = 0; call < callCount; call += 1) {
        final CommandShape shape = pickOne(random, allCommandShapes);
        shapes.add(shape);
        replyJsons.add(rereadThroughWire(shape.buildReplyJson(random)));
      }
      final List<NodeCommand<Object?>> commands = <NodeCommand<Object?>>[];
      final Map<String, Object?> repliesByCommand = <String, Object?>{};
      for (int call = 0; call < callCount; call += 1) {
        final NodeCommand<Object?> command = shapes[call].buildCommand(random);
        commands.add(command);
        repliesByCommand[jsonEncode(encodeNodeCommand(command))] =
            replyJsons[call];
      }
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(
          answer: (String inputJson) =>
              encodeSuccessReply(repliesByCommand[inputJson]),
        ),
      );

      final List<Object?> decoded = await Future.wait(<Future<Object?>>[
        for (final NodeCommand<Object?> command in commands)
          channel.execute(command),
      ]);

      for (int call = 0; call < callCount; call += 1) {
        final String sentText = jsonEncode(encodeNodeCommand(commands[call]));
        expect(
          rereadThroughWire(shapes[call].encodeReply(decoded[call])),
          equals(repliesByCommand[sentText]),
          reason: shapes[call].commandName,
        );
      }
    }
  });
}
