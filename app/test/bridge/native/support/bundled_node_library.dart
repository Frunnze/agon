import 'dart:io';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';

const String _bundledLibraryRelativePath =
    'macos/native/liborchestration_ffi.dylib';
const String notStartedMessagePrefix = 'the node has not started';
const String invalidConfigurationMessage = 'invalid configuration';

String bundledLibraryPath() {
  return File(_bundledLibraryRelativePath).absolute.path;
}

LibraryFile bundledLibraryFile() {
  return LibraryFile(path: bundledLibraryPath());
}

String? readBundledLibrarySkipReason() {
  if (!Platform.isMacOS) {
    return 'the bundled node library is only built for macOS';
  }
  if (!File(_bundledLibraryRelativePath).existsSync()) {
    return 'the bundled node library $_bundledLibraryRelativePath is missing';
  }
  return null;
}
