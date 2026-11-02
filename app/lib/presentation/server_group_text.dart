import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const String _activeServerText =
    'Active server · relays messages and keeps the run queue. It sees only '
    'encrypted data.';
const String _backupServerText =
    'Backup · keeps a live copy and takes over when the active server is '
    'off.';
const String _thisDevicePrefix = 'This device · ';
const String _keepBackupHint =
    'This computer keeps a live copy and takes over when the server is off.';
const String _activeServerHint = 'This computer is the active server.';

List<AppServerMember> orderAppServerMembers(List<AppServerMember> members) {
  final List<AppServerMember> activeMembers = <AppServerMember>[];
  final List<AppServerMember> backupMembers = <AppServerMember>[];

  for (final AppServerMember member in members) {
    if (member.standing == ServerStanding.active) {
      activeMembers.add(member);
    } else {
      backupMembers.add(member);
    }
  }

  return List<AppServerMember>.unmodifiable(<AppServerMember>[
    ...activeMembers,
    ...backupMembers,
  ]);
}

String describeAppServerMember(
  AppServerMember member, {
  required DeviceId currentDeviceId,
}) {
  final String standingText = switch (member.standing) {
    ServerStanding.active => _activeServerText,
    ServerStanding.backup => _backupServerText,
  };

  if (member.deviceId == currentDeviceId) {
    return '$_thisDevicePrefix$standingText';
  }
  return standingText;
}

String describeServerBackupHint(ThisDeviceStanding standing) {
  return switch (standing) {
    ThisDeviceStanding.active => _activeServerHint,
    ThisDeviceStanding.backup => _keepBackupHint,
    ThisDeviceStanding.none => _keepBackupHint,
  };
}
