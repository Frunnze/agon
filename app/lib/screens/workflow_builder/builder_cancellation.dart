import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder/builder_header.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

Future<void> cancelBuilding({
  required BuildContext context,
  required WorkflowRepository workflowRepository,
  required Workflow openedVersion,
  required WorkflowChange? openedChange,
  required AppNavigation navigation,
}) async {
  final ActionOutcome outcome = await runShowingRefusal(
    context: context,
    title: openedVersion.name,
    actionLabel: cancelBuildingLabel,
    action: () => restoreOpenedWorkflow(
      workflowRepository: workflowRepository,
      openedVersion: openedVersion,
      openedChange: openedChange,
    ),
  );

  if (outcome == ActionOutcome.done) {
    navigation.closeRoute();
  }
}

Future<void> restoreOpenedWorkflow({
  required WorkflowRepository workflowRepository,
  required Workflow openedVersion,
  required WorkflowChange? openedChange,
}) async {
  final WorkflowId workflowId = openedVersion.id;
  final WorkflowChange? currentChange = workflowRepository.findPendingChange(
    workflowId,
  );
  final bool isChangedSinceOpening =
      openedChange == null && currentChange != null;
  if (isChangedSinceOpening) {
    await workflowRepository.discardChange(workflowId);
    return;
  }

  final Workflow currentVersion = workflowRepository.findWorkflow(workflowId);
  if (!hasSameDesign(currentVersion, openedVersion)) {
    await workflowRepository.saveWorkflow(openedVersion);
  }
}
