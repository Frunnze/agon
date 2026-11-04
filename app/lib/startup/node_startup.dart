import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/startup_stage.dart';

typedef AppStart = Future<StartedApp> Function();

final class NodeStartup extends ChangeNotifier {
  NodeStartup({
    required AppStart startApp,
    required AppStart startAppAsNewDevice,
  }) : _startApp = startApp,
       _startAppAsNewDevice = startAppAsNewDevice;

  final AppStart _startApp;
  final AppStart _startAppAsNewDevice;
  StartupStage _stage = const StartupWaiting();
  Future<StartedApp>? _latestAttempt;

  StartupStage get stage => _stage;

  void start() {
    unawaited(_follow(_startApp()));
  }

  void setUpAgain() {
    unawaited(_follow(_startAppAsNewDevice()));
  }

  Future<void> _follow(Future<StartedApp> attempt) async {
    _latestAttempt = attempt;
    _show(const StartupWaiting());

    final StartupStage outcome = await _awaitOutcome(attempt);
    if (identical(attempt, _latestAttempt)) {
      _show(outcome);
    }
  }

  void _show(StartupStage stage) {
    _stage = stage;
    notifyListeners();
  }
}

Future<StartupStage> _awaitOutcome(Future<StartedApp> attempt) async {
  try {
    return StartupFinished(await attempt);
  } on Object catch (problem) {
    return StartupFailed(problem);
  }
}
