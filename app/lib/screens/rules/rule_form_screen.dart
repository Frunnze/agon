import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

ScopeSelection buildPresetRuleScope({
  required ProjectId? presetProjectId,
  required ProjectRepository projectRepository,
}) {
  if (presetProjectId == null) {
    return ScopeSelection.everywhere();
  }

  final Project project = projectRepository.findProject(presetProjectId);
  return ScopeSelection(
    workspaceIds: <WorkspaceId>[project.workspaceId],
    projectIds: <ProjectId>[project.id],
  );
}

class RuleFormScreen extends StatelessWidget {
  const RuleFormScreen({
    required this.existingRule,
    required this.presetProjectId,
    required this.ruleRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final Rule? existingRule;
  final ProjectId? presetProjectId;
  final RuleRepository ruleRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  RuleDraft _describeInitialRule() {
    final Rule? rule = existingRule;
    if (rule != null) {
      return RuleDraft(
        title: rule.title,
        details: rule.details,
        scope: rule.scope,
      );
    }

    final ScopeSelection presetScope = buildPresetRuleScope(
      presetProjectId: presetProjectId,
      projectRepository: projectRepository,
    );
    return RuleDraft(title: '', details: '', scope: presetScope.toScope());
  }

  @override
  Widget build(BuildContext context) {
    final Rule? rule = existingRule;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: rule == null ? 'New rule' : 'Edit rule',
          backLink: BackLink(
            label: rule == null ? 'Rules' : rule.title,
            onPressed: navigation.closeRoute,
          ),
        ),
        RuleForm(
          initialRule: _describeInitialRule(),
          catalog: collectScopeCatalog(
            workspaceRepository: workspaceRepository,
            projectRepository: projectRepository,
          ),
          actions: <FormAction<RuleDraft>>[
            LeaveFormAction<RuleDraft>(
              label: 'Cancel',
              onPressed: navigation.closeRoute,
            ),
            SubmitFormAction<RuleDraft>(
              label: rule == null ? 'Add rule' : 'Save rule',
              tone: ButtonTone.primary,
              onSubmitted: _saveRule,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveRule(RuleDraft draft) async {
    final Rule? rule = existingRule;
    if (rule == null) {
      await ruleRepository.createRule(draft);
    } else {
      await ruleRepository.updateRule(rule.id, draft);
    }
    navigation.closeSavedForm();
  }
}
