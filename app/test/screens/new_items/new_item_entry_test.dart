import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/projects/new_project_screen.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const String _newProjectLabel = 'New project';
const String _projectQuestion = 'What is this project, and where is its code?';
const String _draftProjectLabel = 'Draft project';
const String _addManuallyLabel = 'Add manually';
const String _createProjectLabel = 'Create project';
const String _projectNameLabel = 'Name';

AppDependencies _buildDependenciesWithoutProjects() {
  return replaceRepositories(
    buildDependenciesWithoutTasks(),
    projectRepository: FakeProjectRepository(projects: const <Project>[]),
  );
}

Future<AppNavigation> _tapNewProjectOnProjectsPage(
  WidgetTester tester,
  AppDependencies dependencies,
) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.projects),
    dependencies: dependencies,
  );
  await tester.tap(findAppButton(_newProjectLabel));
  await pumpFrames(tester);
  return navigation;
}

void _expectManualProjectForm() {
  expect(find.byType(NewProjectScreen), findsOneWidget);
  expect(findFieldInput(_projectNameLabel), findsOneWidget);
  expect(find.text(_createProjectLabel), findsOneWidget);
  expect(find.text(_projectQuestion), findsNothing);
  expect(find.text(_draftProjectLabel), findsNothing);
  expect(find.text(_addManuallyLabel), findsNothing);
}

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

  testWidgets('New project on the Projects page opens the project form', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _tapNewProjectOnProjectsPage(
      tester,
      buildNewItemDependencies(ScriptedItemDraftRepository()),
    );

    expect(navigation.currentRoute, const NewProjectRoute());
    _expectManualProjectForm();
  });

  testWidgets('New project on the empty Projects page opens the form', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _tapNewProjectOnProjectsPage(
      tester,
      _buildDependenciesWithoutProjects(),
    );

    expect(navigation.currentRoute, const NewProjectRoute());
    _expectManualProjectForm();
  });

  testWidgets('a new task without projects opens the project form', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openNewItem(
      tester,
      route: const NewTaskRoute(),
      dependencies: _buildDependenciesWithoutProjects(),
    );

    expect(navigation.currentRoute, const NewTaskRoute());
    _expectManualProjectForm();
  });

  testWidgets(
    'test_new_item_screen_property_every_draft_kind_drafts_none_a_project',
    (WidgetTester tester) async {
      final Random random = seededRandom(8402);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, DraftKind.values);
        await openNewItem(
          tester,
          route: newItemRoutes[kind]!,
          dependencies: buildNewItemDependencies(
            ScriptedItemDraftRepository(),
          ),
        );

        final NewItemScreen screen = tester.widget(find.byType(NewItemScreen));
        expect(screen.kind, kind);
        expect(find.text(describeNewItem(kind).draftLabel), findsOneWidget);
        expect(find.text(_draftProjectLabel), findsNothing);
        expect(find.text(_projectQuestion), findsNothing);
      }
    },
  );

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

      await tapVisible(tester, findAppButton(approveLabel));
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
