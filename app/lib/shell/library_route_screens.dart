import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/rules.dart';
import 'package:agent_orchestration/screens/skills/skill_detail_screen.dart';
import 'package:agent_orchestration/screens/skills/skill_form_screen.dart';
import 'package:agent_orchestration/screens/skills/skills_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

Widget buildSkillsScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return SkillsScreen(
    skillRepository: dependencies.skillRepository,
    workflowRepository: dependencies.workflowRepository,
    jobRepository: dependencies.jobRepository,
    taskRepository: dependencies.taskRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

Widget buildSkillDetailScreen({
  required SkillDetailRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return SkillDetailScreen(
    skillId: route.skillId,
    skillRepository: dependencies.skillRepository,
    workflowRepository: dependencies.workflowRepository,
    jobRepository: dependencies.jobRepository,
    taskRepository: dependencies.taskRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

Widget buildSkillFormScreen({
  required Skill? existingSkill,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return SkillFormScreen(
    existingSkill: existingSkill,
    skillRepository: dependencies.skillRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

Widget buildRulesScreen({
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return RulesScreen(
    ruleRepository: dependencies.ruleRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

Widget buildRuleDetailScreen({
  required RuleDetailRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return RuleDetailScreen(
    ruleId: route.ruleId,
    ruleRepository: dependencies.ruleRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

Widget buildRuleFormScreen({
  required Rule? existingRule,
  required ProjectId? presetProjectId,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return RuleFormScreen(
    existingRule: existingRule,
    presetProjectId: presetProjectId,
    ruleRepository: dependencies.ruleRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}
