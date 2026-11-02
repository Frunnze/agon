import 'dart:convert';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

const String _commandField = 'command';
const String _afterSequenceField = 'after';
const String _changeFeedPollCommand = 'poll_events';
const int _startingSnapshotSequence = 0;

final class CountingNodeTransport implements NodeTransport {
  CountingNodeTransport({required NodeTransport transport})
    : _transport = transport;

  final NodeTransport _transport;
  int _commandsInFlight = 0;
  int _exchangesInFlight = 0;

  bool get hasCommandsInFlight => _commandsInFlight > 0;

  bool get hasExchangesInFlight => _exchangesInFlight > 0;

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final bool isCommand = !_isChangeFeedWait(inputJson);
    _exchangesInFlight += 1;
    if (isCommand) {
      _commandsInFlight += 1;
    }

    try {
      return await _transport.exchange(
        entryPoint: entryPoint,
        inputJson: inputJson,
      );
    } finally {
      _exchangesInFlight -= 1;
      if (isCommand) {
        _commandsInFlight -= 1;
      }
    }
  }

  @override
  Future<String> stop() => _transport.stop();
}

bool _isChangeFeedWait(String inputJson) {
  final Object? command = jsonDecode(inputJson);
  if (command is! Map<String, Object?>) {
    return false;
  }
  final bool isPoll = command[_commandField] == _changeFeedPollCommand;
  final bool isAfterKnownChange =
      command[_afterSequenceField] != _startingSnapshotSequence;
  return isPoll && isAfterKnownChange;
}
