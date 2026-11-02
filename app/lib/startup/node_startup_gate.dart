import 'package:flutter/material.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';

class NodeStartupGate extends StatefulWidget {
  const NodeStartupGate({
    required this.startApp,
    required this.startAppAsNewDevice,
    required this.messengerKey,
    super.key,
  });

  final Future<StartedApp> Function() startApp;
  final Future<StartedApp> Function() startAppAsNewDevice;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<NodeStartupGate> createState() => _NodeStartupGateState();
}

class _NodeStartupGateState extends State<NodeStartupGate> {
  late Future<StartedApp> _start = widget.startApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StartedApp>(future: _start, builder: _buildStage);
  }

  Widget _buildStage(BuildContext context, AsyncSnapshot<StartedApp> start) {
    if (start.connectionState == ConnectionState.waiting) {
      return const StartupWaitingPage();
    }

    final Object? problem = start.error;
    if (problem != null) {
      return StartupProblemPage(
        problem: describeProblemForPeople(problem) ?? problem.toString(),
        onRetry: _retry,
        onSetUpAgain: _chooseSetUpAgainAction(problem),
      );
    }

    final StartedApp started = start.requireData;
    return AgentOrchestrationApp(
      dependencies: started.dependencies,
      navigation: started.navigation,
      messengerKey: widget.messengerKey,
    );
  }

  VoidCallback? _chooseSetUpAgainAction(Object problem) {
    if (!isForgottenDeviceProblem(problem)) {
      return null;
    }
    return _setUpAgain;
  }

  void _retry() {
    _showStart(widget.startApp());
  }

  void _setUpAgain() {
    _showStart(widget.startAppAsNewDevice());
  }

  void _showStart(Future<StartedApp> nextStart) {
    setState(() {
      _start = nextStart;
    });
  }
}
