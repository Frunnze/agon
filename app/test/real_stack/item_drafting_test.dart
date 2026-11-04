import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_catalog.dart';
import 'support/stack_folders.dart';
import 'support/stack_navigation.dart';
import 'support/stack_pairing.dart';
import 'support/stack_server_state.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';
import 'support/workflow_node_steps.dart';
import 'support/workflow_screen_steps.dart';

const String _tasksTitle = 'Tasks';
const String _newTaskTitle = 'New task';
const String _wish = 'Clean the build cache. Wait for release';
const String _changedTitle = 'Clean the docs cache';
const String _draftedDetails = 'Drafted by the fake agent.';
const String _draftingTaskTitle = 'Draft new task';
const String _drafterLine = 'Claude Code is drafting on $runnerDeviceName';
const String _draftingFolderRecord = 'drafting-folder.txt';
const String _projectsTitle = 'Projects';
const String _newProjectTitle = 'New project';
const String _projectQuestion = 'What is this project, and where is its code?';
const String _firstProjectName = 'billing';
const String _firstProjectWish =
    'The billing service. Name it billing. Wait for release.';
const String _chosenFolderName = 'billing-ui';
const String _chooseFolderLabel = 'Choose folder…';
const String _workflowQuestion = 'What should this workflow do?';
const String _workflowName = 'release-plan';
const String _workflowWords = 'Plan each release and list the risks.';

bool _isDraftingProjectKnown(RealStack stack) {
  final List<Project> projects = stack.dependencies.projectRepository
      .listProjects(stack.homeWorkspaceId);
  return projects.isNotEmpty;
}

Future<List<String>> _listNodeTaskTitles(RealStack stack) async {
  final node.TasksView tasks = await stack.channel.execute(
    node.ListTasksCommand(workspaceId: stack.homeWorkspaceId),
  );
  return <String>[
    for (final node.TaskView view in tasks.tasks) view.task.title,
  ];
}

Future<void> _openNewTaskChat(WidgetTester tester, RealStack stack) async {
  await waitUntilTrue(
    tester,
    description: 'the app to know the drafting project',
    isReached: () => _isDraftingProjectKnown(stack),
  );
  await openRailSection(tester, label: _tasksTitle, pageTitle: _tasksTitle);
  await tapAndWait(
    tester,
    find.text(_newTaskTitle).first,
    expected: find.text('What should be done?'),
  );
  await waitUntilGone(tester, findPageTitle(_tasksTitle));
}

void _expectNothingLeftOnServer(RealStack stack, RunnerDevice runner) {
  final List<String> titles = listServerTaskTitles(stack);
  expect(
    titles.where((String title) => title.startsWith('Draft new ')),
    isEmpty,
  );
  expect(runner.readRecord(_draftingFolderRecord), isEmpty);
}

bool _isRunnerOnline(RealStack stack) {
  final List<Runner> runners = stack.dependencies.runnerRepository
      .listRunners();
  return runners.any((Runner runner) => runner.online);
}

List<String> _listProjectNames(RealStack stack) {
  final List<Project> projects = stack.dependencies.projectRepository
      .listProjects(stack.homeWorkspaceId);
  return <String>[for (final Project project in projects) project.name];
}

