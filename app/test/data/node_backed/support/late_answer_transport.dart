import 'dart:async';
import 'dart:convert';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

import '../../../bridge/support/scripted_node_transport.dart';

final class LateAnswerTransport implements NodeTransport {
  LateAnswerTransport({required this.answer, required this.heldCommandName});

  final NodeAnswer answer;
  final String heldCommandName;
  final Completer<void> _release = Completer<void>();
  bool isHoldingCommand = false;

  void releaseHeldCommand() => _release.complete();

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final bool isHeld =
        command['command'] == heldCommandName && !_release.isCompleted;
    if (isHeld) {
      isHoldingCommand = true;
      await _release.future;
    }
    return answer(inputJson);
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a late answer transport is never stopped');
  }
}
