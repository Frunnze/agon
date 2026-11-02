import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

class WorkspaceSwitcherDialog extends StatefulWidget {
  const WorkspaceSwitcherDialog({
    required this.workspaceRepository,
    required this.projectRepository,
    required this.runnerRepository,
    required this.deviceRepository,
    required this.navigation,
    super.key,
  });

  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final RunnerRepository runnerRepository;
  final DeviceRepository deviceRepository;
  final AppNavigation navigation;

  @override
  State<WorkspaceSwitcherDialog> createState() =>
      _WorkspaceSwitcherDialogState();
}

class _WorkspaceSwitcherDialogState extends State<WorkspaceSwitcherDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;
  String? _nameProblem;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) {
      return _buildCreateForm();
    }

    return AppDialog(
      title: 'Switch workspace',
      content: <Widget>[
        ResponsiveList.plain(
          rows: <ListRowData>[
            for (final Workspace workspace
                in widget.workspaceRepository.listWorkspaces())
              _buildRow(workspace),
          ],
        ),
        const DialogNote(
          'Each workspace has its own projects and picks which of your '
          'devices it uses. Devices are paired once for all of them.',
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(label: 'Close', onPressed: _close),
        AppButton.secondary(
          label: 'Your devices',
          icon: AppIconKind.key,
          onPressed: () => widget.navigation.openSection(
            const SectionRoute(AppSection.devices),
          ),
        ),
        AppButton.secondary(
          label: 'Create workspace',
          icon: AppIconKind.plus,
          onPressed: () => setState(() => _isCreating = true),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return AppDialog(
      title: 'Create workspace',
      content: <Widget>[
        FormFieldBlock(
          label: 'Name',
          hint: 'It uses the same app server as this workspace.',
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(errorText: _nameProblem),
            ),
          ],
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Back',
          onPressed: () => setState(() => _isCreating = false),
        ),
        AppButton.primary(
          label: 'Create workspace',
          icon: AppIconKind.plus,
          onPressed: _createWorkspace,
        ),
      ],
    );
  }

  ListRowData _buildRow(Workspace workspace) {
    final bool isCurrent =
        workspace.id == widget.workspaceRepository.currentWorkspace().id;
    final String contents = describeWorkspaceContents(
      projectCount: widget.projectRepository.listProjects(workspace.id).length,
      runnerCount: countWorkspaceRunners(
        workspaceId: workspace.id,
        runners: widget.runnerRepository.listRunners(),
        devices: widget.deviceRepository.listDevices(),
      ),
    );

    return ListRowData(
      key: ValueKey<String>(workspace.id.value),
      main: ListRowMain(
        title: workspace.name,
        subtitle: <TextSegment>[TextSegment(contents)],
      ),
      end: isCurrent
          ? const StatusLabel(
              text: 'Current',
              tone: StatusTone.normal,
              icon: AppIconKind.check,
            )
          : const RowAction(label: 'Open'),
      emphasis: isCurrent ? RowEmphasis.current : RowEmphasis.normal,
      onTap: isCurrent ? _close : () => _openWorkspace(workspace),
    );
  }

  void _close() {
    widget.navigation.returnTo(_projectsRoute);
  }

  Future<void> _openWorkspace(Workspace workspace) async {
    await widget.workspaceRepository.switchWorkspace(workspace.id);
    widget.navigation.openSection(_projectsRoute);
  }

  Future<void> _createWorkspace() async {
    final String name = _nameController.text.trim();
    final String? problem = describeNameProblem(name);
    if (problem != null) {
      setState(() => _nameProblem = problem);
      return;
    }

    final Workspace created = await widget.workspaceRepository.createWorkspace(
      name: name,
    );
    await widget.workspaceRepository.switchWorkspace(created.id);
    widget.navigation.openSection(_projectsRoute);
  }
}
