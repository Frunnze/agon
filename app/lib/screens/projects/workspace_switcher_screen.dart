import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

class WorkspaceSwitcherScreen extends StatefulWidget {
  const WorkspaceSwitcherScreen({
    required this.dependencies,
    required this.navigation,
    super.key,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;

  @override
  State<WorkspaceSwitcherScreen> createState() =>
      _WorkspaceSwitcherScreenState();
}

class _WorkspaceSwitcherScreenState extends State<WorkspaceSwitcherScreen> {
  final OverlayPortalController _windowOverlay = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _windowOverlay.show();
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies dependencies = widget.dependencies;

    return OverlayPortal(
      controller: _windowOverlay,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildWindowOverlay,
      child: ProjectsScreen(
        projectRepository: dependencies.projectRepository,
        workspaceRepository: dependencies.workspaceRepository,
        taskRepository: dependencies.taskRepository,
        clock: dependencies.clock,
        navigation: widget.navigation,
      ),
    );
  }

  Widget _buildWindowOverlay(BuildContext context) {
    return Stack(
      children: <Widget>[
        ModalBarrier(
          color: AppColors.scrim,
          semanticsLabel: 'Close',
          onDismiss: () => widget.navigation.returnTo(
            const SectionRoute(AppSection.projects),
          ),
        ),
        AppDialogPlacement(
          child: ListenableBuilder(
            listenable: widget.dependencies.workspaceRepository,
            builder: _buildDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildDialog(BuildContext context, Widget? _) {
    final AppDependencies dependencies = widget.dependencies;

    return WorkspaceSwitcherDialog(
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      runnerRepository: dependencies.runnerRepository,
      deviceRepository: dependencies.deviceRepository,
      navigation: widget.navigation,
    );
  }
}
