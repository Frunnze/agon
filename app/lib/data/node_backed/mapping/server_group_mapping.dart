import 'package:agent_orchestration/bridge/codecs/server_group_values.dart'
    as node;
import 'package:agent_orchestration/data/models/app_server_group.dart';

ServerStanding _mapServerStandingFromNode(node.ServerStanding standing) {
  return switch (standing) {
    node.ServerStanding.active => ServerStanding.active,
    node.ServerStanding.backup => ServerStanding.backup,
  };
}

ThisDeviceStanding _mapThisDeviceStandingFromNode(
  node.ThisDeviceStanding standing,
) {
  return switch (standing) {
    node.ThisDeviceStanding.active => ThisDeviceStanding.active,
    node.ThisDeviceStanding.backup => ThisDeviceStanding.backup,
    node.ThisDeviceStanding.none => ThisDeviceStanding.none,
  };
}

BackupCopy? _mapBackupCopyFromNode(node.BackupCopyView? copy) {
  if (copy == null) {
    return null;
  }
  return BackupCopy(
    changesBehind: copy.changesBehind,
    verifiedAt: copy.verifiedAt,
  );
}

AppServerGroup mapAppServerGroupFromNode(node.AppServersView view) {
  final List<AppServerMember> members = <AppServerMember>[
    for (final node.AppServerView server in view.servers)
      AppServerMember(
        deviceId: server.deviceId,
        standing: _mapServerStandingFromNode(server.standing),
        copy: _mapBackupCopyFromNode(server.copy),
      ),
  ];

  return AppServerGroup(
    members: members,
    thisDeviceStanding: _mapThisDeviceStandingFromNode(view.thisDevice),
    canKeepBackup: view.canKeepBackup,
  );
}
