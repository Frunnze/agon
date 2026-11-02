import 'dart:io';

const String _rustBuildFolder = 'rust/target/debug';
const String _serverProgramName = 'orchestration-server';
const String _nodeHostProgramName = 'orchestration_node_host';
const String _windowsProgramSuffix = '.exe';
const String _macLibraryName = 'liborchestration_ffi.dylib';
const String _linuxLibraryName = 'liborchestration_ffi.so';
const String _windowsLibraryName = 'orchestration_ffi.dll';

String _rustBuildFolderPath() {
  final String projectFolder = Directory.current.parent.path;
  return '$projectFolder/$_rustBuildFolder';
}

String hostLibraryPath() {
  final String libraryName = switch (Platform.operatingSystem) {
    'macos' => _macLibraryName,
    'windows' => _windowsLibraryName,
    _ => _linuxLibraryName,
  };
  return '${_rustBuildFolderPath()}/$libraryName';
}

String serverProgramPath() {
  final String suffix = Platform.isWindows ? _windowsProgramSuffix : '';
  return '${_rustBuildFolderPath()}/$_serverProgramName$suffix';
}

String nodeHostProgramPath() {
  final String suffix = Platform.isWindows ? _windowsProgramSuffix : '';
  return '${_rustBuildFolderPath()}/$_nodeHostProgramName$suffix';
}
