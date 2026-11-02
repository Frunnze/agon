import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';

const SectionRoute _tasksRoute = SectionRoute(AppSection.tasks);

void expectGalleryTaskRows() {
  expect(find.text('Tasks'), findsWidgets);
  expect(find.text('1 running · 1 failed · 1 to do'), findsOneWidget);
  expect(find.text('Ship release 2.4'), findsOneWidget);
  expect(
    find.text('acme-app · workflow release · step 2 of 3'),
    findsNWidgets(2),
  );
  expect(find.text('Clean up old feature branches'), findsOneWidget);
  expect(find.text('acme-app · Claude Code'), findsOneWidget);
  expect(find.text('Write the v2 API docs'), findsOneWidget);
  expect(find.text('docs · Gemini CLI'), findsOneWidget);
  expect(find.text('mac-studio'), findsNWidgets(2));
  expect(find.text('office-server'), findsOneWidget);
  expect(find.text('Any runner'), findsOneWidget);
  expect(find.text('4 min ago'), findsOneWidget);
  expect(find.text('Not yet'), findsOneWidget);
  expect(find.text('Yesterday 18:20'), findsOneWidget);
  expect(find.text('Yesterday 11:40'), findsOneWidget);
  expect(find.text('Running'), findsOneWidget);
  expect(find.text('To do'), findsOneWidget);
  expect(find.text('Failed'), findsOneWidget);
  expect(find.text('Done'), findsOneWidget);
  expect(find.text('New task'), findsOneWidget);
}

void main() {
  testWidgets('tasks page matches the gallery on a phone', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: phoneSize,
      route: _tasksRoute,
      dependencies: buildGalleryDependencies(),
    );

    expectGalleryTaskRows();
    expect(find.text('Runs on'), findsNothing);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('air-laptop · Client'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tasks page matches the gallery on a desktop', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: _tasksRoute,
      dependencies: buildGalleryDependencies(),
    );

    expectGalleryTaskRows();
    expect(find.text('Runs on'), findsOneWidget);
    expect(find.text('Started'), findsOneWidget);
    expect(find.text('acme'), findsOneWidget);
    expect(find.text('air-laptop · Client'), findsOneWidget);
    expect(find.text('Workflows'), findsOneWidget);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('empty tasks page invites a first task', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[phoneSize, desktopSize]) {
      await pumpApp(
        tester,
        size: size,
        route: _tasksRoute,
        dependencies: buildDependenciesWithoutTasks(),
      );

      expect(find.text('No tasks yet'), findsOneWidget);
      expect(
        find.text(
          'Write what you want done, then pick one agent or a whole '
          'workflow to do it.',
        ),
        findsOneWidget,
      );
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    }
  });

  testWidgets('tapping rows opens the run or the form', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _tasksRoute,
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('Ship release 2.3'));
    await pumpFrames(tester);
    expect(find.byType(TaskRunScreen), findsOneWidget);
    expect(navigation.currentRoute, isA<TaskRunRoute>());

    navigation.openSection(_tasksRoute);
    await pumpFrames(tester);
    await tester.tap(find.text('Clean up old feature branches'));
    await pumpFrames(tester);
    expect(find.byType(TaskFormScreen), findsOneWidget);
    expect(find.text('Edit task'), findsOneWidget);
  });
}
