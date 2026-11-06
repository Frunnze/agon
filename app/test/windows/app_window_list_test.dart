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
const int _runChoiceCount = 3;
const int _largestStepCount = 12;

AppWindowList _buildWindowList(RecordingNativeWindows nativeWindows) {
  return AppWindowList(nativeWindows: nativeWindows);
}

void _openRandomWindow(
  AppWindowList windowList,
  Random random, {
  required int windowNumber,
}) {
  switch (random.nextInt(3)) {
    case 0:
      windowList.openStartingWindow();
    case 1:
      windowList.openSectionWindow();
    default:
      windowList.openRunWindow(
        runId: RunId('run-$windowNumber'),
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

int _countRunWindows(AppWindowList windowList, RunId runId) {
  final TaskRunRoute runRoute = TaskRunRoute(runId);
  int runWindowCount = 0;

  for (final OpenAppWindow window in windowList.windows) {
    final AppWindowPage page = window.page;
    if (page is RunWindowPage && page.navigation.routes.contains(runRoute)) {
      runWindowCount += 1;
    }
  }

  return runWindowCount;
}

void _closeRandomWindow(AppWindowList windowList, Random random) {
  final List<OpenAppWindow> windows = windowList.windows;
  final OpenAppWindow closing = windows[random.nextInt(windows.length)];
  final RecordingNativeWindow closingNativeWindow =
      closing.nativeWindow as RecordingNativeWindow;
  closingNativeWindow.closeByPerson();
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
      expect(
        Set<AppNavigation>.identity()..addAll(navigations),
        hasLength(windowCount),
      );
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

  test('test_open_run_window_property_repeat_brings_same_window_front', () {
    final Random random = seededRandom(4106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
      final AppWindowList windowList = _buildWindowList(nativeWindows);
      final RunId runId = RunId('run-${random.nextInt(999)}');
      final int pressCount = 2 + random.nextInt(_largestWindowCount);

      for (int pressed = 0; pressed < pressCount; pressed += 1) {
        windowList.openRunWindow(runId: runId, title: randomText(random));
      }

      final RecordingNativeWindow runWindow = nativeWindows.opened.single;
      expect(runWindow.frontRequests, pressCount - 1);
      expect(windowList.windows.single.nativeWindow, runWindow);
    }
  });

  test('test_open_run_window_property_keeps_one_window_per_run', () {
    final Random random = seededRandom(4107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppWindowList windowList = _buildWindowList(
        RecordingNativeWindows(),
      );
      final List<RunId> runChoices = <RunId>[
        for (int choice = 0; choice < _runChoiceCount; choice += 1)
          RunId('run-$choice'),
      ];
      final int stepCount = 1 + random.nextInt(_largestStepCount);

      for (int step = 0; step < stepCount; step += 1) {
        final bool closesWindow =
            windowList.windows.isNotEmpty && random.nextBool();
        if (closesWindow) {
          _closeRandomWindow(windowList, random);
          continue;
        }
        final RunId runId = runChoices[random.nextInt(_runChoiceCount)];
        windowList.openRunWindow(runId: runId, title: randomText(random));
        expect(_countRunWindows(windowList, runId), 1);
      }

      for (final RunId runId in runChoices) {
        expect(_countRunWindows(windowList, runId), lessThanOrEqualTo(1));
      }
    }
  });

  test('test_open_run_window_property_closed_run_window_opens_again', () {
    final Random random = seededRandom(4108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingNativeWindows nativeWindows = RecordingNativeWindows();
      final AppWindowList windowList = _buildWindowList(nativeWindows);
      final RunId runId = RunId('run-${random.nextInt(999)}');
      final int reopenCount = 1 + random.nextInt(_largestWindowCount);

      windowList.openRunWindow(runId: runId, title: randomText(random));
      for (int reopened = 0; reopened < reopenCount; reopened += 1) {
        nativeWindows.opened.last.closeByPerson();
        windowList.openRunWindow(runId: runId, title: randomText(random));
      }

      expect(nativeWindows.opened, hasLength(reopenCount + 1));
      expect(
        windowList.windows.single.nativeWindow,
        nativeWindows.opened.last,
      );
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
        _openRandomWindow(windowList, random, windowNumber: opened);
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
        _openRandomWindow(windowList, random, windowNumber: opened);
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
        _openRandomWindow(windowList, random, windowNumber: opened);
      }
      nativeWindows.opened.first.closeByPerson();

      expect(changes, windowCount + 1);
      expect(windowList.windows.length, windowCount - 1);
    }
  });
}
