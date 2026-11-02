import 'dart:ffi';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';

DynamicLibrary openNativeLibrary(NativeLibrarySource source) {
  return switch (source) {
    LinkedIntoProcess() => DynamicLibrary.process(),
    LibraryFile(:final String path) => DynamicLibrary.open(path),
    LinkedIntoProcessOrLibraryFile(:final String path) => _openProcessOrFile(
      path,
    ),
  };
}

DynamicLibrary _openProcessOrFile(String path) {
  final DynamicLibrary process = DynamicLibrary.process();
  final String commandSymbol = NodeEntryPoint.handleCommand.symbol;
  if (process.providesSymbol(commandSymbol)) {
    return process;
  }
  return DynamicLibrary.open(path);
}
