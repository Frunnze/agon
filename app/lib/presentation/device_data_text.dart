import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const Duration _copyFreshWithin = Duration(minutes: 1);
const String _activeServerRole = 'App server';
const String _backupServerRole = 'Backup server';
const String _holdsDataText = 'Holds the data';
const String _hasCopyText = 'Has a copy';
const String _noCopyText = 'No copy';
const String _upToDateText = 'Up to date';
const String _unreachableServerText =
    "Not syncing: can't reach the app server";
const String _neverCopiedText =
    'Not syncing: no copy since the server started';

AppServerMember? findAppServerMember({
  required AppServerGroup group,
  required DeviceId deviceId,
}) {
  for (final AppServerMember member in group.members) {
    if (member.deviceId == deviceId) {
      return member;
    }
  }
  return null;
}

String describeDeviceRole({
  required DeviceRole role,
  required AppServerMember? serverMember,
}) {
  if (serverMember == null) {
    return role.label;
  }
  return switch (serverMember.standing) {
    ServerStanding.active => _activeServerRole,
    ServerStanding.backup => _backupServerRole,
  };
}

String describeDeviceData({
  required AppServerMember? serverMember,
  required AppServerState serverState,
  required DateTime now,
}) {
  if (serverMember == null) {
    return _noCopyText;
  }
  switch (serverMember.standing) {
    case ServerStanding.active:
      return _holdsDataText;
    case ServerStanding.backup:
      final String copyState = describeBackupCopy(
        copy: serverMember.copy,
        serverState: serverState,
        now: now,
      );
      return '$_hasCopyText · $copyState';
  }
}

String describeBackupCopy({
  required BackupCopy? copy,
  required AppServerState serverState,
  required DateTime now,
}) {
  if (serverState == AppServerState.unreachable) {
    return _unreachableServerText;
  }
  if (copy == null) {
    return _neverCopiedText;
  }

  final bool isFresh = now.difference(copy.verifiedAt) < _copyFreshWithin;
  if (!isFresh) {
    final String copyAge = describeTimeSince(copy.verifiedAt, now);
    return 'Last copied ${copyAge.toLowerCase()}';
  }

  final int changesBehind = copy.changesBehind;
  if (changesBehind == 0) {
    return _upToDateText;
  }
  if (changesBehind == 1) {
    return '1 change behind';
  }
  return '$changesBehind changes behind';
}
