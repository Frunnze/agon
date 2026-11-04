import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';
import 'package:agent_orchestration/windows/app_window_page.dart';
import 'package:agent_orchestration/windows/open_app_window.dart';
import 'package:agent_orchestration/windows/run_window_app.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

class AppWindowContent extends StatefulWidget {
  const AppWindowContent({
    required this.window,
    required this.startup,
    required this.problemMessenger,
    required this.runWindowOpener,
    super.key,
  });

  final OpenAppWindow window;
  final NodeStartup startup;
  final ProblemMessenger problemMessenger;
  final RunWindowOpener runWindowOpener;

  @override
  State<AppWindowContent> createState() => _AppWindowContentState();
}

class _AppWindowContentState extends State<AppWindowContent> {
  late final MessengerKey _messengerKey = widget.problemMessenger
      .addMessengerKey();

  @override
  void dispose() {
    widget.problemMessenger.removeMessengerKey(_messengerKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NodeStartupGate(
      startup: widget.startup,
      buildStartedApp: _buildStartedApp,
    );
  }

  Widget _buildStartedApp(StartedApp started) {
    final AppWindowPage page = widget.window.page;

    switch (page) {
      case StartingWindowPage():
        return _buildMainApp(started, started.navigation);
      case SectionWindowPage(:final AppNavigation navigation):
        return _buildMainApp(started, navigation);
      case RunWindowPage(:final AppNavigation navigation):
        return RunWindowApp(
          navigation: navigation,
          dependencies: started.dependencies,
          onTopSwitch: widget.window.nativeWindow,
          messengerKey: _messengerKey,
        );
    }
  }

  Widget _buildMainApp(StartedApp started, AppNavigation navigation) {
    return AgentOrchestrationApp(
      dependencies: started.dependencies,
      navigation: navigation,
      messengerKey: _messengerKey,
      runWindowOpener: widget.runWindowOpener,
    );
  }
}
