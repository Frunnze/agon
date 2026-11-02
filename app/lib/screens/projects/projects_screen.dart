import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const List<String> _columnLabels = <String>[
  'Project',
  'Repos',
  'Tasks',
  'Activity',
];

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    required this.projectRepository,
    required this.workspaceRepository,
    required this.taskRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final TaskRepository taskRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        projectRepository,
        workspaceRepository,
        taskRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Workspace workspace = workspaceRepository.currentWorkspace();
    final List<Project> projects = projectRepository.listProjects(
      workspace.id,
    );

    if (projects.isEmpty) {
      return AppPage(
        children: <Widget>[
          _buildHeading(
            context: context,
            workspace: workspace,
            header: const PageHeader(title: 'Projects'),
          ),
          EmptyState(
            title: 'No projects yet',
            message: 'Add a project with the repos its tasks should work on.',
            action: _buildNewProjectButton(),
          ),
        ],
      );
    }

    final PageHeader header = PageHeader(
      title: 'Projects',
      summary: const <TextSegment>[
        TextSegment('Each project holds the repos its tasks work on.'),
      ],
      actions: <Widget>[_buildNewProjectButton()],
    );
    return AppPage(
      children: <Widget>[
        _buildHeading(context: context, workspace: workspace, header: header),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[
            for (final Project project in projects) _buildRow(project),
          ],
        ),
      ],
    );
  }

  Widget _buildHeading({
    required BuildContext context,
    required Workspace workspace,
    required PageHeader header,
  }) {
    if (!LayoutSize.of(context).isCompact) {
      return header;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        WorkspaceLinkButton(
          workspaceName: workspace.name,
          onPressed: () =>
              navigation.openRoute(const WorkspaceSwitcherRoute()),
        ),
        const SizedBox(height: AppSpacing.space1),
        header,
      ],
    );
  }

  Widget _buildNewProjectButton() {
    return AppButton.primary(
      label: 'New project',
      icon: AppIconKind.plus,
      onPressed: () => navigation.openRoute(const NewProjectRoute()),
    );
  }

  ListRowData _buildRow(Project project) {
    return buildProjectRow(
      project: project,
      work: collectProjectWork(
        projectId: project.id,
        tasks: taskRepository.listTasks(),
        listRuns: taskRepository.listRuns,
      ),
      now: clock.now(),
      onTap: () => navigation.openRoute(ProjectRoute(project.id)),
    );
  }
}
