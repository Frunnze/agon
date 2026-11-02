import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const Duration _presentWithin = Duration(minutes: 1);
const String _thisDeviceLabel = 'This device';
const String _workspaceSeparator = ', ';
const int _countdownFieldWidth = 2;

String describeLastSeen(DateTime lastSeen, DateTime now) {
  if (now.difference(lastSeen) < _presentWithin) {
    return 'Now';
  }
  return describeTimeSince(lastSeen, now);
}

String describeRoleWithArticle(DeviceRole role) {
  return 'a ${role.label.toLowerCase()}';
}

String describeThisDeviceKind(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
      return 'Mac';
    case TargetPlatform.windows:
      return 'PC';
    case TargetPlatform.linux:
      return 'computer';
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return 'device';
  }
}

String describeTrayName(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
      return 'menu bar';
    case TargetPlatform.linux:
    case TargetPlatform.windows:
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return 'tray';
  }
}

String describeDeviceKey({
  required Device device,
  required DeviceId currentDeviceId,
}) {
  if (device.id == currentDeviceId) {
    return '$_thisDeviceLabel · ${device.keyKind.label}';
  }
  return device.keyKind.label;
}

String describeDevicePairing(Device device, DeviceNames deviceNames) {
  final String pairedOn = formatCalendarDate(device.pairedAt);
  final DeviceId? approver = device.approvedBy;

  if (approver == null) {
    return pairedOn;
  }
  return '$pairedOn, approved by ${deviceNames.nameOf(approver)}';
}

String describeWorkspaceNames(
  List<WorkspaceId> workspaceIds,
  ScopeCatalog catalog,
) {
  final List<String> names = <String>[
    for (final WorkspaceId workspaceId in workspaceIds)
      catalog.nameOfWorkspace(workspaceId),
  ];

  return names.join(_workspaceSeparator);
}

String describeTimeLeft({required DateTime expiresAt, required DateTime now}) {
  final Duration left = expiresAt.difference(now);
  if (left <= Duration.zero) {
    return 'Expired';
  }

  final int minutes = left.inMinutes;
  final String seconds = (left.inSeconds % Duration.secondsPerMinute)
      .toString()
      .padLeft(_countdownFieldWidth, '0');
  return 'Expires in $minutes:$seconds';
}
