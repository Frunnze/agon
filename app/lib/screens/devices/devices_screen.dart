import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/devices/all_devices_section.dart';
import 'package:agent_orchestration/screens/devices/runner_notices.dart';
import 'package:agent_orchestration/screens/devices/workspace_devices_section.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const String _pageTitle = 'Devices';
const String _missingAllDevicesProblem = 'All your devices is not on screen';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    required this.deviceRepository,
    required this.runnerRepository,
    required this.pairingRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final PairingRepository pairingRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final GlobalKey _allDevicesKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.deviceRepository,
        widget.runnerRepository,
        widget.workspaceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final String? runnerSummary = describeRunnerSummary(
      runners: widget.runnerRepository.listRunners(),
      serverState: widget.workspaceRepository.findAppServerStatus().state,
    );
    final RunnerNotices runnerNotices = RunnerNotices(
      runnerRepository: widget.runnerRepository,
      deviceRepository: widget.deviceRepository,
      workspaceRepository: widget.workspaceRepository,
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: _pageTitle,
          summary: <TextSegment>[
            if (runnerSummary != null) TextSegment(runnerSummary),
          ],
        ),
        ...runnerNotices.buildNotices(context),
        WorkspaceDevicesSection(
          workspaceRepository: widget.workspaceRepository,
          deviceRepository: widget.deviceRepository,
          runnerRepository: widget.runnerRepository,
          clock: widget.clock,
          navigation: widget.navigation,
          onShowAllDevices: _showAllDevices,
        ),
        AllDevicesSection(
          key: _allDevicesKey,
          deviceRepository: widget.deviceRepository,
          pairingRepository: widget.pairingRepository,
          workspaceRepository: widget.workspaceRepository,
          catalog: collectScopeCatalog(
            workspaceRepository: widget.workspaceRepository,
            projectRepository: widget.projectRepository,
          ),
          clock: widget.clock,
          navigation: widget.navigation,
        ),
      ],
    );
  }

  void _showAllDevices() {
    final BuildContext? allDevicesContext = _allDevicesKey.currentContext;
    if (allDevicesContext == null) {
      throw StateError(_missingAllDevicesProblem);
    }
    unawaited(Scrollable.ensureVisible(allDevicesContext));
  }
}
