import 'dart:async';

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
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const SectionRoute _skillsRoute = SectionRoute(AppSection.skills);
const String _instructionLineBreak = '\n';

class SkillDetailScreen extends StatelessWidget {
  const SkillDetailScreen({
    required this.skillId,
    required this.skillRepository,
    required this.workflowRepository,
    required this.jobRepository,
    required this.taskRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final SkillId skillId;
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
    final Skill skill = skillRepository.findSkill(skillId);
    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );
    final String users = describeSkillUsers(
      skillId: skill.id,
      workflows: workflowRepository.listWorkflows(),
      jobs: jobRepository.listJobs(),
      tasks: taskRepository.listTasks(),
    );
    final List<String> instructionLines = skill.instructions.split(
      _instructionLineBreak,
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: skill.name,
          summary: <TextSegment>[TextSegment(skill.summary)],
          backLink: BackLink(
            label: 'Skills',
            onPressed: () => navigation.returnTo(_skillsRoute),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: 'Delete',
              onPressed: () =>
                  unawaited(_reviewDeletion(context, skill, users)),
            ),
            AppButton.primary(
              label: 'Edit',
              icon: AppIconKind.edit,
              onPressed: () => navigation.openRoute(EditSkillRoute(skill.id)),
            ),
          ],
        ),
        SplitLayout(
          start: PageSection(
            title: 'How agents use it',
            children: <Widget>[
              FactList(
                facts: <Fact>[
                  Fact(
                    term: 'When agents use it',
                    description: <TextSegment>[TextSegment(skill.usage.label)],
                  ),
                  Fact.chips(
                    term: 'Applies to',
                    chips: describeScopeChips(skill.scope, catalog),
                  ),
                  Fact(
                    term: 'Used by',
                    description: <TextSegment>[TextSegment(users)],
                  ),
                ],
              ),
            ],
          ),
          end: PageSection(
            title: 'Instructions',
            children: <Widget>[
              CodeBlock(
                lines: <CodeBlockLine>[
                  for (final String line in instructionLines)
                    CodeBlockLine(line),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(
    BuildContext context,
    Skill skill,
    String users,
  ) {
    return reviewDeletion(
      context: context,
      prompt: describeSkillDeletion(skill: skill, users: users),
      leavePage: () => navigation.returnTo(_skillsRoute),
      deleteRecord: () => skillRepository.deleteSkill(skill.id),
    );
  }
}
