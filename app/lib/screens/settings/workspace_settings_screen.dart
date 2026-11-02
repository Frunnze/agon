import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

const String _deleteWorkspaceLabel = 'Delete workspace';
const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

enum SettingsTab {
  general('General'),
  runners('Runners'),
  auditLog('Audit log');

  const SettingsTab(this.label);

  final String label;
}

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({
    required this.initialTab,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.runnerRepository,
    required this.auditRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final SettingsTab initialTab;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final AuditRepository auditRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  late SettingsTab _selectedTab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.workspaceRepository,
        widget.deviceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Workspace workspace = widget.workspaceRepository.currentWorkspace();
    final String workspaceName = workspace.name;
    final String? peerAddressProblem = widget.deviceRepository
        .findPeerAddressProblem();

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Settings',
          summary: <TextSegment>[
            TextSegment('For the $workspaceName workspace.'),
          ],
          actions: <Widget>[
            if (_selectedTab == SettingsTab.general)
              _buildDeleteButton(context, workspace),
          ],
        ),
        if (peerAddressProblem != null)
          PeerAddressBanner(problem: peerAddressProblem),
        TabStrip(
          labels: <String>[
            for (final SettingsTab tab in SettingsTab.values) tab.label,
          ],
          selectedIndex: _selectedTab.index,
          onSelected: _selectTab,
        ),
        _buildTab(),
      ],
    );
  }

  Widget _buildDeleteButton(BuildContext context, Workspace workspace) {
    final Workspace? nextWorkspace = _findNextWorkspace(workspace);
    if (nextWorkspace == null) {
      return const AppButton.secondary(
        label: _deleteWorkspaceLabel,
        onPressed: null,
      );
    }

    return AppButton.secondary(
      label: _deleteWorkspaceLabel,
      onPressed: () => unawaited(
        reviewDeletion(
          context: context,
          prompt: describeWorkspaceDeletion(
            doomed: workspace,
            next: nextWorkspace,
          ),
          leavePage: () => widget.navigation.openSection(_projectsRoute),
          deleteRecord: () =>
              widget.workspaceRepository.deleteWorkspace(workspace.id),
        ),
      ),
    );
  }

  Workspace? _findNextWorkspace(Workspace current) {
    for (final Workspace workspace
        in widget.workspaceRepository.listWorkspaces()) {
      if (workspace.id != current.id) {
        return workspace;
      }
    }
    return null;
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = SettingsTab.values[index]);
  }

  Widget _buildTab() {
    switch (_selectedTab) {
      case SettingsTab.general:
        return GeneralSettingsTab(
          workspaceRepository: widget.workspaceRepository,
          deviceRepository: widget.deviceRepository,
          clock: widget.clock,
          navigation: widget.navigation,
        );
      case SettingsTab.runners:
        return RunnersSettingsTab(
          runnerRepository: widget.runnerRepository,
          deviceRepository: widget.deviceRepository,
          workspaceRepository: widget.workspaceRepository,
          clock: widget.clock,
          navigation: widget.navigation,
        );
      case SettingsTab.auditLog:
        return AuditLogTab(
          auditRepository: widget.auditRepository,
          deviceRepository: widget.deviceRepository,
          clock: widget.clock,
        );
    }
  }
}
