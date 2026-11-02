import 'dart:math';

import 'package:agent_orchestration/data/rules/naming.dart';

const String _peerScheme = 'peer';
const Set<String> _serverSchemes = <String>{'https', 'http', _peerScheme};
const String _peerHostLabel = 'peer link';
const int _shownPeerKeyLength = 8;
const int _pairingCodeLength = 6;
const String _localHostSuffix = '.local';
const String _fallbackDeviceName = 'new-device';
const String _nameSeparator = '-';
final RegExp _pairingCodeSeparators = RegExp(r'[\s-]');
final RegExp _characterOutsideNames = RegExp('[^a-z0-9]+');
final RegExp _edgeSeparators = RegExp(r'^-+|-+$');

Uri? _parseServerAddress(String address) {
  final Uri? parsed = Uri.tryParse(address.trim());
  if (parsed == null || !_serverSchemes.contains(parsed.scheme)) {
    return null;
  }
  if (parsed.host.isEmpty) {
    return null;
  }
  return parsed;
}

String? describeServerAddressProblem(String address) {
  if (address.trim().isEmpty) {
    return 'Enter the app server address';
  }
  if (_parseServerAddress(address) == null) {
    return 'Start the address with https:// or http://';
  }
  return null;
}

String describeServerHost(String address) {
  final Uri? parsed = _parseServerAddress(address);
  if (parsed == null) {
    return address;
  }
  if (parsed.scheme != _peerScheme) {
    return parsed.authority;
  }
  final String key = parsed.host;
  final int shownLength = min(key.length, _shownPeerKeyLength);
  return '$_peerHostLabel ${key.substring(0, shownLength)}';
}

String? describePairingCodeProblem(String code) {
  final String characters = code.replaceAll(_pairingCodeSeparators, '');
  if (characters.length != _pairingCodeLength) {
    return 'A pairing code has six characters';
  }
  return null;
}

String? describeJoinInputProblem({
  required String? serverAddress,
  required String code,
}) {
  final String? codeProblem = describePairingCodeProblem(code);
  if (codeProblem != null || serverAddress == null) {
    return codeProblem;
  }
  return describeServerAddressProblem(serverAddress);
}

String suggestDeviceName(String hostName) {
  final String lowercase = hostName.trim().toLowerCase();
  final String withoutSuffix = lowercase.endsWith(_localHostSuffix)
      ? lowercase.substring(0, lowercase.length - _localHostSuffix.length)
      : lowercase;
  final String dashed = withoutSuffix
      .replaceAll(_characterOutsideNames, _nameSeparator)
      .replaceAll(_edgeSeparators, '');
  final String shortened = dashed.length > nameMaximumLength
      ? dashed.substring(0, nameMaximumLength).replaceAll(_edgeSeparators, '')
      : dashed;

  if (shortened.isEmpty) {
    return _fallbackDeviceName;
  }
  return shortened;
}
