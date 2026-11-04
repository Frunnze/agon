import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

const List<String> _memberColumnLabels = <String>[
  'Device',
  'Role',
  'Last seen',
  '',
];

List<Device> listWorkspaceMembers({
  required List<Device> devices,
  required WorkspaceId workspaceId,
}) {
  return <Device>[
    for (final Device device in devices)
      if (!device.revoked && device.workspaces.contains(workspaceId)) device,
  ];
}

class GeneralSettingsTab extends StatelessWidget {
  const GeneralSettingsTab({
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        workspaceRepository,
        deviceRepository,
      ]),
      builder: _buildSections,
    );
  }

  Widget _buildSections(BuildContext context, Widget? _) {
    final Workspace workspace = workspaceRepository.currentWorkspace();
    final List<Device> members = listWorkspaceMembers(
      devices: deviceRepository.listDevices(),
      workspaceId: workspace.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        AppServerSection(
          workspaceRepository: workspaceRepository,
          deviceRepository: deviceRepository,
        ),
        PageSection(
          title: 'Devices in ${workspace.name}',
          actions: <Widget>[
            AppButton.secondary(
              label: 'Add one of your devices',
              icon: AppIconKind.plus,
              onPressed: () => unawaited(_addDevice(context, workspace)),
            ),
          ],
          children: <Widget>[
            _buildRemovalNote(workspace.name),
            ResponsiveList(
              columns: buildStandardColumns(_memberColumnLabels),
              rows: <ListRowData>[
                for (final Device device in members)
                  _buildMemberRow(device, workspace.id),
              ],
            ),
          ],
        ),
        WorkspaceApprovalPolicySection(
          workspaceRepository: workspaceRepository,
        ),
        ProtectedFilesSection(workspaceRepository: workspaceRepository),
      ], pageGap),
    );
  }

  Widget _buildRemovalNote(String workspaceName) {
    final Widget note = Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text:
                'Removing a device here only takes it out of $workspaceName. '
                'To cut it off everywhere, revoke it in ',
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InlineLink(
              label: 'Your devices',
              onPressed: () => navigation.openSection(
                const SectionRoute(AppSection.devices),
              ),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );

    return DefaultTextStyle.merge(style: AppTextStyles.bodyMuted, child: note);
  }

  ListRowData _buildMemberRow(Device device, WorkspaceId workspaceId) {
    final DeviceId thisDeviceId = deviceRepository.currentDevice().id;
    final bool isThisDevice = device.id == thisDeviceId;

    return ListRowData(
      key: ValueKey<DeviceId>(device.id),
      main: ListRowMain.monospace(
        title: device.name,
        subtitle: <TextSegment>[
          if (isThisDevice) const TextSegment('This device'),
        ],
      ),
      meta: <Widget>[
        Text(device.role.label),
        Text(
          describeDeviceLastSeen(
            device: device,
            thisDeviceId: thisDeviceId,
            now: clock.now(),
          ),
        ),
      ],
      end: isThisDevice
          ? null
          : AppButton.secondary(
              label: 'Remove',
              onPressed: () => unawaited(
                deviceRepository.removeDeviceFromWorkspace(
                  device.id,
                  workspaceId,
                ),
              ),
            ),
    );
  }

  Future<void> _addDevice(BuildContext context, Workspace workspace) async {
    final List<Device> outsiders = <Device>[
      for (final Device device in deviceRepository.listDevices())
        if (!device.revoked && !device.workspaces.contains(workspace.id))
          device,
    ];

    final DeviceId? chosenDeviceId = await showAddWorkspaceDeviceDialog(
      context: context,
      workspaceName: workspace.name,
      candidates: outsiders,
    );
    if (chosenDeviceId != null) {
      await deviceRepository.addDeviceToWorkspace(
        chosenDeviceId,
        workspace.id,
      );
    }
  }
}
