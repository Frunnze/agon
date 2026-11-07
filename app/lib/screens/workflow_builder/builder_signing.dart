import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder/builder_header.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

Future<void> signBuiltWorkflow({
  required BuildContext context,
  required WorkflowRepository workflowRepository,
  required Workflow workflow,
  required AppNavigation navigation,
}) async {
  final ActionOutcome outcome = await runShowingRefusal(
    context: context,
    title: workflow.name,
    actionLabel: signAndSaveLabel,
    action: () => workflowRepository.signWorkflow(workflow.id),
  );

  if (outcome == ActionOutcome.done) {
    navigation.openSection(_workflowsRoute);
  }
}
