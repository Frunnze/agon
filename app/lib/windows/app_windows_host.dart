import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/windows/app_window_content.dart';
import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/native_windows.dart';
import 'package:agent_orchestration/windows/open_app_window.dart';

class AppWindowsHost extends StatelessWidget {
  const AppWindowsHost({
    required this.windowList,
    required this.nativeWindows,
    required this.startup,
    required this.problemMessenger,
    super.key,
  });

  final AppWindowList windowList;
  final NativeWindows nativeWindows;
  final NodeStartup startup;
  final ProblemMessenger problemMessenger;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: windowList, builder: _buildWindows);
  }

  Widget _buildWindows(BuildContext context, Widget? _) {
    final List<Widget> windowViews = <Widget>[];

    for (final OpenAppWindow window in windowList.windows) {
      final Widget content = AppWindowContent(
        window: window,
        startup: startup,
        problemMessenger: problemMessenger,
        runWindowOpener: windowList,
      );
      windowViews.add(
        KeyedSubtree(
          key: ObjectKey(window),
          child: window.nativeWindow.showContent(content),
        ),
      );
    }

    return nativeWindows.arrangeWindows(windowViews);
  }
}
