import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import 'app_harness.dart';

const Size tallDesktopSize = Size(1440, 1400);
const SectionRoute workflowsSectionRoute = SectionRoute(AppSection.workflows);
const WorkflowId pipelineId = GalleryWorkflowIds.featurePipeline;

Finder findDiagramNode(String name) {
  return find.ancestor(
    of: find.descendant(
      of: find.byType(WorkflowDiagram),
      matching: find.text(name),
    ),
    matching: find.byType(AgentNodeBox),
  );
}

Workflow readPipeline(AppDependencies dependencies) {
  return dependencies.workflowRepository.findWorkflow(pipelineId);
}

WorkflowAgent findAgentNamed(Workflow workflow, String name) {
  return workflow.agents.firstWhere(
    (WorkflowAgent agent) => agent.name == name,
  );
}

Future<AppNavigation> openPipelineBuilder(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: workflowsSectionRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(
    const WorkflowBuilderRoute(
      pipelineId,
      opening: BuilderOpening.afterDrafting,
    ),
  );
  await pumpFrames(tester);
  return navigation;
}

Future<void> selectDiagramNode(WidgetTester tester, String name) async {
  await tester.tap(findDiagramNode(name));
  await pumpFrames(tester);
}

Future<void> dragBetween(
  WidgetTester tester, {
  required Offset start,
  required Offset end,
}) async {
  await tester.dragFrom(start, end - start);
  await pumpFrames(tester);
}
