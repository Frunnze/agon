import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

const String _localAddressPrefix = 'local:';
const String _deviceSeparator = ':';
const List<String> _folderPathStarts = <String>['/', '\\', '~'];
final RegExp _folderSeparators = RegExp(r'[\\/]');
final RegExp _driveRoot = RegExp(r'^[A-Za-z]:[\\/]');

final class LocalFolderAddress {
  const LocalFolderAddress({required this.deviceId, required this.path});

  final DeviceId deviceId;
  final String path;
}

String renderLocalFolderAddress({
  required DeviceId deviceId,
  required String path,
}) {
  return '$_localAddressPrefix${deviceId.value}$_deviceSeparator$path';
}

LocalFolderAddress? parseLocalFolderAddress(String address) {
  if (!address.startsWith(_localAddressPrefix)) {
    return null;
  }

  final String deviceAndPath = address.substring(_localAddressPrefix.length);
  final int separatorIndex = deviceAndPath.indexOf(_deviceSeparator);
  if (separatorIndex <= 0) {
    return null;
  }
  final String deviceText = deviceAndPath.substring(0, separatorIndex);
  final String path = deviceAndPath.substring(separatorIndex + 1);
  if (path.isEmpty) {
    return null;
  }
  return LocalFolderAddress(deviceId: DeviceId(deviceText), path: path);
}

String describeFolderName(String path) {
  final List<String> namedParts = <String>[
    for (final String part in path.split(_folderSeparators))
      if (part.isNotEmpty) part,
  ];
  if (namedParts.isEmpty) {
    return path;
  }
  return namedParts.last;
}

bool looksLikeFolderPath(String text) {
  final String trimmed = text.trim();
  for (final String start in _folderPathStarts) {
    if (trimmed.startsWith(start)) {
      return true;
    }
  }
  return _driveRoot.hasMatch(trimmed);
}

LocalFolderAddress? findLocalFolder(List<Repository> repositories) {
  for (final Repository repository in repositories) {
    final LocalFolderAddress? folder = parseLocalFolderAddress(
      repository.address,
    );
    if (folder != null) {
      return folder;
    }
  }
  return null;
}
