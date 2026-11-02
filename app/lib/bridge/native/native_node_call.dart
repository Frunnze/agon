import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:agent_orchestration/bridge/native/native_library_opening.dart';
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';

typedef NodeTextFunction = Pointer<Utf8> Function(Pointer<Utf8> input);

typedef NodeStopFunction = Pointer<Utf8> Function();

typedef FreeTextNativeFunction = Void Function(Pointer<Utf8> text);

typedef FreeTextFunction = void Function(Pointer<Utf8> text);

String callNodeEntryPoint({
  required NativeLibrarySource source,
  required NodeEntryPoint entryPoint,
  required String inputJson,
}) {
  final DynamicLibrary library = openNativeLibrary(source);
  final NodeTextFunction callNode = library
      .lookupFunction<NodeTextFunction, NodeTextFunction>(entryPoint.symbol);

  final Pointer<Utf8> inputText = inputJson.toNativeUtf8();
  try {
    return _takeReply(library, callNode(inputText));
  } finally {
    malloc.free(inputText);
  }
}

String callNodeStop(NativeLibrarySource source) {
  final DynamicLibrary library = openNativeLibrary(source);
  final NodeStopFunction stopNode = library
      .lookupFunction<NodeStopFunction, NodeStopFunction>(stopSymbol);
  return _takeReply(library, stopNode());
}

String _takeReply(DynamicLibrary library, Pointer<Utf8> replyText) {
  final FreeTextFunction freeReply = library
      .lookupFunction<FreeTextNativeFunction, FreeTextFunction>(
        freeStringSymbol,
      );
  try {
    return replyText.toDartString();
  } finally {
    freeReply(replyText);
  }
}
