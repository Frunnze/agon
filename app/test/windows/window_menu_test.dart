import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/app_window_page.dart';
import 'package:agent_orchestration/windows/open_app_window.dart';
import 'package:agent_orchestration/windows/several_windows_support.dart';
import 'package:agent_orchestration/windows/window_menu.dart';

import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';

void main() {
  test('test_supports_several_windows_property_only_computers_with_api', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      expect(
        supportsSeveralWindows(platform),
        platform == TargetPlatform.macOS,
        reason: platform.name,
      );
    }
  });

  test('test_answer_window_menu_property_new_window_opens_main_window', () {
    final Random random = seededRandom(8201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppWindowList windowList = AppWindowList(
        nativeWindows: RecordingNativeWindows(),
      );
      final int presses = 1 + random.nextInt(4);

      for (int press = 0; press < presses; press += 1) {
        answerWindowMenu(
          const MethodCall(openNewWindowMethod),
          windowList: windowList,
        );
      }

      expect(windowList.windows, hasLength(presses));
      for (final AppWindowPage page in <AppWindowPage>[
        for (final OpenAppWindow window in windowList.windows) window.page,
      ]) {
        expect(page, isA<SectionWindowPage>());
      }
    }
  });

  test('test_answer_window_menu_property_reopen_brings_a_window_back', () {
    final AppWindowList windowList = AppWindowList(
      nativeWindows: RecordingNativeWindows(),
    );

    answerWindowMenu(const MethodCall(reopenMethod), windowList: windowList);
    answerWindowMenu(const MethodCall(reopenMethod), windowList: windowList);

    expect(windowList.windows.single.page, isA<StartingWindowPage>());
  });

  test('test_answer_window_menu_property_unknown_calls_are_refused', () {
    final Random random = seededRandom(8202);
    final AppWindowList windowList = AppWindowList(
      nativeWindows: RecordingNativeWindows(),
    );
    for (int i = 0; i < propertyIterations; i += 1) {
      final String method = 'unknown-${randomText(random)}';
      expect(
        () => answerWindowMenu(MethodCall(method), windowList: windowList),
        throwsA(isA<MissingPluginException>()),
      );
    }
    expect(windowList.windows, isEmpty);
  });
}
