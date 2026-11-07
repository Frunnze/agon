const String _schemeSeparator = '://';
const String _supportedScheme = 'https';
const String _secureShellPrefix = 'git@';
const String _secureShellHostSeparator = ':';
const String _gitSuffix = '.git';
const String _pathSeparator = '/';
const String _hostLabelSeparator = '.';
const int _canonicalPartCount = 3;
const int _minimumHostLabels = 2;
const List<String> _reservedPathParts = <String>['.', '..'];
final RegExp _hostLabelPattern = RegExp(
  r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$',
);
final RegExp _pathPartPattern = RegExp(r'^[A-Za-z0-9._-]+$');

String? _removeAddressPrefix(String address) {
  final int schemeEnd = address.indexOf(_schemeSeparator);
  if (schemeEnd >= 0) {
    final String scheme = address.substring(0, schemeEnd);
    if (scheme.toLowerCase() != _supportedScheme) {
      return null;
    }
    return address.substring(schemeEnd + _schemeSeparator.length);
  }

  if (address.startsWith(_secureShellPrefix)) {
    final String rest = address.substring(_secureShellPrefix.length);
    final int colon = rest.indexOf(_secureShellHostSeparator);
    if (colon < 0) {
      return null;
    }
    final String host = rest.substring(0, colon);
    final String path = rest.substring(colon + 1);
    return '$host$_pathSeparator$path';
  }

  return address;
}

String _removeTrailing(String text, String suffix) {
  String remaining = text;
  while (remaining.endsWith(suffix)) {
    remaining = remaining.substring(0, remaining.length - suffix.length);
  }
  return remaining;
}

bool _isHost(String host) {
  final List<String> labels = host.split(_hostLabelSeparator);
  if (labels.length < _minimumHostLabels) {
    return false;
  }
  return labels.every(_hostLabelPattern.hasMatch);
}

bool _isPathPart(String part) {
  return !_reservedPathParts.contains(part) && _pathPartPattern.hasMatch(part);
}

String? parseRepositoryAddress(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final String? hostAndPath = _removeAddressPrefix(trimmed);
  if (hostAndPath == null) {
    return null;
  }

  final String withoutSlashes = _removeTrailing(hostAndPath, _pathSeparator);
  final String withoutSuffix = _removeTrailing(withoutSlashes, _gitSuffix);

  final List<String> parts = withoutSuffix.split(_pathSeparator);
  if (parts.length != _canonicalPartCount) {
    return null;
  }
  if (!_isHost(parts[0]) || !_isPathPart(parts[1]) || !_isPathPart(parts[2])) {
    return null;
  }
  final String lowercaseHost = parts[0].toLowerCase();
  return <String>[lowercaseHost, parts[1], parts[2]].join(_pathSeparator);
}
