import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/screens/new_items/new_item_sources.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/library_route_screens.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';
import 'package:agent_orchestration/shell/workflow_route_screens.dart';

String describeStartingProject(String projectName) {
  return 'the project $projectName';
}

String describeStartingWorkflow(String workflowName) {
  return 'the workflow $workflowName, which should do the work';
}

DraftReview _buildDraftReview({
  required DraftKind kind,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return switch (kind) {
    DraftKind.task || DraftKind.job => WorkDraftReview(
      kind: kind,
      buildOptions: (RunnerTarget chosenTarget) => buildTaskFormOptionsFor(
        dependencies: dependencies,
        chosenTarget: chosenTarget,
      ),
      taskRepository: dependencies.taskRepository,
      jobRepository: dependencies.jobRepository,
      navigation: navigation,
    ),
    DraftKind.skill => SkillDraftReview(
      skillRepository: dependencies.skillRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: navigation,
    ),
    DraftKind.rule => RuleDraftReview(
      ruleRepository: dependencies.ruleRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: navigation,
    ),
  };
}

Widget buildNewItemScreen({
  required NewItemFormRoute formRoute,
  required String? startedFrom,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return NewItemScreen(
    kind: formRoute.kind,
    startedFrom: startedFrom,
    sources: NewItemSources(
      itemDraftRepository: dependencies.itemDraftRepository,
      runnerRepository: dependencies.runnerRepository,
      deviceRepository: dependencies.deviceRepository,
    ),
    review: _buildDraftReview(
      kind: formRoute.kind,
      dependencies: dependencies,
      navigation: navigation,
    ),
    formRoute: formRoute,
    navigation: navigation,
  );
}

Widget buildNewRuleScreen({
  required NewRuleRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  final ProjectId? presetProjectId = route.presetProjectId;
  final String? startedFrom = presetProjectId == null
      ? null
      : describeStartingProject(
          dependencies.projectRepository.findProject(presetProjectId).name,
        );

  return buildNewItemScreen(
    formRoute: NewItemFormRoute(
      DraftKind.rule,
      presetProjectId: presetProjectId,
    ),
    startedFrom: startedFrom,
    dependencies: dependencies,
    navigation: navigation,
  );
}

Widget buildNewWorkflowTaskScreen({
  required NewWorkflowTaskRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  final String workflowName = dependencies.workflowRepository
      .findWorkflow(route.workflowId)
      .name;

  return buildNewItemScreen(
    formRoute: NewItemFormRoute(
      DraftKind.task,
      presetWorkflowId: route.workflowId,
    ),
    startedFrom: describeStartingWorkflow(workflowName),
    dependencies: dependencies,
    navigation: navigation,
  );
}

Widget buildNewItemForm({
  required NewItemFormRoute route,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  final WorkflowId? presetWorkflowId = route.presetWorkflowId;
  switch (route.kind) {
    case DraftKind.task when presetWorkflowId != null:
      return buildWorkflowTaskFormScreen(
        workflowId: presetWorkflowId,
        dependencies: dependencies,
        navigation: navigation,
      );
    case DraftKind.task:
      return buildTaskFormScreen(
        existingTask: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case DraftKind.job:
      return buildJobFormScreen(
        existingJob: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case DraftKind.skill:
      return buildSkillFormScreen(
        existingSkill: null,
        dependencies: dependencies,
        navigation: navigation,
      );
    case DraftKind.rule:
      return buildRuleFormScreen(
        existingRule: null,
        presetProjectId: route.presetProjectId,
        dependencies: dependencies,
        navigation: navigation,
      );
  }
}
