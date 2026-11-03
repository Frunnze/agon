import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/devices/revoke_device_dialog.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const List<String> _columnLabels = <String>[
  'Device',
  'Role',
  'Workspaces',
  'Last seen',
  '',
];

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({
    required this.deviceRepository,
    required this.pairingRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final DeviceRepository deviceRepository;
  final PairingRepository pairingRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        deviceRepository,
        workspaceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Your devices',
          summary: const <TextSegment>[
            TextSegment(
              'Shared by all your workspaces. Pair once, revoke once.',
            ),
          ],
          actions: <Widget>[
            AppButton.primary(
              label: 'Add device',
              icon: AppIconKind.plus,
              onPressed: () => unawaited(_addDevice()),
            ),
          ],
        ),
        ResponsiveList(
          columns: buildColumnsWithAction(_columnLabels),
          rows: <ListRowData>[
            for (final Device device in deviceRepository.listDevices())
              if (!device.revoked) _buildRow(context, device, catalog),
          ],
        ),
      ],
    );
  }

  Future<void> _addDevice() async {
    if (pairingRepository.findActiveSession() == null) {
      await pairingRepository.startPairing();
    }
    navigation.openRoute(const PairingCodeRoute());
  }

  ListRowData _buildRow(
    BuildContext context,
    Device device,
    ScopeCatalog catalog,
  ) {
    final DeviceId currentDeviceId = deviceRepository.currentDevice().id;
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
            describeDeviceKey(
              device: device,
              currentDeviceId: currentDeviceId,
            ),
          ),
        ],
      ),
      meta: <Widget>[
        Text(device.role.label),
        Text(workspaceNames),
        Text(
          describeDeviceLastSeen(
            device: device,
            thisDeviceId: currentDeviceId,
            now: clock.now(),
          ),
        ),
      ],
      end: device.id == currentDeviceId
          ? null
          : AppButton.secondary(
              label: 'Revoke',
              onPressed: () =>
                  unawaited(_reviewRevoke(context, device, workspaceNames)),
            ),
    );
  }

  Future<void> _reviewRevoke(
    BuildContext context,
    Device device,
    String workspaceNames,
  ) async {
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
    if (choice != RevokeChoice.revoke) {
      return;
    }

    await deviceRepository.revokeDevice(device.id);
  }
}
