import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

const String _invitationScheme = 'agent-orchestration';
const String _invitationPath = 'pair';
const String _versionField = 'v';
const String _codeField = 'code';
const String _serverField = 'server';
const String _currentVersion = '1';

String encodePairingInvitation(PairingInvitation invitation) {
  final Uri link = Uri(
    scheme: _invitationScheme,
    path: _invitationPath,
    queryParameters: <String, String>{
      _versionField: _currentVersion,
      _codeField: invitation.code,
      _serverField: invitation.serverAddress,
    },
  );

  return link.toString();
}

PairingInvitation decodePairingInvitation(String text) {
  final Uri link = Uri.parse(text);
  final bool isInvitation =
      link.scheme == _invitationScheme && link.path == _invitationPath;
  if (!isInvitation) {
    throw FormatException('This is not a pairing code', text);
  }

  final Map<String, String> fields = link.queryParameters;
  if (fields[_versionField] != _currentVersion) {
    throw FormatException('This pairing code needs a newer app', text);
  }

  final String? code = fields[_codeField];
  final String? serverAddress = fields[_serverField];
  if (code == null || serverAddress == null) {
    throw FormatException('This pairing code is incomplete', text);
  }
  if (describeServerAddressProblem(serverAddress) != null) {
    throw FormatException(
      'This pairing code has a broken server address',
      text,
    );
  }
  return PairingInvitation(code: code, serverAddress: serverAddress);
}
