import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';

const List<String> _kinds = <String>['project', 'workflow agent', 'rule'];

void main() {
  test('test_translate_node_failure_property_not_found_keeps_record', () {
    final Random random = seededRandom(9201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String kind = pickOne(random, _kinds);
      final String identifier = 'id-${random.nextInt(100000)}';
      final Object translated = translateNodeFailure(
        NodeCommandFailure('$kind $identifier was not found'),
      );
      expect(translated, isA<RecordNotFound>());
      final RecordNotFound notFound = translated as RecordNotFound;
      expect(notFound.kind, kind);
      expect(notFound.identifier, identifier);
    }
  });

  test('test_translate_node_failure_property_other_failures_keep_text', () {
    final Random random = seededRandom(9202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);
      final Object translated = translateNodeFailure(
        NodeCommandFailure(message),
      );
      if (translated is StateError) {
        expect(translated.message, message);
      } else {
        expect(message, endsWith(' was not found'));
      }
    }
  });

  test('test_execute_node_command_property_failures_are_translated', () async {
    final Random random = seededRandom(9203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = 'the app server answered ${random.nextInt(600)}';
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(
          answer: (String _) => encodeErrorReply(message),
        ),
      );
      await expectLater(
        executeNodeCommand(channel, const node.RetryServerCommand()),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            message,
          ),
        ),
      );
    }
  });

  test('test_execute_node_command_property_success_is_decoded', () async {
    final Random random = seededRandom(9204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isReachable = random.nextBool();
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(
          answer: (String _) => encodeSuccessReply(<String, Object?>{
            'reachable': isReachable,
            'checked_at': '2026-10-31T10:00:00Z',
            'problem': null,
          }),
        ),
      );
      final bool reachable = (await executeNodeCommand(
        channel,
        const node.RetryServerCommand(),
      )).reachable;
      expect(reachable, isReachable);
    }
  });
}
