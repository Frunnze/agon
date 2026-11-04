import 'package:flutter/material.dart';

import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';
import 'package:agent_orchestration/startup/startup_stage.dart';

typedef StartedAppBuilder = Widget Function(StartedApp started);

class NodeStartupGate extends StatelessWidget {
  const NodeStartupGate({
    required this.startup,
    required this.buildStartedApp,
    super.key,
  });

  final NodeStartup startup;
  final StartedAppBuilder buildStartedApp;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: startup, builder: _buildStage);
  }

  Widget _buildStage(BuildContext context, Widget? _) {
    final StartupStage stage = startup.stage;

    switch (stage) {
      case StartupWaiting():
        return const StartupWaitingPage();
      case StartupFailed(:final Object problem):
        return StartupProblemPage(
          problem: describeProblemForPeople(problem) ?? problem.toString(),
          onRetry: startup.start,
          onSetUpAgain: _chooseSetUpAgainAction(problem),
        );
      case StartupFinished(:final StartedApp started):
        return buildStartedApp(started);
    }
  }

  VoidCallback? _chooseSetUpAgainAction(Object problem) {
    if (!isForgottenDeviceProblem(problem)) {
      return null;
    }
    return startup.setUpAgain;
  }
}
