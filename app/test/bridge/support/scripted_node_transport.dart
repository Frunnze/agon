import 'dart:convert';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

typedef NodeAnswer = String Function(String inputJson);

typedef RecordedExchange = ({NodeEntryPoint entryPoint, String inputJson});

final class ScriptedNodeTransport implements NodeTransport {
  ScriptedNodeTransport({required this.answer});

  final NodeAnswer answer;
  final List<RecordedExchange> exchanges = <RecordedExchange>[];
  int stopRequests = 0;

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    exchanges.add((entryPoint: entryPoint, inputJson: inputJson));
    await Future<void>.delayed(Duration.zero);
    return answer(inputJson);
  }

  @override
  Future<String> stop() async {
    stopRequests += 1;
    await Future<void>.delayed(Duration.zero);
    return answer('');
  }
}

String encodeSuccessReply(Object? okValue) {
  return jsonEncode(<String, Object?>{'ok': okValue});
}

String encodeErrorReply(String message) {
  return jsonEncode(<String, Object?>{'error': message});
}
