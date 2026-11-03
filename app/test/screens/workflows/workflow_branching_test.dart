import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/form_finders.dart';

AgentConnection _findConnectionNamed(
  Workflow workflow, {
  required String from,
  required String to,
}) {
  final WorkflowAgent source = findAgentNamed(workflow, from);
  final WorkflowAgent target = findAgentNamed(workflow, to);
  return workflow.connections.firstWhere(
    (AgentConnection connection) =>
        connection.from == source.id && connection.to == target.id,
  );
}

Future<void> _tapArrowBetween(
  WidgetTester tester, {
  required String from,
  required String to,
}) async {
  final Offset start = tester.getRect(findDiagramNode(from)).bottomCenter;
  final Offset end = tester.getRect(findDiagramNode(to)).topCenter;
  await tester.tapAt(Offset.lerp(start, end, 0.5)!);
  await pumpFrames(tester);
}

Future<void> _drawLoopFromReviewToPlan(WidgetTester tester) async {
  await dragBetween(
    tester,
    start: tester.getRect(findDiagramNode('review')).bottomCenter,
    end: tester.getCenter(findDiagramNode('plan')),
  );
}

Future<void> _chooseRounds(WidgetTester tester, String rounds) async {
  await tapVisible(tester, findFieldText(roundsLabel, chooseRoundsLabel));
  await pumpFrames(tester);
  await tester.tap(find.text(rounds).last);
  await pumpFrames(tester);
}

void main() {
  testWidgets('adding a person step shows You and asks for its question', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await tester.tap(find.text(addPersonStepLabel));
    await pumpFrames(tester);
    await enterFieldText(tester, label: questionLabel, text: 'Ship it?');
    await pumpFrames(tester);

    final WorkflowAgent person = findAgentNamed(
      readPipeline(dependencies),
      'new-person-step',
    );
    expect(person.stepKind, StepKind.person);
    expect(person.task, 'Ship it?');
    expect(find.text(personStepPanelTitle), findsOneWidget);
    expect(findFieldInput('Task'), findsNothing);
    expect(
      find.descendant(
        of: findDiagramNode('new-person-step'),
        matching: find.text(personKindText),
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting an arrow sets and clears its outcome', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await _tapArrowBetween(tester, from: 'review', to: 'ship');
    expect(find.text(connectionPanelTitle), findsOneWidget);
    expect(find.text('review → ship'), findsOneWidget);

    await enterFieldText(tester, label: outcomeLabel, text: 'approved');
    await pumpFrames(tester);
    final AgentConnection named = _findConnectionNamed(
      readPipeline(dependencies),
      from: 'review',
      to: 'ship',
    );
    expect(named.condition, 'approved');
    expect(
      find.descendant(
        of: find.byType(WorkflowDiagram),
        matching: find.text('approved'),
      ),
      findsOneWidget,
    );

    await enterFieldText(tester, label: outcomeLabel, text: 'Bad Name');
    await pumpFrames(tester);
    expect(find.text(outcomeFormatProblem), findsOneWidget);

    await enterFieldText(tester, label: outcomeLabel, text: '');
    await pumpFrames(tester);
    final AgentConnection cleared = _findConnectionNamed(
      readPipeline(dependencies),
      from: 'review',
      to: 'ship',
    );
    expect(cleared.condition, isNull);
  });

  testWidgets('a repeated outcome from one step is refused', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await _tapArrowBetween(tester, from: 'plan', to: 'backend');
    await enterFieldText(tester, label: outcomeLabel, text: 'approved');
    await pumpFrames(tester);
    await _tapArrowBetween(tester, from: 'plan', to: 'ios');
    await enterFieldText(tester, label: outcomeLabel, text: 'approved');
    await pumpFrames(tester);

    expect(
      find.text('Another connection from plan already uses approved'),
      findsOneWidget,
    );
    final AgentConnection unchanged = _findConnectionNamed(
      readPipeline(dependencies),
      from: 'plan',
      to: 'ios',
    );
    expect(unchanged.condition, isNull);
  });

  testWidgets('drawing back to an earlier step adds a limited loop', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    final int connectionCount = readPipeline(dependencies).connections.length;

    await _drawLoopFromReviewToPlan(tester);
    await tapVisible(tester, find.text(addLoopLabel));
    await pumpFrames(tester);
    expect(find.text(loopNeedsOutcomeProblem), findsOneWidget);
    expect(find.text(chooseRoundsProblem), findsOneWidget);
    expect(readPipeline(dependencies).connections.length, connectionCount);

    await enterFieldText(tester, label: outcomeLabel, text: 'changes');
    await _chooseRounds(tester, 'Go back at most 3 rounds');
    await tapVisible(tester, find.text(addLoopLabel));
    await pumpFrames(tester);

    final AgentConnection loop = _findConnectionNamed(
      readPipeline(dependencies),
      from: 'review',
      to: 'plan',
    );
    expect(loop.condition, 'changes');
    expect(loop.roundLimit, 3);
    expect(find.text('changes · ≤ 3'), findsOneWidget);
    expect(find.text(connectionPanelTitle), findsOneWidget);
  });

  testWidgets('a person step without a question cannot be signed', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await tester.tap(find.text(addPersonStepLabel));
    await pumpFrames(tester);
    await tester.tap(find.text('Sign and save'));
    await pumpFrames(tester);

    expect(find.text('Write a question for new-person-step'), findsOneWidget);
  });

  testWidgets('cancelling a drawn loop leaves the workflow unchanged', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    final int connectionCount = readPipeline(dependencies).connections.length;

    await _drawLoopFromReviewToPlan(tester);
    await tapVisible(tester, find.text('Cancel').last);
    await pumpFrames(tester);

    expect(find.text(newLoopTitle), findsNothing);
    expect(readPipeline(dependencies).connections.length, connectionCount);
  });
}
