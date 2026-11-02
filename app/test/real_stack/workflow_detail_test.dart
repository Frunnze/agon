import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/widgets/app_button.dart';

import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/workflow_node_steps.dart';
import 'support/workflow_screen_steps.dart';

const String _workflowName = 'signed-plan';
const String _editDiagramLabel = 'Edit diagram';
const String _useInTaskLabel = 'Use in a task';

void main() {
  testWidgets(
    'test_workflow_detail_property_shows_the_signed_node_version',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final DraftingStage stage = await prepareDraftingStage(
        tester,
        stack: stack,
      );
      final node.WorkflowView drafted = await draftWorkflowOnNode(
        tester,
        stack: stack,
        stage: stage,
        workflowName: _workflowName,
      );
      await signWorkflowOnNode(
        tester,
        stack: stack,
        workflowId: drafted.workflow.id,
      );

      await openWorkflowsSection(tester);
      await openWorkflowRow(
        tester,
        workflowName: _workflowName,
        signatureLabel: signedLabel,
        expected: find.text(_editDiagramLabel),
      );
      await waitUntilGone(tester, findPageTitle(workflowsTitle));

      final node.WorkflowView listed = await askNode(
        tester,
        () => fetchWorkflowView(stack, drafted.workflow.id),
      );
      final AppButton useInTask = tester.widget<AppButton>(
        find.widgetWithText(AppButton, _useInTaskLabel),
      );
      expect(listed.signatureState, node.SignatureState.signed);
      expect(listed.workflow.signature?.signedBy, stack.appDeviceId);
      expect(findPageTitle(_workflowName), findsOneWidget);
      expect(find.textContaining('signed on $appDeviceName'), findsOneWidget);
      expect(useInTask.onPressed, isNotNull);
      expect(listed.agentNames, <String>[draftedAgentName]);
      for (final String agentName in listed.agentNames) {
        expect(find.text(agentName), findsOneWidget);
      }
      expect(readShownCodeLines(tester), splitDocument(listed.document));
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
