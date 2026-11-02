import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/presentation/server_group_text.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

typedef _ServerBackupChange = Future<AppServerGroup> Function();

const String _sectionTitle = 'App server';
const String _standaloneServerText =
    'Relays messages and keeps the run queue. It sees only encrypted data.';
const String _keepBackupLabel = 'Keep a backup of the server';

StatusLabel buildAppServerStatusLabel(AppServerState state) {
  switch (state) {
    case AppServerState.online:
      return const StatusLabel(
        text: 'Online',
        tone: StatusTone.normal,
        icon: AppIconKind.online,
      );
    case AppServerState.unreachable:
      return const StatusLabel(
        text: 'Unreachable',
        tone: StatusTone.attention,
        icon: AppIconKind.offline,
      );
  }
}

class AppServerSection extends StatefulWidget {
  const AppServerSection({
    required this.workspaceRepository,
    required this.deviceRepository,
    super.key,
  });

  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;

  @override
  State<AppServerSection> createState() => _AppServerSectionState();
}

class _AppServerSectionState extends State<AppServerSection> {
  bool _isChangingBackup = false;
  String? _backupProblem;

  @override
  Widget build(BuildContext context) {
    final AppServerStatus server = widget.workspaceRepository
        .findAppServerStatus();
    final AppServerGroup group = widget.workspaceRepository
        .findAppServerGroup();

    return PageSection(
      title: _sectionTitle,
      children: <Widget>[
        ResponsiveList.plain(rows: _buildRows(server, group)),
      ],
    );
  }

  List<ListRowData> _buildRows(AppServerStatus server, AppServerGroup group) {
    if (group.members.isEmpty) {
      return <ListRowData>[_buildStandaloneRow(server)];
    }

    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );
    final DeviceId currentDeviceId = widget.deviceRepository
        .currentDevice()
        .id;
    final List<AppServerMember> members = orderAppServerMembers(group.members);

    return <ListRowData>[
      for (final AppServerMember member in members)
        _buildMemberRow(
          member: member,
          deviceName: deviceNames.describeDevice(member.deviceId),
          description: describeAppServerMember(
            member,
            currentDeviceId: currentDeviceId,
          ),
          serverState: server.state,
        ),
      if (group.canKeepBackup) _buildBackupToggleRow(group),
    ];
  }

  ListRowData _buildStandaloneRow(AppServerStatus server) {
    return ListRowData(
      main: ListRowMain.monospace(
        title: describeServerHost(server.address),
        subtitle: const <TextSegment>[TextSegment(_standaloneServerText)],
      ),
      end: buildAppServerStatusLabel(server.state),
    );
  }

  ListRowData _buildMemberRow({
    required AppServerMember member,
    required String deviceName,
    required String description,
    required AppServerState serverState,
  }) {
    final bool isActive = member.standing == ServerStanding.active;

    return ListRowData(
      main: ListRowMain.monospace(
        title: deviceName,
        subtitle: <TextSegment>[TextSegment(description)],
      ),
      end: isActive ? buildAppServerStatusLabel(serverState) : null,
    );
  }

  ListRowData _buildBackupToggleRow(AppServerGroup group) {
    final ThisDeviceStanding standing = group.thisDeviceStanding;
    final String hint = _backupProblem ?? describeServerBackupHint(standing);

    return ListRowData(
      main: ListRowMain(
        title: _keepBackupLabel,
        subtitle: <TextSegment>[TextSegment(hint)],
      ),
      end: SwitchToggle(
        semanticLabel: _keepBackupLabel,
        value: standing != ThisDeviceStanding.none,
        onChanged: _chooseBackupSwitchHandler(standing),
      ),
    );
  }

  ValueChanged<bool>? _chooseBackupSwitchHandler(ThisDeviceStanding standing) {
    if (_isChangingBackup) {
      return null;
    }

    return switch (standing) {
      ThisDeviceStanding.active => null,
      ThisDeviceStanding.backup => _turnServerBackupOff,
      ThisDeviceStanding.none => _turnServerBackupOn,
    };
  }

  void _turnServerBackupOn(bool _) {
    unawaited(
      _changeServerBackup(widget.workspaceRepository.startServerBackup),
    );
  }

  void _turnServerBackupOff(bool _) {
    unawaited(
      _changeServerBackup(widget.workspaceRepository.stopServerBackup),
    );
  }

  Future<void> _changeServerBackup(_ServerBackupChange change) async {
    setState(() {
      _isChangingBackup = true;
      _backupProblem = null;
    });

    try {
      await change();
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _backupProblem = explanation);
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingBackup = false);
      }
    }
  }
}
