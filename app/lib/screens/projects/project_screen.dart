import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const List<String> _columnLabels = <String>[
  'Repo',
  'Branch',
  'Last task',
  'Agents can',
  '',
];
const String _noTaskYet = 'None yet';
const String _browseFilesLabel = 'Browse files';
const String _removeRepositoryLabel = 'Remove';
const String _deleteLabel = 'Delete';
const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({
    required this.projectId,
    required this.projectRepository,
    required this.workspaceRepository,
    required this.taskRepository,
    required this.ruleRepository,
    required this.deviceRepository,
    required this.navigation,
    super.key,
  });

  final ProjectId projectId;
  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final TaskRepository taskRepository;
  final RuleRepository ruleRepository;
  final DeviceRepository deviceRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        projectRepository,
        workspaceRepository,
        taskRepository,
        ruleRepository,
        deviceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Project project = projectRepository.findProject(projectId);
    final ProjectWork work = collectProjectWork(
      projectId: project.id,
      tasks: taskRepository.listTasks(),
      listRuns: taskRepository.listRuns,
    );
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: project.name,
          summary: <TextSegment>[
            TextSegment(describeProjectSummary(project, work)),
          ],
          backLink: BackLink(
            label: 'Projects',
            onPressed: () => navigation.returnTo(_projectsRoute),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: _deleteLabel,
              onPressed: () => unawaited(_reviewDeletion(context, project)),
            ),
            AppButton.secondary(
              label: _browseFilesLabel,
              onPressed: project.repositories.isEmpty
                  ? null
                  : () => _openFiles(project, project.repositories.first),
            ),
            AppButton.primary(
              label: 'Add repo',
              icon: AppIconKind.plus,
              onPressed: () => showAddRepositoryDialog(
                context: context,
                project: project,
                projectRepository: projectRepository,
              ),
            ),
          ],
        ),
        if (project.repositories.isEmpty)
          const EmptyState(
            title: 'No repos yet',
            message:
                "Add a repo so this project's tasks have code to work on.",
            action: null,
          )
        else ...<Widget>[
          ResponsiveList(
            columns: buildColumnsWithAction(_columnLabels),
            rows: <ListRowData>[
              for (final Repository repository in project.repositories)
                _buildRepositoryRow(
                  context: context,
                  project: project,
                  repository: repository,
                  work: work,
                  deviceNames: deviceNames,
                ),
            ],
          ),
          const MutedNote(
            'Each run gets its own short-lived token for these repos. The '
            'token stops working when the run ends.',
          ),
        ],
        ProjectRulesSection(
          project: project,
          rules: ruleRepository.listRules(),
          catalog: _buildCatalog(),
          navigation: navigation,
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(BuildContext context, Project project) {
    return reviewDeletion(
      context: context,
      prompt: describeProjectDeletion(project),
      leavePage: () => navigation.returnTo(_projectsRoute),
      deleteRecord: () => projectRepository.deleteProject(project.id),
    );
  }

  void _openFiles(Project project, Repository repository) {
    navigation.openRoute(
      ProjectFilesRoute(
        projectId: project.id,
        repositoryAddress: repository.address,
      ),
    );
  }

  ScopeCatalog _buildCatalog() {
    final List<Workspace> workspaces = workspaceRepository.listWorkspaces();
    final List<Project> projects = <Project>[
      for (final Workspace workspace in workspaces)
        ...projectRepository.listProjects(workspace.id),
    ];

    return ScopeCatalog(workspaces: workspaces, projects: projects);
  }

  ListRowData _buildRepositoryRow({
    required BuildContext context,
    required Project project,
    required Repository repository,
    required ProjectWork work,
    required DeviceNames deviceNames,
  }) {
    return ListRowData(
      key: ValueKey<String>(repository.address),
      main: ListRowMain.monospace(
        title: describeRepositoryPath(repository.address),
        subtitle: <TextSegment>[
          TextSegment(
            describeRepositoryPlace(repository.address, deviceNames),
          ),
        ],
      ),
      meta: <Widget>[
        Text(repository.defaultBranch, style: AppTextStyles.monospace),
        Text(work.latestTaskTitle ?? _noTaskYet),
        buildAgentAccessLabel(repository.agentAccess),
      ],
      end: AppButton.secondary(
        label: _removeRepositoryLabel,
        onPressed: () => showRemoveRepositoryDialog(
          context: context,
          project: project,
          repository: repository,
          projectRepository: projectRepository,
        ),
      ),
      onTap: () => _openFiles(project, repository),
    );
  }
}
