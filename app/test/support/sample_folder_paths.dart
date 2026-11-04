import 'dart:io';

const String _unixSeparator = '/';
const String _windowsSeparator = '\\';
const String _driveSeparator = ':';

String buildTemporaryFolderPath(String pathInsideTemporaryFolder) {
  final String temporaryFolder = Directory.systemTemp.path;
  return '$temporaryFolder$_unixSeparator$pathInsideTemporaryFolder';
}

String buildWindowsFolderPath({
  required String driveLetter,
  required List<String> folderNames,
}) {
  final String folders = folderNames.join(_windowsSeparator);
  return '$driveLetter$_driveSeparator$_windowsSeparator$folders';
}
