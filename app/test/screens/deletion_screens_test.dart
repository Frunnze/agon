import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';

const List<Size> _layoutSizes = <Size>[phoneSize, desktopSize];
const String _deleteLabel = 'Delete';
const String _deleteWorkspaceLabel = 'Delete workspace';
const SectionRoute _settingsRoute = SectionRoute(AppSection.settings);

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tapVisible(tester, find.widgetWithText(AppButton, label).last);
  await pumpFrames(tester);
}

AppButton _readButton(WidgetTester tester, String label) {
  return tester.widget<AppButton>(find.widgetWithText(AppButton, label));
}

List<WorkflowId> _listWorkflowIds(AppDependencies dependencies) {
  return <WorkflowId>[
    for (final Workflow workflow
        in dependencies.workflowRepository.listWorkflows())
      workflow.id,
  ];
}

Future<AppDependencies> _buildIdleGallery() async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final List<Task> work = <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
  for (final Task task in work) {
    for (final Run run in dependencies.taskRepository.listRuns(task.id)) {
      if (isRunActive(run)) {
        await dependencies.taskRepository.cancelRun(run.id);
      }
    }
  }
  return dependencies;
}

void main() {
  for (final Size size in _layoutSizes) {
    testWidgets('Delete project asks, leaves and deletes at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = await _buildIdleGallery();
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: const ProjectRoute(GalleryProjectIds.acmeApp),
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      expect(find.text('Delete acme-app?'), findsOneWidget);
      expect(find.text("This can't be undone."), findsOneWidget);
      await _tapButton(tester, 'Delete project');

      expect(navigation.currentRoute, const SectionRoute(AppSection.projects));
      expect(
        () => dependencies.projectRepository.findProject(
          GalleryProjectIds.acmeApp,
        ),
        throwsA(isA<RecordNotFound>()),
      );
    });

    testWidgets('Keep project keeps the project at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      const ProjectRoute route = ProjectRoute(GalleryProjectIds.acmeApp);
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: route,
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      await _tapButton(tester, 'Keep project');

      expect(find.text('Delete acme-app?'), findsNothing);
      expect(navigation.currentRoute, route);
      expect(
        dependencies.projectRepository
            .findProject(GalleryProjectIds.acmeApp)
            .name,
        'acme-app',
      );
    });

    testWidgets('Delete workflow leaves and deletes at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: const WorkflowDetailRoute(GalleryWorkflowIds.featurePipeline),
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      expect(find.text('Delete feature-pipeline?'), findsOneWidget);
      await _tapButton(tester, 'Delete workflow');

      expect(
        navigation.currentRoute,
        const SectionRoute(AppSection.workflows),
      );
      expect(
        _listWorkflowIds(dependencies),
        isNot(contains(GalleryWorkflowIds.featurePipeline)),
      );
    });

    testWidgets('Delete workspace switches to another at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = await _buildIdleGallery();
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: _settingsRoute,
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteWorkspaceLabel);
      expect(find.text('Delete acme?'), findsOneWidget);
      expect(find.textContaining('You switch to personal.'), findsOneWidget);
      await _tapButton(tester, _deleteWorkspaceLabel);

      expect(navigation.currentRoute, const SectionRoute(AppSection.projects));
      final String currentName = dependencies.workspaceRepository
          .currentWorkspace()
          .name;
      expect(currentName, 'personal');
      expect(dependencies.workspaceRepository.listWorkspaces().length, 1);
    });

    testWidgets('the last workspace offers no delete at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      await dependencies.workspaceRepository.deleteWorkspace(
        GalleryWorkspaceIds.personal,
      );
      await pumpApp(
        tester,
        size: size,
        route: _settingsRoute,
        dependencies: dependencies,
      );

      expect(_readButton(tester, _deleteWorkspaceLabel).onPressed, isNull);
    });

    testWidgets('only the General tab offers Delete at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _settingsRoute,
        dependencies: buildGalleryDependencies(),
      );

      await tapVisible(tester, find.text('Audit log'));
      await pumpFrames(tester);

      expect(
        find.widgetWithText(AppButton, _deleteWorkspaceLabel),
        findsNothing,
      );
    });
  }
}
