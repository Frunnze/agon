import 'dart:isolate';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_call.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

final class NativeNodeTransport implements NodeTransport {
  const NativeNodeTransport({required this.source});

  final NativeLibrarySource source;

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) {
    return Isolate.run(
      () => callNodeEntryPoint(
        source: source,
        entryPoint: entryPoint,
        inputJson: inputJson,
      ),
      debugName: entryPoint.symbol,
    );
  }

  @override
  Future<String> stop() {
    return Isolate.run(() => callNodeStop(source), debugName: stopSymbol);
  }
}
