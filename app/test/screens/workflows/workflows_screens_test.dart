import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const List<String> _listTexts = <String>[
  'Workflows',
  'Available in all your workspaces unless you limit it.',
  'New workflow',
  'release',
  'plan, build-ios, train',
  'nightly-tests',
  'test, report',
  'feature-pipeline',
  'plan, backend, ios, review, ship',
  'train-ranker',
  'prepare, train',
  'docs-sync',
  'publish',
  'acme',
  'All workspaces',
  '4 min ago',
  'Never',
  'Signed',
  'Not signed yet',
  'Changed, not signed',
  'Runners only run versions signed with one of your keys.',
];
const List<String> _detailTexts = <String>[
  'release',
  'In acme · signed on air-laptop 3 days ago',
  'Edit diagram',
  'Use in a task',
  'Steps',
  'plan',
  'build-ios',
  'Online',
  '1 match online',
  'Source',
  'name: release',
  '  - name: build-ios',
  '    requires: [gpu]',
];
const List<String> _changeTexts = <String>[
  'train-ranker',
  'Changed 1 h ago on air-laptop',
  'Discard change',
  'Sign change',
  "This version won't run until you sign it",
  'Until then, runners keep using the version signed 2 days ago.',
  'What changes',
  'Time limit for train',
  '2 h, now 6 h',
  'Network for train',
  'Can now reach huggingface.co',
  'Changes',
  '  name: train-ranker',
  '-     timeout: 2h',
  '+     timeout: 6h',
  '+     egress: [huggingface.co]',
];

void _expectTexts(List<String> texts) {
  for (final String text in texts) {
    expect(find.text(text), findsWidgets, reason: text);
  }
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('workflows match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _workflowsRoute,
        dependencies: buildGalleryDependencies(),
      );

      _expectTexts(_listTexts);
      expect(find.text('Signed'), findsNWidgets(3));
    });

    testWidgets('workflow detail matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const WorkflowDetailRoute(GalleryWorkflowIds.release),
        dependencies: buildGalleryDependencies(),
      );

      _expectTexts(_detailTexts);
      expect(find.text('Online'), findsNWidgets(2));
    });

    testWidgets('workflow change matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const WorkflowChangeRoute(GalleryWorkflowIds.trainRanker),
        dependencies: buildGalleryDependencies(),
      );

      _expectTexts(_changeTexts);
    });
  }

  testWidgets('rows open the page that fits their signature', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _workflowsRoute,
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('release'));
    await pumpFrames(tester);
    expect(find.byType(WorkflowDetailScreen), findsOneWidget);

    navigation.openSection(_workflowsRoute);
    await pumpFrames(tester);
    await tester.tap(find.text('feature-pipeline'));
    await pumpFrames(tester);
    expect(find.byType(WorkflowBuilderScreen), findsOneWidget);

    navigation.openSection(_workflowsRoute);
    await pumpFrames(tester);
    await tester.tap(find.text('train-ranker'));
    await pumpFrames(tester);
    expect(find.byType(WorkflowChangeScreen), findsOneWidget);
  });

  testWidgets('use in a task opens the chat, its form keeps the workflow', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _workflowsRoute,
      dependencies: buildGalleryDependencies(),
    );
    navigation.openRoute(
      const WorkflowDetailRoute(GalleryWorkflowIds.release),
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Use in a task'));
    await pumpFrames(tester);

    final NewItemScreen chat = tester.widget(find.byType(NewItemScreen));
    expect(chat.kind, DraftKind.task);
    expect(chat.startedFrom, contains('release'));
    navigation.replaceRoute(
      NewItemFormRoute(
        DraftKind.task,
        presetWorkflowId: GalleryWorkflowIds.release,
      ),
    );
    await pumpFrames(tester);

    final TaskFormScreen form = tester.widget(find.byType(TaskFormScreen));
    expect(form.initialDoer, const WorkflowDoer(GalleryWorkflowIds.release));
    expect(findFieldText('Who does it', 'release'), findsOneWidget);
  });

  testWidgets('signing a change takes one tap and clears it', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const WorkflowChangeRoute(GalleryWorkflowIds.trainRanker),
      dependencies: dependencies,
    );
    await tester.tap(find.text('Sign change'));
    await pumpFrames(tester);

    expect(
      dependencies.workflowRepository.findPendingChange(
        GalleryWorkflowIds.trainRanker,
      ),
      isNull,
    );
    expect(navigation.currentRoute, _workflowsRoute);
    expect(find.text('Changed, not signed'), findsNothing);
  });

  testWidgets('discarding a change keeps the signed version', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: phoneSize,
      route: const WorkflowChangeRoute(GalleryWorkflowIds.trainRanker),
      dependencies: dependencies,
    );

    await tapVisible(tester, find.text('Discard change'));
    await pumpFrames(tester);

    expect(
      dependencies.workflowRepository.findPendingChange(
        GalleryWorkflowIds.trainRanker,
      ),
      isNull,
    );
    expect(find.text('Changed, not signed'), findsNothing);
  });

  testWidgets('test_workflow_screens_fuzz_property_render_at_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9101);
    final List<AppRoute> routes = <AppRoute>[
      _workflowsRoute,
      const WorkflowDetailRoute(GalleryWorkflowIds.release),
      const WorkflowChangeRoute(GalleryWorkflowIds.trainRanker),
      const NewWorkflowRoute(),
      const WorkflowBuilderRoute(
        GalleryWorkflowIds.featurePipeline,
        opening: BuilderOpening.afterDrafting,
      ),
    ];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final AppRoute route = pickOne(random, routes);
      await pumpApp(
        tester,
        size: Size(width, desktopHeight),
        route: route,
        dependencies: buildGalleryDependencies(),
      );

      expect(tester.takeException(), isNull, reason: '$route at $width');
    }
  });
}
