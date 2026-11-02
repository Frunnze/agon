import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

import '../../support/random_inputs.dart';
import '../support/all_command_shapes.dart';
import '../support/arbitrary_json.dart';
import '../support/command_shape.dart';
import '../support/scripted_node_transport.dart';

void main() {
  test('test_send_property_passes_the_command_and_returns_ok', () async {
    final Random random = seededRandom(5001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject command = <String, Object?>{
        commandNameField: randomText(random),
        'argument': randomArbitraryJson(random),
      };
      final Object? okValue = randomArbitraryJson(random);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeSuccessReply(okValue),
      );
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: transport,
      );

      final Object? reply = await channel.send(command);

      expect(reply, equals(okValue));
      expect(
        transport.exchanges.single.entryPoint,
        NodeEntryPoint.handleCommand,
      );
      expect(
        jsonDecode(transport.exchanges.single.inputJson),
        equals(command),
      );
    }
  });

  test('test_send_property_raises_node_command_failure', () async {
    final Random random = seededRandom(5002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(
          answer: (String inputJson) => encodeErrorReply(message),
        ),
      );

      await expectLater(
        channel.send(<String, Object?>{commandNameField: 'status'}),
        throwsA(
          isA<NodeCommandFailure>().having(
            (NodeCommandFailure failure) => failure.message,
            'message',
            message,
          ),
        ),
      );
    }
  });

  test('test_execute_property_sends_encoded_command_and_decodes', () async {
    final Random random = seededRandom(5003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CommandShape shape = pickOne(random, allCommandShapes);
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final Object? replyJson = shape.buildReplyJson(random);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeSuccessReply(replyJson),
      );
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: transport,
      );

      final Object? decoded = await channel.execute(command);

      expect(
        jsonDecode(jsonEncode(shape.encodeReply(decoded))),
        equals(replyJson),
      );
      expect(
        jsonDecode(transport.exchanges.single.inputJson),
        equals(jsonDecode(jsonEncode(encodeNodeCommand(command)))),
      );
    }
  });
}
