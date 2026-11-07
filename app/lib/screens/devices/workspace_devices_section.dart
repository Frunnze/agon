import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/devices/add_workspace_device_dialog.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';

const String allDevicesTitle = 'All your devices';
const String _noSlotsText = '—';
const List<String> _memberColumnLabels = <String>[
  'Device',
  'Role',
  'Slots',
  'Status',
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

Runner? findDeviceRunner({
  required List<Runner> runners,
  required DeviceId deviceId,
}) {
  for (final Runner runner in runners) {
    if (runner.deviceId == deviceId) {
      return runner;
    }
  }
  return null;
}

const String _addDeviceLabel = 'Add a device';
const String _removeDeviceLabel = 'Remove';

class WorkspaceDevicesSection extends StatelessWidget {
  const WorkspaceDevicesSection({
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.runnerRepository,
    required this.clock,
    required this.navigation,
    required this.onShowAllDevices,
    super.key,
  });

  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final Clock clock;
  final AppNavigation navigation;
  final VoidCallback onShowAllDevices;

  @override
  Widget build(BuildContext context) {
    final Workspace workspace = workspaceRepository.currentWorkspace();
    final List<Device> members = listWorkspaceMembers(
      devices: deviceRepository.listDevices(),
      workspaceId: workspace.id,
    );

    return PageSection(
      title: 'In ${workspace.name}',
      actions: <Widget>[
        AppButton.secondary(
          label: _addDeviceLabel,
          icon: AppIconKind.plus,
          onPressed: () => unawaited(_addDevice(context, workspace)),
        ),
      ],
      children: <Widget>[
        _buildRemovalNote(workspace.name),
        ResponsiveList(
          columns: buildColumnsWithAction(_memberColumnLabels),
          rows: <ListRowData>[
            for (final Device device in members)
              _buildMemberRow(context, device, workspace.id),
          ],
        ),
      ],
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
              label: allDevicesTitle,
              onPressed: onShowAllDevices,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );

    return DefaultTextStyle.merge(style: AppTextStyles.bodyMuted, child: note);
  }

  ListRowData _buildMemberRow(
    BuildContext context,
    Device device,
    WorkspaceId workspaceId,
  ) {
    final DeviceId thisDeviceId = deviceRepository.currentDevice().id;
    final AppServerMember? serverMember = findAppServerMember(
      group: workspaceRepository.findAppServerGroup(),
      deviceId: device.id,
    );
    final Runner? runner = findDeviceRunner(
      runners: runnerRepository.listRunners(),
      deviceId: device.id,
    );
    final String kindLine = describeDeviceKindLine(
      device: device,
      thisDeviceId: thisDeviceId,
    );
    final String deviceLine = runner == null
        ? kindLine
        : '$kindLine · ${describeRunnerOffers(runner.offers)}';

    return ListRowData(
      key: ValueKey<DeviceId>(device.id),
      main: ListRowMain.monospace(
        title: device.name,
        subtitle: <TextSegment>[TextSegment(deviceLine)],
      ),
      meta: <Widget>[
        Text(
          describeDeviceRole(role: device.role, serverMember: serverMember),
        ),
        ..._buildRunnerMeta(device, thisDeviceId, runner),
      ],
      end: device.id == thisDeviceId
          ? null
          : AppButton.secondary(
              label: _removeDeviceLabel,
              onPressed: () => unawaited(
                _removeDevice(
                  context,
                  device: device,
                  workspaceId: workspaceId,
                ),
              ),
            ),
      onTap: runner == null
          ? null
          : () => navigation.openRoute(RunnerDetailRoute(device.id)),
    );
  }

  List<Widget> _buildRunnerMeta(
    Device device,
    DeviceId thisDeviceId,
    Runner? runner,
  ) {
    if (runner == null) {
      final String presence = describeDevicePresence(
        device: device,
        thisDeviceId: thisDeviceId,
        now: clock.now(),
      );
      return <Widget>[const Text(_noSlotsText), Text(presence)];
    }

    final AppServerState serverState = workspaceRepository
        .findAppServerStatus()
        .state;
    final RunnerReach reach = findRunnerReach(runner, serverState);
    return <Widget>[
      _buildSlots(runner, reach),
      buildRunnerStatusLabel(runner: runner, reach: reach),
    ];
  }

  Widget _buildSlots(Runner runner, RunnerReach reach) {
    switch (reach) {
      case RunnerReach.reachable:
        return SlotsIndicator(
          total: runner.slotsTotal,
          busy: runner.slotsBusy,
        );
      case RunnerReach.offline:
        return const Text('None free');
      case RunnerReach.needsServer:
        return const Text('Unknown');
    }
  }

  Future<void> _removeDevice(
    BuildContext context, {
    required Device device,
    required WorkspaceId workspaceId,
  }) {
    return runShowingRefusal(
      context: context,
      title: device.name,
      actionLabel: _removeDeviceLabel,
      action: () =>
          deviceRepository.removeDeviceFromWorkspace(device.id, workspaceId),
    );
  }

  Future<void> _addDevice(BuildContext context, Workspace workspace) async {
    final BuildContext rootContext = Navigator.of(
      context,
      rootNavigator: true,
    ).context;
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
    if (chosenDeviceId == null || !rootContext.mounted) {
      return;
    }

    await runShowingRefusal(
      context: rootContext,
      title: _addDeviceLabel,
      actionLabel: _addDeviceLabel,
      action: () =>
          deviceRepository.addDeviceToWorkspace(chosenDeviceId, workspace.id),
    );
  }
}
