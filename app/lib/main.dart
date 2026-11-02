import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';

const String _appDataEnvironmentName = 'APP_DATA';
const String _galleryAppData = 'gallery';
const String _appDataChoice = String.fromEnvironment(_appDataEnvironmentName);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final ProblemMessenger problemMessenger = ProblemMessenger();
  WidgetsBinding.instance.platformDispatcher.onError =
      problemMessenger.showProblem;

  if (_appDataChoice == _galleryAppData) {
    runApp(
      AgentOrchestrationApp(
        dependencies: buildGalleryDependencies(),
        navigation: AppNavigation(
          initialRoute: const SectionRoute(AppSection.tasks),
        ),
        messengerKey: problemMessenger.messengerKey,
      ),
    );
    return;
  }

  runApp(
    NodeStartupGate(
      startApp: startNodeApp,
      startAppAsNewDevice: startNodeAppAsNewDevice,
      messengerKey: problemMessenger.messengerKey,
    ),
  );
}
