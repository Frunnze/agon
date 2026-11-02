import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const List<String> _columnLabels = <String>[
  'Skill',
  'Applies to',
  'Used by',
  'When',
];

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({
    required this.skillRepository,
    required this.workflowRepository,
    required this.jobRepository,
    required this.taskRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final SkillRepository skillRepository;
  final WorkflowRepository workflowRepository;
  final JobRepository jobRepository;
  final TaskRepository taskRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        skillRepository,
        workflowRepository,
        jobRepository,
        taskRepository,
        workspaceRepository,
        projectRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final List<Skill> skills = skillRepository.listSkills();

    if (skills.isEmpty) {
      return AppPage(
        children: <Widget>[
          const PageHeader(title: 'Skills'),
          EmptyState(
            title: 'No skills yet',
            message:
                'Write the steps an agent should follow for one kind of '
                'work, like releasing the iOS app.',
            action: _buildNewSkillButton(),
          ),
        ],
      );
    }

    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Skills',
          summary: const <TextSegment>[
            TextSegment(
              'Skills are instructions an agent can follow for one kind of '
              'work.',
            ),
          ],
          actions: <Widget>[_buildNewSkillButton()],
        ),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[
            for (final Skill skill in skills) _buildRow(skill, catalog),
          ],
        ),
        const MutedNote(
          'Agents use automatic skills on their own when the work fits. '
          'Other skills run only when a task, job or workflow agent picks '
          'them.',
        ),
      ],
    );
  }

  Widget _buildNewSkillButton() {
    return AppButton.primary(
      label: 'New skill',
      icon: AppIconKind.plus,
      onPressed: () => navigation.openRoute(const NewSkillRoute()),
    );
  }

  ListRowData _buildRow(Skill skill, ScopeCatalog catalog) {
    final String users = describeSkillUsers(
      skillId: skill.id,
      workflows: workflowRepository.listWorkflows(),
      jobs: jobRepository.listJobs(),
      tasks: taskRepository.listTasks(),
    );
    final StatusTone usageTone = skill.usage == SkillUsage.automatic
        ? StatusTone.normal
        : StatusTone.muted;

    return ListRowData(
      key: ValueKey<SkillId>(skill.id),
      main: ListRowMain.monospace(
        title: skill.name,
        subtitle: <TextSegment>[TextSegment(skill.summary)],
      ),
      meta: <Widget>[Text(describeSkillReach(skill, catalog)), Text(users)],
      end: StatusLabel(text: skill.usage.label, tone: usageTone),
      onTap: () => navigation.openRoute(SkillDetailRoute(skill.id)),
    );
  }
}
