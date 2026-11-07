import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/devices/revoke_device_dialog.dart';
import 'package:agent_orchestration/screens/devices/workspace_devices_section.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

const String _sharedDevicesNote =
    'Shared by all your workspaces. Pair once, revoke once. Clients and '
    'runners keep no copy of the workspace data.';
const List<String> _columnLabels = <String>[
  'Device',
  'Role',
  'Data',
  'Status',
  '',
];

const String _pairDeviceLabel = 'Pair a device';
const String _revokeLabel = 'Revoke';

class AllDevicesSection extends StatelessWidget {
  const AllDevicesSection({
    required this.deviceRepository,
    required this.pairingRepository,
    required this.workspaceRepository,
    required this.catalog,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final DeviceRepository deviceRepository;
  final PairingRepository pairingRepository;
  final WorkspaceRepository workspaceRepository;
  final ScopeCatalog catalog;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final AppServerGroup serverGroup = workspaceRepository
        .findAppServerGroup();
    final AppServerState serverState = workspaceRepository
        .findAppServerStatus()
        .state;

    return PageSection(
      title: allDevicesTitle,
      actions: <Widget>[
        AppButton.primary(
          label: _pairDeviceLabel,
          icon: AppIconKind.plus,
          onPressed: () => unawaited(_pairDevice(context)),
        ),
      ],
      children: <Widget>[
        const MutedNote(_sharedDevicesNote),
        ResponsiveList(
          columns: buildColumnsWithAction(_columnLabels),
          rows: <ListRowData>[
            for (final Device device in deviceRepository.listDevices())
              if (!device.revoked)
                _buildRow(context, device, serverGroup, serverState),
          ],
        ),
      ],
    );
  }

  Future<void> _pairDevice(BuildContext context) async {
    final ActionOutcome outcome = await runShowingRefusal(
      context: context,
      title: allDevicesTitle,
      actionLabel: _pairDeviceLabel,
      action: _showPairingCode,
    );

    if (outcome == ActionOutcome.done) {
      navigation.openRoute(const PairingCodeRoute());
    }
  }

  Future<void> _showPairingCode() async {
    if (pairingRepository.findActiveSession() == null) {
      await pairingRepository.startPairing();
    }
  }

  ListRowData _buildRow(
    BuildContext context,
    Device device,
    AppServerGroup serverGroup,
    AppServerState serverState,
  ) {
    final DeviceId thisDeviceId = deviceRepository.currentDevice().id;
    final DateTime now = clock.now();
    final AppServerMember? serverMember = findAppServerMember(
      group: serverGroup,
      deviceId: device.id,
    );
    final String workspaceNames = describeWorkspaceNames(
      device.workspaces,
      catalog,
    );

    return ListRowData(
      key: ValueKey<DeviceId>(device.id),
      main: ListRowMain.monospace(
        title: device.name,
        subtitle: <TextSegment>[
          TextSegment(
            _describeDeviceLine(device, thisDeviceId, workspaceNames),
          ),
        ],
      ),
      meta: <Widget>[
        Text(
          describeDeviceRole(role: device.role, serverMember: serverMember),
        ),
        Text(
          describeDeviceData(
            serverMember: serverMember,
            serverState: serverState,
            now: now,
          ),
        ),
        Text(
          describeDevicePresence(
            device: device,
            thisDeviceId: thisDeviceId,
            now: now,
          ),
        ),
      ],
      end: device.id == thisDeviceId
          ? null
          : AppButton.secondary(
              label: _revokeLabel,
              onPressed: () =>
                  unawaited(_reviewRevoke(context, device, workspaceNames)),
            ),
    );
  }

  String _describeDeviceLine(
    Device device,
    DeviceId thisDeviceId,
    String workspaceNames,
  ) {
    final String kindLine = describeDeviceKindLine(
      device: device,
      thisDeviceId: thisDeviceId,
    );
    if (workspaceNames.isEmpty) {
      return kindLine;
    }
    return '$kindLine · $workspaceNames';
  }

  Future<void> _reviewRevoke(
    BuildContext context,
    Device device,
    String workspaceNames,
  ) async {
    final BuildContext rootContext = Navigator.of(
      context,
      rootNavigator: true,
    ).context;
    final RevokeChoice? choice = await showAppDialog<RevokeChoice>(
      context: context,
      builder: (BuildContext _) => RevokeDeviceDialog(
        device: device,
        workspaceNames: workspaceNames,
        lastSeen: describeLastSeen(device.lastSeen, clock.now()),
        pairing: describeDevicePairing(
          device,
          DeviceNames(deviceRepository.listDevices()),
        ),
      ),
    );
    if (choice != RevokeChoice.revoke || !rootContext.mounted) {
      return;
    }

    await runShowingRefusal(
      context: rootContext,
      title: device.name,
      actionLabel: _revokeLabel,
      action: () => deviceRepository.revokeDevice(device.id),
    );
  }
}
