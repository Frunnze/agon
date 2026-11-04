import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';
import 'package:agent_orchestration/windows/flutter_windowing/flutter_windowing_switch.dart';
import 'package:agent_orchestration/windows/run_several_windows.dart';
import 'package:agent_orchestration/windows/several_windows_support.dart';

const String _appDataEnvironmentName = 'APP_DATA';
const String _galleryAppData = 'gallery';
const String _appDataChoice = String.fromEnvironment(_appDataEnvironmentName);

void main() {
  final bool hasSeveralWindows = supportsSeveralWindows(defaultTargetPlatform);
  if (hasSeveralWindows) {
    turnOnFlutterWindowing();
  }

  WidgetsFlutterBinding.ensureInitialized();
  final ProblemMessenger problemMessenger = ProblemMessenger();
  WidgetsBinding.instance.platformDispatcher.onError =
      problemMessenger.showProblem;

  final NodeStartup startup = _chooseStartup();
  startup.start();

  if (hasSeveralWindows) {
    runSeveralWindows(startup: startup, problemMessenger: problemMessenger);
    return;
  }

  final MessengerKey messengerKey = problemMessenger.addMessengerKey();
  runApp(
    NodeStartupGate(
      startup: startup,
      buildStartedApp: (StartedApp started) =>
          _buildSingleWindowApp(started, messengerKey),
    ),
  );
}

NodeStartup _chooseStartup() {
  if (_appDataChoice == _galleryAppData) {
    return NodeStartup(
      startApp: _startGallery,
      startAppAsNewDevice: _startGallery,
    );
  }
  return NodeStartup(
    startApp: startNodeApp,
    startAppAsNewDevice: startNodeAppAsNewDevice,
  );
}

Future<StartedApp> _startGallery() async {
  return StartedApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.tasks),
    ),
  );
}

Widget _buildSingleWindowApp(StartedApp started, MessengerKey messengerKey) {
  return AgentOrchestrationApp(
    dependencies: started.dependencies,
    navigation: started.navigation,
    messengerKey: messengerKey,
    runWindowOpener: null,
  );
}
