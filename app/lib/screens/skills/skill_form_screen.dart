import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const SkillDraft _blankSkill = SkillDraft(
  name: '',
  summary: '',
  instructions: '',
  scope: Scope.everywhere(),
  usage: SkillUsage.automatic,
  improvement: SkillImprovement.auto,
);

SkillDraft _describeSkillDraft(Skill skill) {
  return SkillDraft(
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    improvement: skill.improvement,
  );
}

class SkillFormScreen extends StatelessWidget {
  const SkillFormScreen({
    required this.existingSkill,
    required this.skillRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final Skill? existingSkill;
  final SkillRepository skillRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final Skill? skill = existingSkill;
    final List<Skill> otherSkills = <Skill>[
      for (final Skill listed in skillRepository.listSkills())
        if (listed.id != skill?.id) listed,
    ];

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: skill == null ? 'New skill' : 'Edit skill',
          backLink: BackLink(
            label: skill == null ? 'Skills' : skill.name,
            onPressed: navigation.closeRoute,
          ),
        ),
        SkillForm(
          initialSkill: skill == null
              ? _blankSkill
              : _describeSkillDraft(skill),
          otherSkills: otherSkills,
          catalog: collectScopeCatalog(
            workspaceRepository: workspaceRepository,
            projectRepository: projectRepository,
          ),
          actions: <FormAction<SkillDraft>>[
            LeaveFormAction<SkillDraft>(
              label: 'Cancel',
              onPressed: navigation.closeRoute,
            ),
            SubmitFormAction<SkillDraft>(
              label: 'Save skill',
              tone: ButtonTone.primary,
              onSubmitted: _saveSkill,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveSkill(SkillDraft draft) async {
    final Skill? skill = existingSkill;
    if (skill == null) {
      await skillRepository.createSkill(draft);
    } else {
      await skillRepository.updateSkill(skill.id, draft);
    }
    navigation.closeSavedForm();
  }
}
