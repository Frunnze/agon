import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/bottom_tabs.dart';
import 'package:agent_orchestration/shell/route_pages.dart';
import 'package:agent_orchestration/shell/side_rail.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

const String accountLoadingText = 'Loading your account…';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.dependencies,
    required this.navigation,
    required this.runWindowOpener,
    super.key,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;
  final RunWindowOpener? runWindowOpener;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final AppDependencies dependencies = widget.dependencies;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.navigation,
        dependencies.approvalRepository,
        dependencies.personStepRepository,
        dependencies.workspaceRepository,
        dependencies.deviceRepository,
      ]),
      builder: _buildFrame,
    );
  }

  Widget _buildFrame(BuildContext context, Widget? _) {
    final AppDependencies dependencies = widget.dependencies;
    final bool isSettingUp = widget.navigation.currentRoute is SetupRoute;
    if (!isSettingUp && !_hasLoadedAccount(dependencies)) {
      return const Scaffold(body: Center(child: Text(accountLoadingText)));
    }

    final AppSection currentSection = widget.navigation.currentRoute.section;
    final int pendingApprovalCount = dependencies.approvalRepository
        .listPendingApprovals()
        .length;
    final int openQuestionCount = dependencies.personStepRepository
        .listOpenPersonSteps()
        .length;
    final int pendingCount = pendingApprovalCount + openQuestionCount;
    final Widget content = NavigatorPopHandler<Object?>(
      onPopWithResult: _popContentPage,
      child: Navigator(
        key: _contentNavigatorKey,
        pages: buildRoutePages(
          routes: widget.navigation.routes,
          dependencies: dependencies,
          navigation: widget.navigation,
          runWindowOpener: widget.runWindowOpener,
        ),
        onDidRemovePage: _handleRemovedPage,
      ),
    );

    if (isSettingUp) {
      return Scaffold(body: SafeArea(child: content));
    }

    if (LayoutSize.of(context).isCompact) {
      return Scaffold(
        body: SafeArea(bottom: false, child: content),
        bottomNavigationBar: BottomTabs(
          currentSection: currentSection,
          pendingApprovalCount: pendingCount,
          onSectionSelected: _openSection,
        ),
      );
    }

    final Device device = dependencies.deviceRepository.currentDevice();
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SideRail(
            workspaceName: dependencies.workspaceRepository
                .currentWorkspace()
                .name,
            deviceSummary: '${device.name} · ${device.role.label}',
            currentSection: currentSection,
            pendingApprovalCount: pendingCount,
            onSectionSelected: _openSection,
            onWorkspacePressed: _openWorkspaceSwitcher,
          ),
          Expanded(child: SafeArea(left: false, child: content)),
        ],
      ),
    );
  }

  bool _hasLoadedAccount(AppDependencies dependencies) {
    final bool hasDevices = dependencies.deviceRepository
        .listDevices()
        .isNotEmpty;
    final bool hasWorkspaces = dependencies.workspaceRepository
        .listWorkspaces()
        .isNotEmpty;
    return hasDevices && hasWorkspaces;
  }

  void _openSection(AppSection section) {
    widget.navigation.openSection(SectionRoute(section));
  }

  void _openWorkspaceSwitcher() {
    widget.navigation.openRoute(const WorkspaceSwitcherRoute());
  }

  void _popContentPage(Object? _) {
    _contentNavigatorKey.currentState?.maybePop().ignore();
  }

  void _handleRemovedPage(Page<Object?> page) {
    if (widget.navigation.routes.length > 1) {
      widget.navigation.closeRoute();
    }
  }
}
