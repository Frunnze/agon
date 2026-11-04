import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/product_name.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/app_window_page.dart';
import 'package:agent_orchestration/windows/open_app_window.dart';

import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';

const int _largestWindowCount = 6;

AppWindowList _buildWindowList(RecordingNativeWindows nativeWindows) {
  return AppWindowList(nativeWindows: nativeWindows);
}

void _openRandomWindow(AppWindowList windowList, Random random) {
  switch (random.nextInt(3)) {
    case 0:
      windowList.openStartingWindow();
    case 1:
      windowList.openSectionWindow();
    default:
      windowList.openRunWindow(
        runId: RunId('run-${random.nextInt(99)}'),
        title: randomText(random),
      );
  }
}

List<AppNavigation> _listSectionNavigations(AppWindowList windowList) {
  return <AppNavigation>[
    for (final OpenAppWindow window in windowList.windows)
      if (window.page case SectionWindowPage(:final AppNavigation navigation))
        navigation,
  ];
}

void main() {
  test('test_open_section_window_property_each_window_has_own_navigation', () {
    final Random random = seededRandom(4101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppWindowList windowList = _buildWindowList(
        RecordingNativeWindows(),
      );
      final int windowCount = 1 + random.nextInt(_largestWindowCount);
      for (int opened = 0; opened < windowCount; opened += 1) {
        windowList.openSectionWindow();
      }

      final List<AppNavigation> navigations = _listSectionNavigations(
        windowList,
      );
      expect(navigations.length, windowCount);
      expect(Set<AppNavigation>.identity()..addAll(navigations), hasLength(
        windowCount,
      ));
      final AppNavigation moved = navigations[random.nextInt(windowCount)];
      moved.openRoute(const TaskRunRoute(RunId('run-moved')));
      for (final AppNavigation navigation in navigations) {
        final AppRoute expected = identical(navigation, moved)
            ? const TaskRunRoute(RunId('run-moved'))
            : const SectionRoute(AppSection.tasks);
        expect(navigation.currentRoute, expected);
      }
    }
  });

  test('test_open_run_window_property_opens_compact_titled_window', () {
    final Random random = seededRandom(4102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
      final AppWindowList windowList = _buildWindowList(nativeWindows);
      final String title = randomText(random);
      final RunId runId = RunId('run-${random.nextInt(999)}');

      windowList.openRunWindow(runId: runId, title: title);

      final RecordingNativeWindow runWindow = nativeWindows.opened.single;
      expect(runWindow.shape.title, title);
      expect(runWindow.shape.size.width, lessThan(mainWindowShape.size.width));
      expect(
        runWindow.shape.size.height,
        lessThanOrEqualTo(mainWindowShape.size.height),
      );
      final AppWindowPage page = windowList.windows.single.page;
      expect(page, isA<RunWindowPage>());
      final AppNavigation navigation = (page as RunWindowPage).navigation;
      expect(navigation.routes, <AppRoute>[TaskRunRoute(runId)]);
      expect(navigation.canOpen(const SectionRoute(AppSection.tasks)), false);
    }
  });

  test('test_open_starting_window_property_main_windows_named_agon', () {
    final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
    final AppWindowList windowList = _buildWindowList(nativeWindows);

    windowList.openStartingWindow();
    windowList.openSectionWindow();

    for (final RecordingNativeWindow window in nativeWindows.opened) {
      expect(window.shape.title, productName);
    }
    expect(windowList.windows.first.page, isA<StartingWindowPage>());
  });

  test('test_forget_closed_window_property_keeps_every_other_window', () {
    final Random random = seededRandom(4103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
      final AppWindowList windowList = _buildWindowList(nativeWindows);
      final int windowCount = 1 + random.nextInt(_largestWindowCount);
      for (int opened = 0; opened < windowCount; opened += 1) {
        _openRandomWindow(windowList, random);
      }
      final List<RecordingNativeWindow> closed = <RecordingNativeWindow>[
        for (final RecordingNativeWindow window in nativeWindows.opened)
          if (random.nextBool()) window,
      ];

      for (final RecordingNativeWindow window in closed) {
        window.closeByPerson();
      }

      final List<RecordingNativeWindow> kept = <RecordingNativeWindow>[
        for (final RecordingNativeWindow window in nativeWindows.opened)
          if (!closed.contains(window)) window,
      ];
      expect(<Object>[
        for (final OpenAppWindow window in windowList.windows)
          window.nativeWindow,
      ], kept);
    }
  });

  test('test_reopen_property_opens_window_only_when_none_is_open', () {
    final Random random = seededRandom(4104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
      final AppWindowList windowList = _buildWindowList(nativeWindows);
      final int windowCount = random.nextInt(_largestWindowCount);
      for (int opened = 0; opened < windowCount; opened += 1) {
        _openRandomWindow(windowList, random);
      }
      if (random.nextBool()) {
        for (final RecordingNativeWindow window in nativeWindows.opened) {
          window.closeByPerson();
        }
      }
      final List<OpenAppWindow> before = windowList.windows;

      windowList.reopen();

      if (before.isEmpty) {
        expect(windowList.windows.single.page, isA<StartingWindowPage>());
        continue;
      }
      expect(windowList.windows, before);
      final RecordingNativeWindow front =
          before.first.nativeWindow as RecordingNativeWindow;
      expect(front.frontRequests, 1);
    }
  });

  test('test_app_window_list_property_tells_listeners_of_every_change', () {
    final Random random = seededRandom(4105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
      final AppWindowList windowList = _buildWindowList(nativeWindows);
      int changes = 0;
      windowList.addListener(() => changes += 1);
      final int windowCount = 1 + random.nextInt(_largestWindowCount);

      for (int opened = 0; opened < windowCount; opened += 1) {
        _openRandomWindow(windowList, random);
      }
      nativeWindows.opened.first.closeByPerson();

      expect(changes, windowCount + 1);
      expect(windowList.windows.length, windowCount - 1);
    }
  });
}
