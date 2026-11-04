import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

final class SkillDraftReview implements DraftReview {
  const SkillDraftReview({
    required this.skillRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
  });

  final SkillRepository skillRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks) {
    return SkillForm(
      initialSkill: _requireSkill(item),
      otherSkills: skillRepository.listSkills(),
      catalog: collectScopeCatalog(
        workspaceRepository: workspaceRepository,
        projectRepository: projectRepository,
      ),
      onChanged: (SkillDraft skill) =>
          callbacks.onChanged(DraftedSkill(skill)),
      actions: buildReviewActions<SkillDraft>(
        onCancelled: callbacks.onCancelled,
        onApproved: (SkillDraft skill) =>
            callbacks.onApproved(DraftedSkill(skill)),
      ),
    );
  }

  @override
  Future<void> approve(DraftedItem item) async {
    final Skill skill = await skillRepository.createSkill(_requireSkill(item));
    navigation.replaceRoute(SkillDetailRoute(skill.id));
  }

  SkillDraft _requireSkill(DraftedItem item) {
    if (item is! DraftedSkill) {
      throw ArgumentError.value(item, 'item', 'Not a skill draft');
    }
    return item.skill;
  }
}

final class RuleDraftReview implements DraftReview {
  const RuleDraftReview({
    required this.ruleRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
  });

  final RuleRepository ruleRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks) {
    return RuleForm(
      initialRule: _requireRule(item),
      catalog: collectScopeCatalog(
        workspaceRepository: workspaceRepository,
        projectRepository: projectRepository,
      ),
      onChanged: (RuleDraft rule) => callbacks.onChanged(DraftedRule(rule)),
      actions: buildReviewActions<RuleDraft>(
        onCancelled: callbacks.onCancelled,
        onApproved: (RuleDraft rule) =>
            callbacks.onApproved(DraftedRule(rule)),
      ),
    );
  }

  @override
  Future<void> approve(DraftedItem item) async {
    await ruleRepository.createRule(_requireRule(item));
    navigation.closeRoute();
  }

  RuleDraft _requireRule(DraftedItem item) {
    if (item is! DraftedRule) {
      throw ArgumentError.value(item, 'item', 'Not a rule draft');
    }
    return item.rule;
  }
}
