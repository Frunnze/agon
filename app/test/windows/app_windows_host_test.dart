import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/app_window_page.dart';
import 'package:agent_orchestration/windows/app_windows_host.dart';
import 'package:agent_orchestration/windows/open_app_window.dart';
import 'package:agent_orchestration/windows/run_window_screen.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';
import '../support/widget_harness.dart';

const Size _twoWindowsSize = Size(desktopWidth * 2, desktopHeight);

final class _HostedWindows {
  _HostedWindows({required this.dependencies})
    : nativeWindows = RecordingNativeWindows() {
    windowList = AppWindowList(nativeWindows: nativeWindows);
    startup = NodeStartup(
      startApp: _startWithSharedDependencies,
      startAppAsNewDevice: _startWithSharedDependencies,
    );
  }

  final AppDependencies dependencies;
  final RecordingNativeWindows nativeWindows;
  final ProblemMessenger problemMessenger = ProblemMessenger();
  late final AppWindowList windowList;
  late final NodeStartup startup;
  int startCount = 0;

  Future<StartedApp> _startWithSharedDependencies() async {
    startCount += 1;
    return StartedApp(
      dependencies: dependencies,
      navigation: AppNavigation(
        initialRoute: const SectionRoute(AppSection.tasks),
      ),
    );
  }

  Widget buildHost() {
    return AppWindowsHost(
      windowList: windowList,
      nativeWindows: nativeWindows,
      startup: startup,
      problemMessenger: problemMessenger,
    );
  }
}

Future<_HostedWindows> _pumpHost(WidgetTester tester) async {
  final _HostedWindows hosted = _HostedWindows(
    dependencies: buildGalleryDependencies(),
  );
  useViewSize(tester, _twoWindowsSize);
  hosted.startup.start();
  hosted.windowList.openStartingWindow();
  await tester.pumpWidget(hosted.buildHost());
  await pumpFrames(tester);
  return hosted;
}

List<AppNavigation> _listNavigations(WidgetTester tester) {
  return <AppNavigation>[
    for (final AppShell shell in tester.widgetList<AppShell>(
      find.byType(AppShell),
    ))
      shell.navigation,
  ];
}

void main() {
  testWidgets('test_app_windows_host_property_windows_share_repositories', (
    WidgetTester tester,
  ) async {
    final _HostedWindows hosted = await _pumpHost(tester);
    hosted.windowList.openSectionWindow();
    await pumpFrames(tester);

    final List<AppShell> shells = tester
        .widgetList<AppShell>(find.byType(AppShell))
        .toList();
    expect(shells, hasLength(2));
    for (final AppShell shell in shells) {
      expect(shell.dependencies, same(hosted.dependencies));
    }
    expect(hosted.startCount, 1);
  });

  testWidgets('test_app_windows_host_property_each_window_navigates_alone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8101);
    final _HostedWindows hosted = await _pumpHost(tester);
    hosted.windowList.openSectionWindow();
    await pumpFrames(tester);
    final List<AppNavigation> navigations = _listNavigations(tester);
    final int movedIndex = random.nextInt(navigations.length);

    navigations[movedIndex].openRoute(
      const TaskRunRoute(GalleryRunIds.release42),
    );
    await pumpFrames(tester);

    expect(find.byType(TaskRunScreen), findsOneWidget);
    for (int index = 0; index < navigations.length; index += 1) {
      final AppRoute route = navigations[index].currentRoute;
      expect(route is TaskRunRoute, index == movedIndex);
    }
  });

  testWidgets('test_app_windows_host_property_windows_stay_in_sync', (
    WidgetTester tester,
  ) async {
    final _HostedWindows hosted = await _pumpHost(tester);
    hosted.windowList.openSectionWindow();
    await pumpFrames(tester);
    for (final AppNavigation navigation in _listNavigations(tester)) {
      navigation.openRoute(const TaskRunRoute(GalleryRunIds.release42));
    }
    await pumpFrames(tester);
    expect(find.text('Cancel run'), findsNWidgets(2));

    unawaited(
      hosted.dependencies.taskRepository.cancelRun(GalleryRunIds.release42),
    );
    await pumpFrames(tester);

    expect(find.text('Cancel run'), findsNothing);
    expect(find.text('Delete'), findsNWidgets(2));
  });

  testWidgets('test_app_windows_host_property_closing_keeps_other_windows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8102);
    final _HostedWindows hosted = await _pumpHost(tester);
    hosted.windowList.openRunWindow(
      runId: GalleryRunIds.release42,
      title: 'release #42',
    );
    await pumpFrames(tester);
    expect(find.byType(RunWindowScreen), findsOneWidget);
    final int closedIndex = random.nextInt(2);

    hosted.nativeWindows.opened[closedIndex].closeByPerson();
    await pumpFrames(tester);

    final OpenAppWindow kept = hosted.windowList.windows.single;
    final bool keptRunWindow = kept.page is RunWindowPage;
    expect(keptRunWindow, closedIndex == 0);
    expect(
      find.byType(RunWindowScreen),
      keptRunWindow ? findsOneWidget : findsNothing,
    );
    expect(find.byType(AppShell), keptRunWindow ? findsNothing : findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_app_windows_host_property_run_page_opens_run_window', (
    WidgetTester tester,
  ) async {
    final _HostedWindows hosted = await _pumpHost(tester);
    _listNavigations(
      tester,
    ).single.openRoute(const TaskRunRoute(GalleryRunIds.release42));
    await pumpFrames(tester);

    await tester.tap(find.text(openInNewWindowLabel));
    await pumpFrames(tester);

    expect(hosted.windowList.windows.last.page, isA<RunWindowPage>());
    expect(find.byType(RunWindowScreen), findsOneWidget);
    expect(find.byType(TaskRunScreen), findsOneWidget);
    expect(
      _listNavigations(tester).single.currentRoute,
      const SectionRoute(AppSection.tasks),
    );
  });
}
