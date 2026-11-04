import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/form_finders.dart';

const String _askHint = 'Ask the agent, e.g. add a test step after ios';
const WorkflowId _signedWorkflowId = GalleryWorkflowIds.release;

void main() {
  testWidgets('asking the agent changes the workflow', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    final Finder askField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == _askHint,
    );

    await tester.tap(find.text('Ask'));
    await pumpFrames(tester);
    expect(find.text('Say what the agent should change'), findsOneWidget);

    await tester.enterText(askField, 'add a test step after ios');
    await tester.tap(find.text('Ask'));
    await pumpFrames(tester);

    final Workflow changed = readPipeline(dependencies);
    expect(changed.agents.length, 6);
    expect(changed.agents.last.task, 'add a test step after ios');
    expect(findDiagramNode('requested-step'), findsOneWidget);
  });

  testWidgets('removing an agent drops it and its arrows', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    final WorkflowAgentId backendId = findAgentNamed(
      readPipeline(dependencies),
      'backend',
    ).id;
    await selectDiagramNode(tester, 'backend');

    await tapVisible(tester, find.text('Remove agent'));
    await pumpFrames(tester);

    final Workflow remaining = readPipeline(dependencies);
    expect(remaining.agents.length, 4);
    for (final AgentConnection connection in remaining.connections) {
      expect(connection.from, isNot(backendId));
      expect(connection.to, isNot(backendId));
    }
    expect(findDiagramNode('backend'), findsNothing);
    expect(find.text('Agent settings'), findsNothing);
  });

  testWidgets('dragging between dots connects or starts a loop', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    final Workflow before = readPipeline(dependencies);
    final AgentConnection backendToIos = AgentConnection(
      from: findAgentNamed(before, 'backend').id,
      to: findAgentNamed(before, 'ios').id,
      condition: null,
      roundLimit: null,
    );

    await dragBetween(
      tester,
      start: tester.getRect(findDiagramNode('backend')).bottomCenter,
      end: tester.getCenter(findDiagramNode('ios')),
    );
    expect(readPipeline(dependencies).connections, contains(backendToIos));

    await dragBetween(
      tester,
      start: tester.getRect(findDiagramNode('review')).bottomCenter,
      end: tester.getCenter(findDiagramNode('plan')),
    );
    expect(find.text('New loop'), findsOneWidget);
    expect(find.text('review → plan'), findsOneWidget);

    await dragBetween(
      tester,
      start: tester.getRect(findDiagramNode('ship')).topCenter,
      end: tester.getCenter(findDiagramNode('ship')),
    );
    expect(find.text("A step can't feed into itself"), findsOneWidget);
    expect(
      readPipeline(dependencies).connections.length,
      before.connections.length + 1,
    );
  });

  testWidgets('dragging a box moves it', (WidgetTester tester) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    final CanvasPosition start = findAgentNamed(
      readPipeline(dependencies),
      'review',
    ).position;
    final Offset centre = tester.getCenter(findDiagramNode('review'));

    await dragBetween(
      tester,
      start: centre,
      end: centre + const Offset(60, 40),
    );

    final CanvasPosition moved = findAgentNamed(
      readPipeline(dependencies),
      'review',
    ).position;
    expect(moved.horizontal, closeTo(start.horizontal + 60, 1));
    expect(moved.vertical, closeTo(start.vertical + 40, 1));
  });

  testWidgets('sign and save signs a complete workflow in one tap', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    await tester.tap(find.text('Add agent'));
    await pumpFrames(tester);

    await tester.tap(find.text('Sign and save'));
    await pumpFrames(tester);
    expect(find.text('Choose an agent for new-agent'), findsOneWidget);
    expect(readPipeline(dependencies).signature, isNull);

    await tapVisible(tester, find.text('Remove agent'));
    await pumpFrames(tester);
    await tester.tap(find.text('Sign and save'));
    await pumpFrames(tester);

    expect(readPipeline(dependencies).signature, isNotNull);
    expect(navigation.routes, <AppRoute>[workflowsSectionRoute]);
    expect(find.text('Not signed yet'), findsNothing);
  });

  testWidgets('cancel puts back the version that was opened', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await openPipelineBuilder(
      tester,
      size: phoneSize,
      dependencies: dependencies,
    );
    await tapVisible(tester, find.text('Add agent'));
    await pumpFrames(tester);
    expect(readPipeline(dependencies).agents.length, 6);

    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);

    expect(readPipeline(dependencies).agents.length, 5);
    expect(navigation.routes, <AppRoute>[workflowsSectionRoute]);
  });

  testWidgets('cancel without a change saves nothing and stays signed', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final WorkflowRepository repository = dependencies.workflowRepository;
    final AppNavigation navigation = await pumpApp(
      tester,
      size: tallDesktopSize,
      route: workflowsSectionRoute,
      dependencies: dependencies,
    );
    navigation.openRoute(
      const WorkflowBuilderRoute(
        _signedWorkflowId,
        opening: BuilderOpening.forEditing,
      ),
    );
    await pumpFrames(tester);
    final Workflow opened = repository.findWorkflow(_signedWorkflowId);
    int savedCount = 0;
    repository.addListener(() => savedCount += 1);

    await tapVisible(tester, find.text(fitLabel));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);

    final Workflow afterCancel = repository.findWorkflow(_signedWorkflowId);
    expect(savedCount, 0);
    expect(afterCancel, same(opened));
    expect(afterCancel.signature, isNotNull);
    expect(navigation.routes, <AppRoute>[workflowsSectionRoute]);
  });
}
