import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const int firstProjectRounds = 3;

void main() {
  testWidgets('no online runner says so and offers the form', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = replaceRepositories(
      buildNewItemDependencies(ScriptedItemDraftRepository()),
      runnerRepository: FakeRunnerRepository(
        runners: const <Runner>[],
        thisDeviceOffers: null,
        thisRunnerProblem: null,
      ),
    );
    final AppNavigation navigation = await openNewItem(
      tester,
      route: const NewTaskRoute(),
      dependencies: dependencies,
    );

    expect(find.text(noRunnerTitle), findsOneWidget);
    expect(isAppButtonOn(tester, 'Draft task'), isTrue);
    await tester.tap(find.text(fillInFormLabel));
    await pumpFrames(tester);

    expect(navigation.currentRoute, NewItemFormRoute(DraftKind.task));
    expect(find.byType(TaskFormScreen), findsOneWidget);
  });

  testWidgets('test_new_item_screen_property_first_project_is_drafted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8402);
    const List<AppRoute> firstWorkRoutes = <AppRoute>[
      NewTaskRoute(),
      NewProjectRoute(),
    ];
    for (int i = 0; i < firstProjectRounds; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final AppDependencies dependencies = replaceRepositories(
        buildNewItemDependencies(drafts),
        projectRepository: FakeProjectRepository(projects: const <Project>[]),
      );
      final AppNavigation navigation = await pumpApp(
        tester,
        size: desktopSize,
        route: const SectionRoute(AppSection.projects),
        dependencies: dependencies,
      );
      navigation.openRoute(pickOne(random, firstWorkRoutes));
      await pumpFrames(tester);

      expect(find.text('New project'), findsOneWidget);
      expect(find.text(fillInFormLabel), findsNothing);
      expect(isAppButtonOn(tester, 'Draft project'), isTrue);
      final String wish = 'billing ${randomText(random)}';
      await tester.enterText(find.byType(TextField).first, wish);
      await tester.tap(find.text('Draft project'));
      await pumpFrames(tester);
      expect(drafts.latestRequest.kind, DraftKind.project);
      expect(drafts.latestRequest.wish, wish.trim());
      await finishNewItemDraft(
        tester,
        drafts,
        findGalleryItemDraft(DraftKind.project),
      );
      await tester.tap(find.text(approveLabel));
      await pumpFrames(tester);

      expect(navigation.currentRoute, isA<ProjectRoute>());
      final WorkspaceId workspaceId = dependencies.workspaceRepository
          .currentWorkspace()
          .id;
      expect(
        dependencies.projectRepository.listProjects(workspaceId),
        hasLength(1),
      );
    }
  });

  testWidgets('test_new_item_screen_property_approval_creates_each_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8401);
    for (int i = 0; i < DraftKind.values.length * 2; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final AppDependencies dependencies = buildNewItemDependencies(drafts);
      final int skillsBefore = dependencies.skillRepository
          .listSkills()
          .length;
      final int rulesBefore = dependencies.ruleRepository.listRules().length;
      final int jobsBefore = dependencies.jobRepository.listJobs().length;
      final AppNavigation navigation = await openNewItem(
        tester,
        route: newItemRoutes[kind]!,
        dependencies: dependencies,
      );
      await startNewItemDraft(tester, describeNewItem(kind).draftLabel);
      await finishNewItemDraft(tester, drafts, findGalleryItemDraft(kind));

      await tester.tap(find.text(approveLabel));
      await pumpFrames(tester);

      final AppRoute route = navigation.currentRoute;
      switch (kind) {
        case DraftKind.task:
          expect(route, isA<TaskRunRoute>());
        case DraftKind.job:
          expect(
            dependencies.jobRepository.listJobs(),
            hasLength(jobsBefore + 1),
          );
        case DraftKind.project:
          expect(route, isA<ProjectRoute>());
        case DraftKind.skill:
          expect(route, isA<SkillDetailRoute>());
          expect(
            dependencies.skillRepository.listSkills(),
            hasLength(skillsBefore + 1),
          );
        case DraftKind.rule:
          expect(
            dependencies.ruleRepository.listRules(),
            hasLength(rulesBefore + 1),
          );
      }
      expect(route, isNot(newItemRoutes[kind]));
    }
  });
}
