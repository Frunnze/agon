import 'dart:async';
import 'dart:convert';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

import '../../../bridge/support/scripted_node_transport.dart';

final class HeldNextReplyTransport implements NodeTransport {
  HeldNextReplyTransport({required this.answer});

  final NodeAnswer answer;
  String? _heldCommandName;
  Completer<void> _release = Completer<void>();
  Completer<void> _heldReplyArrival = Completer<void>();

  Future<void> get heldReplyArrival => _heldReplyArrival.future;

  void holdNextReply(String commandName) {
    _heldCommandName = commandName;
    _release = Completer<void>();
    _heldReplyArrival = Completer<void>();
  }

  void releaseHeldReply() => _release.complete();

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final String reply = answer(inputJson);
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final Object? commandName = command['command'];
    if (commandName != _heldCommandName) {
      await Future<void>.delayed(Duration.zero);
      return reply;
    }

    _heldCommandName = null;
    _heldReplyArrival.complete();
    await _release.future;
    return reply;
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a held next reply transport is never stopped');
  }
}
