import 'package:agent_orchestration/data/models/identifiers.dart';

enum ServerStanding { active, backup }

enum ThisDeviceStanding { active, backup, none }

final class BackupCopy {
  const BackupCopy({required this.changesBehind, required this.verifiedAt});

  final int changesBehind;
  final DateTime verifiedAt;
}

final class AppServerMember {
  const AppServerMember({
    required this.deviceId,
    required this.standing,
    required this.copy,
  });

  final DeviceId deviceId;
  final ServerStanding standing;
  final BackupCopy? copy;
}

final class AppServerGroup {
  AppServerGroup({
    required List<AppServerMember> members,
    required this.thisDeviceStanding,
    required this.canKeepBackup,
  }) : members = List<AppServerMember>.unmodifiable(members);

  final List<AppServerMember> members;
  final ThisDeviceStanding thisDeviceStanding;
  final bool canKeepBackup;
}
