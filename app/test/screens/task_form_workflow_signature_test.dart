import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/random_signature_workflows.dart';

const String _unsignedChoice = 'feature-pipeline, not signed';
const String _unsignedWarning = 'Sign feature-pipeline first';
const String _unsignedLink = 'Open feature-pipeline';
const String _typedTitle = 'Write the poems';
const List<String> _submitLabels = <String>['Start now', 'Save for later'];

final RegExp _signWarningPattern = RegExp(r'^Sign .+ first$');

Finder _findSignWarnings() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is Text && _signWarningPattern.hasMatch(widget.data ?? ''),
  );
}

Future<AppNavigation> _openForm(
  WidgetTester tester, {
  required AppRoute route,
  required AppDependencies dependencies,
}) {
  return pumpApp(
    tester,
    size: phoneSize,
    route: route,
    dependencies: dependencies,
  );
}

Future<void> _chooseDoer(WidgetTester tester, String choice) async {
  await tester.ensureVisible(find.text('Claude Code'));
  await tester.tap(find.text('Claude Code'));
  await pumpFrames(tester);
  await tester.tap(find.text(choice).last);
  await pumpFrames(tester);
}

Future<void> _typeTitle(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, _typedTitle);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFrames(tester);
}

Future<void> _scrollTo(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await pumpFrames(tester);
}

Future<void> _press(WidgetTester tester, String label) async {
  await _scrollTo(tester, label);
  await tester.tap(find.text(label));
  await pumpFrames(tester);
}

NewItemFormRoute _buildWorkflowFormRoute(WorkflowId workflowId) {
  return NewItemFormRoute(DraftKind.task, presetWorkflowId: workflowId);
}

AppRoute _pickFormRoute(
  Random random,
  List<WorkflowInSignatureState> choices,
) {
  final int chosenIndex = random.nextInt(choices.length + 1);
  if (chosenIndex == choices.length) {
    return NewItemFormRoute(DraftKind.task);
  }
  return _buildWorkflowFormRoute(choices[chosenIndex].workflow.id);
}

WorkflowInSignatureState? _findChosenWorkflow(
  AppRoute route,
  List<WorkflowInSignatureState> choices,
) {
  if (route is! NewItemFormRoute) {
    return null;
  }
  final WorkflowId? presetWorkflowId = route.presetWorkflowId;
  if (presetWorkflowId == null) {
    return null;
  }
  for (final WorkflowInSignatureState choice in choices) {
    if (choice.workflow.id == presetWorkflowId) {
      return choice;
    }
  }
  throw StateError('The route names no listed workflow');
}

void main() {
  testWidgets('choosing an unsigned workflow shows the warning and link', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _openForm(
      tester,
      route: NewItemFormRoute(DraftKind.task),
      dependencies: buildGalleryDependencies(),
    );
    expect(find.text(_unsignedWarning), findsNothing);

    await _chooseDoer(tester, _unsignedChoice);

    expect(find.text(_unsignedChoice), findsOneWidget);
    expect(find.text(_unsignedWarning), findsOneWidget);
    await tester.ensureVisible(find.text(_unsignedLink));
    await tester.tap(find.text(_unsignedLink));
    await pumpFrames(tester);
    expect(
      navigation.currentRoute,
      const WorkflowBuilderRoute(
        GalleryWorkflowIds.featurePipeline,
        opening: BuilderOpening.forEditing,
      ),
    );
  });

  testWidgets('a changed workflow links to the change that needs signing', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _openForm(
      tester,
      route: _buildWorkflowFormRoute(GalleryWorkflowIds.trainRanker),
      dependencies: buildGalleryDependencies(),
    );

    expect(find.text('train-ranker, not signed'), findsOneWidget);
    expect(find.text('Sign train-ranker first'), findsOneWidget);
    await tester.ensureVisible(find.text('Open train-ranker'));
    await tester.tap(find.text('Open train-ranker'));
    await pumpFrames(tester);
    expect(
      navigation.currentRoute,
      const WorkflowChangeRoute(GalleryWorkflowIds.trainRanker),
    );
  });

  for (final String label in _submitLabels) {
    testWidgets('$label with an unsigned workflow shows why, saves nothing', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppRoute formRoute = _buildWorkflowFormRoute(
        GalleryWorkflowIds.featurePipeline,
      );
      final AppNavigation navigation = await _openForm(
        tester,
        route: formRoute,
        dependencies: dependencies,
      );
      final int taskCount = dependencies.taskRepository.listTasks().length;
      final int jobCount = dependencies.jobRepository.listJobs().length;
      await _typeTitle(tester);
      await _scrollTo(tester, label);
      expect(find.text(_unsignedWarning).hitTestable(), findsNothing);

      await tester.tap(find.text(label));
      await pumpFrames(tester);

      expect(find.text(_unsignedWarning).hitTestable(), findsOneWidget);
      expect(find.text(_unsignedLink), findsOneWidget);
      expect(dependencies.taskRepository.listTasks().length, taskCount);
      expect(dependencies.jobRepository.listJobs().length, jobCount);
      expect(navigation.currentRoute, formRoute);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a signed workflow shows no warning and starts', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openForm(
      tester,
      route: _buildWorkflowFormRoute(GalleryWorkflowIds.release),
      dependencies: dependencies,
    );
    await _typeTitle(tester);

    expect(_findSignWarnings(), findsNothing);
    expect(find.text('Open release'), findsNothing);
    await _press(tester, 'Start now');
    expect(navigation.currentRoute, isA<TaskRunRoute>());
    expect(dependencies.taskRepository.listTasks().first.title, _typedTitle);
  });

  testWidgets('a refusal from the repository on start is shown', (
    WidgetTester tester,
  ) async {
    const AppRoute formRoute = EditTaskRoute(GalleryTaskIds.shipRelease24);
    final AppNavigation navigation = await _openForm(
      tester,
      route: formRoute,
      dependencies: buildGalleryDependencies(),
    );

    await _press(tester, 'Start now');

    expect(tester.takeException(), isNull);
    expect(find.text('Start now did not work'), findsOneWidget);
    expect(find.text('Task Ship release 2.4 is already running'), findsOne);
    expect(navigation.currentRoute, formRoute);
  });

  testWidgets(
    'test_task_form_property_sign_warning_shows_exactly_when_not_signed',
    (WidgetTester tester) async {
      final Random random = seededRandom(12071);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<WorkflowInSignatureState> choices =
            randomWorkflowsInSignatureStates(random);
        final AppRoute route = _pickFormRoute(random, choices);
        await tester.pumpWidget(const SizedBox.shrink());
        await _openForm(
          tester,
          route: route,
          dependencies: replaceRepositories(
            buildGalleryDependencies(),
            workflowRepository: buildSignatureStateRepository(choices),
          ),
        );

        final WorkflowInSignatureState? chosen = _findChosenWorkflow(
          route,
          choices,
        );
        if (chosen == null || chosen.isSigned) {
          expect(_findSignWarnings(), findsNothing);
        } else {
          expect(_findSignWarnings(), findsOneWidget);
          expect(find.text('Sign ${chosen.workflow.name} first'), findsOne);
        }
      }
    },
  );
}
