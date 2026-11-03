import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/form_finders.dart';

void main() {
  testWidgets('a new workflow gets a person step and a limited loop', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openManualWorkflow(tester, dependencies);

    await tester.tap(find.text(addAgentLabel));
    await pumpFrames(tester);
    await tester.tap(find.text(addPersonStepLabel));
    await pumpFrames(tester);
    expect(find.text(personStepPanelTitle), findsOneWidget);

    await dragBetween(
      tester,
      start: tester.getRect(findDiagramNode('new-agent')).bottomCenter,
      end: tester.getCenter(findDiagramNode('new-person-step')),
    );
    await dragBetween(
      tester,
      start: tester.getRect(findDiagramNode('new-person-step')).bottomCenter,
      end: tester.getCenter(findDiagramNode('new-agent')),
    );
    expect(find.text(newLoopTitle), findsOneWidget);

    await enterFieldText(tester, label: outcomeLabel, text: 'changes');
    await tapVisible(tester, findFieldText(roundsLabel, chooseRoundsLabel));
    await pumpFrames(tester);
    await tester.tap(find.text(describeRoundLimitChoice(2)).last);
    await pumpFrames(tester);
    await tapVisible(tester, find.text(addLoopLabel));
    await pumpFrames(tester);

    expect(find.text('changes · ≤ 2'), findsOneWidget);
    expect(find.text(connectionPanelTitle), findsOneWidget);
  });
}
