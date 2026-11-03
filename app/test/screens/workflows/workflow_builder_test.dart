import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/form_finders.dart';

const String _askHint = 'It asks you before each command and each push.';
const String _autoHint =
    'It runs commands and pushes without asking, and refuses risky '
    'commands. In Docker it can run anything.';
const String _draftedNote =
    'Check each agent before you sign. Change anything by hand: drag between '
    'dots, add agents, or edit the settings.';
const List<String> _builderTexts = <String>[
  'feature-pipeline',
  '5 agents · all workspaces · not signed yet',
  'Cancel',
  'Sign and save',
  'Drafted from your description',
  _draftedNote,
  'Add agent',
  'Ask',
  'plan',
  'backend',
  'ios',
  'review',
  'ship',
  'Claude Code',
  'Codex',
  'Gemini CLI',
  'office-server',
  'mac-studio',
  'any linux runner',
];
const List<String> _settingsTexts = <String>[
  'Agent settings',
  'Done',
  'Fill in with agent',
  'Name',
  'Agent',
  'Task',
  'Runs on',
  'Skills to use',
  'ios-release',
  'Also let the agent pick automatic skills',
  'Commands',
  'Ask for approval',
  _askHint,
  'Auto',
  _autoHint,
  'Remove agent',
];

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('builder matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openPipelineBuilder(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in _builderTexts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Agent settings'), findsNothing);
    });

    testWidgets('selecting an agent shows its settings at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openPipelineBuilder(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      await selectDiagramNode(tester, 'ios');
      for (final String text in _settingsTexts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      final AgentNodeBox node = tester.widget(findDiagramNode('ios'));
      expect(node.look, NodeLook.selected);

      await tapVisible(tester, find.text('Done'));
      await pumpFrames(tester);
      expect(find.text('Agent settings'), findsNothing);
    });
  }

  testWidgets('add agent drops a blank agent and opens it', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );

    await tester.tap(find.text('Add agent'));
    await pumpFrames(tester);

    expect(readPipeline(dependencies).agents.length, 6);
    expect(
      find.text('6 agents · all workspaces · not signed yet'),
      findsOneWidget,
    );
    expect(findDiagramNode('new-agent'), findsOneWidget);
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.text('Connect it by dragging'), findsOneWidget);
    expect(find.text('Choose an agent'), findsOneWidget);
    expect(findFieldText('Runs on', 'Any free runner'), findsOneWidget);
  });

  testWidgets('editing settings saves the workflow', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    await selectDiagramNode(tester, 'ios');
    final WorkflowAgentId iosId = findAgentNamed(
      readPipeline(dependencies),
      'ios',
    ).id;

    await enterFieldText(tester, label: 'Name', text: 'ios-app');
    expect(readPipeline(dependencies).findAgent(iosId).name, 'ios-app');

    await enterFieldText(tester, label: 'Name', text: 'Bad Name');
    expect(find.text('Use lowercase letters, digits and dashes'), findsOne);
    expect(readPipeline(dependencies).findAgent(iosId).name, 'ios-app');

    await enterFieldText(tester, label: 'Name', text: 'backend');
    expect(find.text('Another agent has this name'), findsOneWidget);

    await enterFieldText(tester, label: 'Task', text: 'Build the iOS app.');
    await tapVisible(tester, find.text('Auto'));
    await tester.pump();
    await tapVisible(
      tester,
      find.text('Also let the agent pick automatic skills'),
    );
    await tester.pump();

    final WorkflowAgent edited = readPipeline(dependencies).findAgent(iosId);
    expect(edited.task, 'Build the iOS app.');
    expect(edited.approvalPolicy, ApprovalPolicy.neverAsk);
    expect(edited.usesAutomaticSkills, isFalse);

    await tapVisible(tester, findFieldText('Agent', 'Claude Code'));
    await pumpFrames(tester);
    await tester.tap(find.text('Codex').last);
    await pumpFrames(tester);
    expect(readPipeline(dependencies).findAgent(iosId).kind, AgentKind.codex);
  });

  testWidgets('fill in with agent completes a blank agent', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await openPipelineBuilder(
      tester,
      size: tallDesktopSize,
      dependencies: dependencies,
    );
    await tester.tap(find.text('Add agent'));
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Fill in with agent'));
    await pumpFrames(tester);

    final WorkflowAgent filled = findAgentNamed(
      readPipeline(dependencies),
      'new-agent',
    );
    expect(filled.kind, AgentKind.claudeCode);
    expect(filled.task, 'Do the new-agent step of feature-pipeline.');
    expect(
      findFieldText('Task', 'Do the new-agent step of feature-pipeline.'),
      findsOneWidget,
    );
  });
}
