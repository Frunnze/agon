import 'package:agent_orchestration/bridge/native/node_entry_point.dart';

abstract interface class NodeTransport {
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  });

  Future<String> stop();
}
