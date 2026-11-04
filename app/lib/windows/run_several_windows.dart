import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/app_windows_host.dart';
import 'package:agent_orchestration/windows/flutter_windowing/flutter_native_windows.dart';
import 'package:agent_orchestration/windows/window_menu.dart';

void runSeveralWindows({
  required NodeStartup startup,
  required ProblemMessenger problemMessenger,
}) {
  const FlutterNativeWindows nativeWindows = FlutterNativeWindows();
  final AppWindowList windowList = AppWindowList(nativeWindows: nativeWindows);
  listenToWindowMenu(windowList);
  windowList.openStartingWindow();

  runWidget(
    AppWindowsHost(
      windowList: windowList,
      nativeWindows: nativeWindows,
      startup: startup,
      problemMessenger: problemMessenger,
    ),
  );
}
