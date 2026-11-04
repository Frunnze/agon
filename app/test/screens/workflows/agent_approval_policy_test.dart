import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

const String _blankAgentName = 'new-agent';
const Map<ApprovalPolicy?, String> _choiceTitles = <ApprovalPolicy?, String>{
  null: 'Same as the project',
  ApprovalPolicy.neverAsk: 'Auto',
  ApprovalPolicy.askBeforeRiskyActions: 'Ask me',
};

Future<void> _addBlankAgent(WidgetTester tester) async {
  await tester.tap(find.text('Add agent'));
  await pumpFrames(tester);
}

void main() {
  testWidgets('a new agent follows the project and offers three choices', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await _addBlankAgent(tester);

    final WorkflowAgent added = findAgentNamed(
      readPipeline(dependencies),
      _blankAgentName,
    );
    expect(added.approvalPolicy, isNull);
    for (final String title in _choiceTitles.values) {
      expect(
        findFieldText('Commands and pushes', title),
        findsOneWidget,
        reason: title,
      );
    }
  });

  testWidgets('test_agent_settings_panel_property_saves_the_tapped_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9831);
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    await _addBlankAgent(tester);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalPolicy? chosen = randomInheritableApprovalPolicy(random);

      await tapVisible(tester, find.text(_choiceTitles[chosen]!));
      await pumpFrames(tester);

      final WorkflowAgent edited = findAgentNamed(
        readPipeline(dependencies),
        _blankAgentName,
      );
      expect(edited.approvalPolicy, chosen);
    }
  });
}