Future<void> _waitForReview(WidgetTester tester, String title) async {
  await waitUntilShown(tester, find.text(reviewSummary));
  await waitUntilShown(tester, find.text(title));
  expect(find.text(draftingProjectName), findsOneWidget);
  expect(find.text(_draftedDetails), findsOneWidget);
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_draft_item_property_agent_fills_the_task_the_person_approves',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final DraftingStage stage = await prepareDraftingStage(
        tester,
        stack: stack,
      );
      await _openNewTaskChat(tester, stack);

      await tester.enterText(find.byType(TextField).first, _wish);
      await tapAndWait(
        tester,
        find.text('Draft task'),
        expected: find.text(draftingSummary),
      );
      expect(find.text(_wish), findsOneWidget);
      await waitUntilShown(tester, find.text(_drafterLine));
      stage.runner.releaseAgent();
      await _waitForReview(tester, _wish);

      final List<String> titlesAfterDraft = await askNode(
        tester,
        () => _listNodeTaskTitles(stack),
      );
      expect(titlesAfterDraft, isNot(contains(_draftingTaskTitle)));
      expect(titlesAfterDraft, isNot(contains(_wish)));
      _expectNothingLeftOnServer(stack, stage.runner);

      await tester.enterText(find.byType(TextField).last, _changedTitle);
      await tapAndWait(
        tester,
        find.text(sendChangeLabel),
        expected: find.text(draftingSummary),
      );
      await _waitForReview(tester, _changedTitle);

      await tapAndWait(
        tester,
        find.text(approveLabel),
        expected: findPageTitle(describeFirstRunTitle(_changedTitle)),
      );
      await waitUntilGone(tester, findPageTitle(_newTaskTitle));
      final List<String> titlesAfterApproval = await askNode(
        tester,
        () => _listNodeTaskTitles(stack),
      );
      expect(titlesAfterApproval, contains(_changedTitle));
      expect(titlesAfterApproval, isNot(contains(_draftingTaskTitle)));
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_draft_item_property_first_project_takes_the_chosen_folder',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await startPairedRunner(
        tester,
        stack: stack,
      );
      final Directory folder = await askNode(
        tester,
        () => createGitFolder(stack.workingDirectory, _chosenFolderName),
      );
      stack.folderPicker.chosenPath = folder.path;
      await waitUntilTrue(
        tester,
        description: 'the app to see the runner online',
        isReached: () => _isRunnerOnline(stack),
      );
      await openRailSection(
        tester,
        label: _projectsTitle,
        pageTitle: _projectsTitle,
      );
      await tapAndWait(
        tester,
        find.text(_newProjectTitle).first,
        expected: find.text(_projectQuestion),
      );
      expect(find.text(fillInFormLabel), findsNothing);
      await tapWhenShown(tester, find.text(_chooseFolderLabel));
      await waitUntilShown(tester, find.text(_chosenFolderName));

      await tester.enterText(find.byType(TextField).first, _firstProjectWish);
      await tapAndWait(
        tester,
        find.text('Draft project'),
        expected: find.text(draftingSummary),
      );
      await waitUntilShown(tester, find.text(_drafterLine));
      runner.releaseAgent();
      await waitUntilShown(tester, find.text(reviewSummary));
      expect(find.text(_firstProjectName), findsWidgets);
      expect(find.text(_chosenFolderName), findsOneWidget);
      _expectNothingLeftOnServer(stack, runner);
      expect(readServerStateText(stack), isNot(contains(_firstProjectWish)));
      expect(readServerStateText(stack), isNot(contains(folder.path)));

      await tapAndWait(
        tester,
        find.text(approveLabel),
        expected: findPageTitle(_firstProjectName),
      );
      expect(_listProjectNames(stack), <String>[_firstProjectName]);
      final List<node.ProjectView> projects = await listHomeProjects(
        tester,
        stack: stack,
      );
      final List<String> addresses = <String>[
        for (final node.Repository repository
            in projects.single.project.repositories)
          repository.address,
      ];
      expect(addresses, <String>[
        'github.com/acme/$_firstProjectName',
        'local:${stack.appDeviceId.value}:${folder.path}',
      ]);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'test_draft_workflow_property_agent_names_it_and_the_person_signs',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await startPairedRunner(
        tester,
        stack: stack,
      );
      await openWorkflowsSection(tester);
      await tapAndWait(
        tester,
        find.text('New workflow').first,
        expected: find.text(_workflowQuestion),
      );
      expect(find.text('Name'), findsNothing);
      expect(find.text('Available in'), findsNothing);

      await enterFieldText(
        tester,
        label: _workflowQuestion,
        text: describeNamedDraft(_workflowWords, _workflowName),
      );
      await tapAndWait(
        tester,
        find.text('Draft workflow'),
        expected: find.text('Drafting from your description'),
      );
      await waitUntilShown(tester, find.text('Drafted from your description'));
      await waitUntilShown(tester, findPageTitle(_workflowName));
      _expectNothingLeftOnServer(stack, runner);

      await tapWhenShown(tester, find.text('Sign and save'));
      await waitUntilShown(tester, findPageTitle(workflowsTitle));
      await waitUntilShown(tester, find.text(signedLabel));
      final List<node.WorkflowView> views = await askNode(
        tester,
        () => fetchWorkflowViews(stack),
      );
      final node.WorkflowView signed = requireWorkflowViewNamed(
        views,
        _workflowName,
      );
      expect(signed.signatureState, node.SignatureState.signed);
      final node.WorkspaceScope availability = signed.workflow.availability;
      if (availability is! node.OnlyWorkspaces) {
        throw TestFailure('The workflow is available in $availability');
      }
      expect(availability.workspaces, <WorkspaceId>[stack.homeWorkspaceId]);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
