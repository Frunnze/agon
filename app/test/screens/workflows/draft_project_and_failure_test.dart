import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const String _promptLabel = 'What should this workflow do?';
const String _blankDescriptionProblem = 'Describe what the workflow should do';
const Duration _galleryDraftStep = Duration(milliseconds: 700);

Future<AppNavigation> _openNewWorkflow(
  WidgetTester tester,
  AppDependencies dependencies,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: _workflowsRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(const NewWorkflowRoute());
  await pumpFrames(tester);
  return navigation;
}

void main() {
  testWidgets('test_new_workflow_property_drafts_without_any_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10041);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies galleryBase = buildGalleryDependencies();
      final AppDependencies dependencies = replaceRepositories(
        galleryBase,
        projectRepository: buildProjectRepositoryOver(
          galleryBase,
          const <Project>[],
        ),
      );
      final AppNavigation navigation = await _openNewWorkflow(
        tester,
        dependencies,
      );
      final String words = 'Review ${randomWordPhrase(random)}'.trim();

      await enterFieldText(tester, label: _promptLabel, text: words);
      await tapVisible(tester, find.text('Draft workflow'));
      await tester.pump();

      final AppRoute route = navigation.currentRoute;
      expect(route, isA<WorkflowDraftingRoute>());
      expect((route as WorkflowDraftingRoute).draft.description, words);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(_galleryDraftStep);
    }
  });

  testWidgets('test_workflow_drafting_property_failure_offers_a_way_back', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10042);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String blank = pickOne(random, <String>['', ' ', '\n\t ']);
      final AppNavigation navigation = await _openNewWorkflow(
        tester,
        buildGalleryDependencies(),
      );
      navigation.openRoute(
        WorkflowDraftingRoute(WorkflowDraft(description: blank)),
      );
      await pumpFrames(tester);

      expect(find.text(draftFailedTitle), findsOneWidget);
      expect(find.text(_blankDescriptionProblem), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text(backToDescriptionLabel));
      await pumpFrames(tester);
      expect(navigation.currentRoute, const NewWorkflowRoute());
    }
  });
}
