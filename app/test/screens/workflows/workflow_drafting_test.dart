import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/stop_recording_workflow_repository.dart';

const String _promptHint =
    'An agent fills in everything else: the name, where it is available, '
    "the diagram and every agent's settings. You check it, then sign it.";
const String _promptLabel = 'What should this workflow do?';
const String _draftLabel = 'Draft workflow';
const String _newWorkflowTitle = 'New workflow';
const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const Duration _draftStep = Duration(milliseconds: 700);
const String _stopRefusal = 'could not reach the app server: down';
const String _description =
    'Plan a feature, build the backend and the iOS app at the same time, '
    'review both, then ship to the release branch.';
const int _wordRounds = 12;

Future<AppNavigation> _openNewWorkflow(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: _workflowsRoute,
    dependencies: dependencies,
  );
  await tester.tap(find.text(_newWorkflowTitle));
  await pumpFrames(tester);
  return navigation;
}

const WorkflowDraftingRoute _draftingRoute = WorkflowDraftingRoute(
  WorkflowDraft(description: _description),
);

int _countWorkflows(AppDependencies dependencies) {
  return dependencies.workflowRepository.listWorkflows().length;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('new workflow matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await _openNewWorkflow(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      expect(find.byType(NewWorkflowScreen), findsOneWidget);
      for (final String text in <String>[
        _newWorkflowTitle,
        'Workflows',
        'Cancel',
        _promptLabel,
        _promptHint,
        _draftLabel,
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      for (final String text in <String>['Name', 'Available in']) {
        expect(find.text(text), findsNothing, reason: text);
      }
    });

    testWidgets('drafting adds agents one by one at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await _openNewWorkflow(
        tester,
        size: size,
        dependencies: dependencies,
      );
      final int workflowsBefore = _countWorkflows(dependencies);
      await enterFieldText(tester, label: _promptLabel, text: _description);
      await tapVisible(tester, find.text(_draftLabel));
      await tester.pump();
      await tester.pump(_draftStep * 4);
      await tester.pump();

      for (final String text in <String>[
        _newWorkflowTitle,
        'Drafting from your description',
        'Stop drafting',
        'Claude Code is drafting on office-server',
        'Draft progress',
        'Read your description',
        'Added plan, Claude Code on office-server',
        'Added backend, Codex on office-server',
        'Added ios, Claude Code on mac-studio with ios-release',
        'Adding review and ship',
        'Adding…',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(_countWorkflows(dependencies), workflowsBefore);

      await tester.pump(_draftStep * 3);
      await pumpFrames(tester);

      expect(_countWorkflows(dependencies), workflowsBefore + 1);
      final Workflow drafted = dependencies.workflowRepository
          .listWorkflows()
          .last;
      expect(find.byType(WorkflowBuilderScreen), findsOneWidget);
      expect(find.text(drafted.name), findsWidgets);
      expect(find.text('Drafted from your description'), findsOneWidget);
      expect(navigation.routes.first, _workflowsRoute);
      expect(navigation.routes.length, 2);
    });
  }

  testWidgets('test_new_workflow_screen_property_drafts_from_words_alone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8701);
    for (int i = 0; i < _wordRounds; i += 1) {
      final bool isBlank = random.nextBool();
      final String words = isBlank ? '  \n ' : ' ${randomText(random)}x ';
      final AppNavigation navigation = await _openNewWorkflow(
        tester,
        size: desktopSize,
        dependencies: buildGalleryDependencies(),
      );

      await enterFieldText(tester, label: _promptLabel, text: words);
      await tapVisible(tester, find.text(_draftLabel));
      await tester.pump();

      final AppRoute route = navigation.currentRoute;
      if (isBlank) {
        expect(route, const NewWorkflowRoute());
        expect(
          find.text('Describe what the workflow should do'),
          findsOneWidget,
        );
      } else {
        expect(route, isA<WorkflowDraftingRoute>());
        final WorkflowDraftingRoute draftingRoute =
            route as WorkflowDraftingRoute;
        expect(draftingRoute.draft.description, words.trim());
      }
      await tester.pump(_draftStep * 8);
    }
  });

  testWidgets('stop drafting returns to the form and saves nothing', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openNewWorkflow(
      tester,
      size: desktopSize,
      dependencies: dependencies,
    );
    final int workflowsBefore = _countWorkflows(dependencies);
    await enterFieldText(tester, label: _promptLabel, text: _description);
    await tapVisible(tester, find.text(_draftLabel));
    await tester.pump();
    await tester.pump(_draftStep * 2);

    await tester.tap(find.text('Stop drafting'));
    await pumpFrames(tester);
    await tester.pump(_draftStep * 8);

    expect(navigation.currentRoute, const NewWorkflowRoute());
    expect(find.text(_description), findsOneWidget);
    expect(_countWorkflows(dependencies), workflowsBefore);
  });

  testWidgets('a refused stop keeps drafting and shows why', (
    WidgetTester tester,
  ) async {
    final StopRecordingWorkflowRepository repository =
        StopRecordingWorkflowRepository(refusal: _stopRefusal);
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: _workflowsRoute,
      dependencies: replaceRepositories(
        buildGalleryDependencies(),
        workflowRepository: repository,
      ),
    );
    navigation.openRoute(_draftingRoute);
    await pumpFrames(tester);

    await tester.tap(find.text('Stop drafting'));
    await pumpFrames(tester);

    expect(repository.stopAttempts, 1);
    expect(navigation.currentRoute, isA<WorkflowDraftingRoute>());
    expect(find.text(stopFailedTitle), findsOneWidget);
    expect(find.text(_stopRefusal), findsOneWidget);
    expect(find.text('Stop drafting'), findsOneWidget);
  });

  testWidgets(
    'test_leave_drafting_property_back_link_behaves_like_stop_drafting',
    (WidgetTester tester) async {
      for (final String? refusal in <String?>[null, _stopRefusal]) {
        final StopRecordingWorkflowRepository repository =
            StopRecordingWorkflowRepository(refusal: refusal);
        final AppNavigation navigation = await pumpApp(
          tester,
          size: phoneSize,
          route: _workflowsRoute,
          dependencies: replaceRepositories(
            buildGalleryDependencies(),
            workflowRepository: repository,
          ),
        );
        navigation.openRoute(_draftingRoute);
        await pumpFrames(tester);

        await tester.tap(find.byType(BackLinkButton));
        await pumpFrames(tester);

        expect(repository.stopAttempts, 1);
        if (refusal == null) {
          expect(navigation.currentRoute, _workflowsRoute);
          expect(find.text(stopFailedTitle), findsNothing);
        } else {
          expect(navigation.currentRoute, _draftingRoute);
          expect(find.text(stopFailedTitle), findsOneWidget);
          expect(find.text(refusal), findsOneWidget);
        }
      }
    },
  );
}
