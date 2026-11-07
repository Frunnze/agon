import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../native/support/bundled_node_library.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/scripted_node_transport.dart';
import 'support/random_start_configurations.dart';

const int _firstSeed = 6277000;
const int _sequenceLength = 12;
const int _restartCount = 3;
const String _nodeFolder = 'build/node_lifecycle_property_test';
const Timeout _realNodeTimeout = Timeout(Duration(minutes: 2));

enum _LifecycleCall { start, stop }

enum _ReplyKind { nothing, refusal, unexpectedValue }

final class _ScriptedReply {
  _ScriptedReply(Random random)
    : kind = pickOne(random, _ReplyKind.values),
      message = randomHostileText(random),
      unexpectedValue = <Object?>[randomArbitraryJson(random)];

  final _ReplyKind kind;
  final String message;
  final Object? unexpectedValue;

  String encode() {
    return switch (kind) {
      _ReplyKind.nothing => encodeSuccessReply(null),
      _ReplyKind.refusal => encodeErrorReply(message),
      _ReplyKind.unexpectedValue => encodeSuccessReply(unexpectedValue),
    };
  }

  Matcher outcome() {
    return switch (kind) {
      _ReplyKind.nothing => completes,
      _ReplyKind.refusal => throwsA(
        isA<NodeCommandFailure>().having(
          (NodeCommandFailure failure) => failure.message,
          'message',
          message,
        ),
      ),
      _ReplyKind.unexpectedValue => throwsFormatException,
    };
  }
}

final class _ReplayedReplies {
  _ReplayedReplies({required this.replies});

  final List<_ScriptedReply> replies;
  int answeredCalls = 0;

  String answer(String inputJson) {
    final _ScriptedReply reply = replies[answeredCalls];
    answeredCalls += 1;
    return reply.encode();
  }
}

Future<void> _callLifecycle(
  _LifecycleCall call,
  ScriptedNodeTransport transport,
  NodeStartConfiguration configuration,
) {
  return switch (call) {
    _LifecycleCall.start => startNode(
      transport: transport,
      configuration: configuration,
    ),
    _LifecycleCall.stop => stopNode(transport),
  };
}

NodeStartConfiguration _realConfiguration(Directory folder) {
  return NodeStartConfiguration(
    dataDirectory: folder.absolute.path,
    identityStore: const FileIdentityStore(),
    runner: const NoRunner(),
    peerRelay: PeerRelayChoice.disabled,
  );
}

Future<Object?> _readStatusJson(NodeCommandChannel channel) async {
  final StatusView status = await channel.execute(const StatusCommand());
  return jsonDecode(jsonEncode(status.toJson()));
}

void main() {
  final String? skipReason = readBundledLibrarySkipReason();

  test('test_start_node_property_rejects_unexpected_ok_values', () async {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> okValue = <Object?>[randomArbitraryJson(random)];
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeSuccessReply(okValue),
      );

      await expectLater(
        startNode(
          transport: transport,
          configuration: randomStartConfiguration(random),
        ),
        throwsFormatException,
      );
      expect(transport.exchanges, hasLength(1));
    }
  });

  test('test_start_node_property_each_call_follows_its_own_reply', () async {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_LifecycleCall> calls = <_LifecycleCall>[];
      final List<_ScriptedReply> replies = <_ScriptedReply>[];
      for (int call = 0; call < _sequenceLength; call += 1) {
        calls.add(pickOne(random, _LifecycleCall.values));
        replies.add(_ScriptedReply(random));
      }
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: _ReplayedReplies(replies: replies).answer,
      );
      final NodeStartConfiguration configuration = randomStartConfiguration(
        random,
      );

      for (int call = 0; call < calls.length; call += 1) {
        await expectLater(
          _callLifecycle(calls[call], transport, configuration),
          replies[call].outcome(),
        );
      }

      final int startCount = calls
          .where((_LifecycleCall call) => call == _LifecycleCall.start)
          .length;
      expect(transport.exchanges, hasLength(startCount));
      expect(transport.stopRequests, calls.length - startCount);
      for (final RecordedExchange exchange in transport.exchanges) {
        expect(exchange.entryPoint, NodeEntryPoint.start);
        expect(jsonDecode(exchange.inputJson), configuration.toJson());
      }
    }
  });

  test(
    'test_start_node_property_restarts_keep_the_node_status',
    () async {
      final Directory folder = Directory(_nodeFolder)
        ..createSync(recursive: true);
      final NativeNodeTransport transport = NativeNodeTransport(
        source: bundledLibraryFile(),
      );
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: transport,
      );
      addTearDown(() => folder.deleteSync(recursive: true));
      addTearDown(() => stopNode(transport));

      await startNode(
        transport: transport,
        configuration: _realConfiguration(folder),
      );
      final Object? firstStatus = await _readStatusJson(channel);

      for (int i = 0; i < _restartCount; i += 1) {
        await stopNode(transport);
        await stopNode(transport);
        await expectLater(
          channel.execute(const StatusCommand()),
          throwsA(isA<NodeCommandFailure>()),
        );

        await startNode(
          transport: transport,
          configuration: _realConfiguration(folder),
        );
        await startNode(
          transport: transport,
          configuration: _realConfiguration(folder),
        );

        expect(await _readStatusJson(channel), equals(firstStatus));
      }
    },
    skip: skipReason,
    timeout: _realNodeTimeout,
  );
}
