import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';

const List<Size> _layoutSizes = <Size>[phoneSize, desktopSize];
const String _deleteLabel = 'Delete';

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tapVisible(tester, find.widgetWithText(AppButton, label).last);
  await pumpFrames(tester);
}

List<TaskId> _listTaskAndJobIds(AppDependencies dependencies) {
  return <TaskId>[
    for (final Task task in dependencies.taskRepository.listTasks()) task.id,
    for (final Task job in dependencies.jobRepository.listJobs()) job.id,
  ];
}

void main() {
  for (final Size size in _layoutSizes) {
    testWidgets('a stopped run offers Delete task at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: const TaskRunRoute(GalleryRunIds.release41),
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      expect(find.text('Delete "Ship release 2.3"?'), findsOneWidget);
      await _tapButton(tester, 'Delete task');

      expect(navigation.currentRoute, const SectionRoute(AppSection.tasks));
      expect(
        _listTaskAndJobIds(dependencies),
        isNot(contains(GalleryTaskIds.shipRelease23)),
      );
    });

    testWidgets('a running run offers no Delete at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const TaskRunRoute(GalleryRunIds.release42),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.widgetWithText(AppButton, _deleteLabel), findsNothing);
      expect(find.widgetWithText(AppButton, 'Cancel run'), findsOneWidget);
    });

    testWidgets('Edit task offers Delete task at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: const EditTaskRoute(GalleryTaskIds.cleanUpBranches),
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      await _tapButton(tester, 'Delete task');

      expect(navigation.currentRoute, const SectionRoute(AppSection.tasks));
      expect(
        _listTaskAndJobIds(dependencies),
        isNot(contains(GalleryTaskIds.cleanUpBranches)),
      );
    });

    testWidgets('New task offers no Delete at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const NewTaskRoute(),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.widgetWithText(AppButton, _deleteLabel), findsNothing);
    });

    testWidgets('Edit job offers Delete job at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: const EditJobRoute(GalleryTaskIds.updateDependencies),
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      expect(find.text('Delete "Update dependencies"?'), findsOneWidget);
      await _tapButton(tester, 'Delete job');

      expect(navigation.currentRoute, const SectionRoute(AppSection.jobs));
      expect(
        _listTaskAndJobIds(dependencies),
        isNot(contains(GalleryTaskIds.updateDependencies)),
      );
    });

    testWidgets('Keep job keeps the job at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      const EditJobRoute route = EditJobRoute(
        GalleryTaskIds.updateDependencies,
      );
      final AppNavigation navigation = await pumpApp(
        tester,
        size: size,
        route: route,
        dependencies: dependencies,
      );

      await _tapButton(tester, _deleteLabel);
      await _tapButton(tester, 'Keep job');

      expect(navigation.currentRoute, route);
      expect(
        _listTaskAndJobIds(dependencies),
        contains(GalleryTaskIds.updateDependencies),
      );
    });
  }
}
