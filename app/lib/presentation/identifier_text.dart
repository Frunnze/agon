import 'package:agent_orchestration/data/rules/local_folder_address.dart';

const int _keptEndLength = 4;
const String _ellipsis = '…';
const String _pathSeparator = '/';
const int _hostedPathSegmentCount = 3;

String shortenIdentifier(String identifier) {
  if (identifier.length <= _keptEndLength * 2 + 1) {
    return identifier;
  }

  final String start = identifier.substring(0, _keptEndLength);
  final String end = identifier.substring(identifier.length - _keptEndLength);

  return '$start$_ellipsis$end';
}

String describeRepositoryPath(String address) {
  final LocalFolderAddress? folder = parseLocalFolderAddress(address);
  if (folder != null) {
    return describeFolderName(folder.path);
  }

  final List<String> segments = address.split(_pathSeparator);
  if (segments.length < _hostedPathSegmentCount) {
    return address;
  }

  return segments.skip(1).join(_pathSeparator);
}
