import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/tray_presence.dart';

const String refusedLoginItemMessage = 'the login item was refused';
const String refusedTrayMessage = 'the tray was refused';
const String registerCall = 'register';
const String unregisterCall = 'unregister';
const String stayInTrayCall = 'stayInTray';
const String leaveTrayCall = 'leaveTray';

final class RecordingLoginItem implements LoginItem {
  bool isRegistered = false;
  final List<String> calls = <String>[];

  @override
  Future<void> register() async {
    calls.add(registerCall);
    isRegistered = true;
  }

  @override
  Future<void> unregister() async {
    calls.add(unregisterCall);
    isRegistered = false;
  }
}

final class RecordingTrayPresence implements TrayPresence {
  bool isInTray = false;
  final List<String> calls = <String>[];

  @override
  Future<void> stayInTray() async {
    calls.add(stayInTrayCall);
    isInTray = true;
  }

  @override
  Future<void> leaveTray() async {
    calls.add(leaveTrayCall);
    isInTray = false;
  }
}

final class RefusingLoginItem implements LoginItem {
  @override
  Future<void> register() async {
    throw StateError(refusedLoginItemMessage);
  }

  @override
  Future<void> unregister() async {
    throw StateError(refusedLoginItemMessage);
  }
}

final class RefusingTrayPresence implements TrayPresence {
  @override
  Future<void> stayInTray() async {
    throw StateError(refusedTrayMessage);
  }

  @override
  Future<void> leaveTray() async {
    throw StateError(refusedTrayMessage);
  }
}

final class RecordedRunnerPresence {
  RecordedRunnerPresence()
    : loginItem = RecordingLoginItem(),
      trayPresence = RecordingTrayPresence();

  final RecordingLoginItem loginItem;
  final RecordingTrayPresence trayPresence;

  RunnerPresence get presence {
    return RunnerPresence(loginItem: loginItem, trayPresence: trayPresence);
  }

  bool get isKeptInBackground {
    return loginItem.isRegistered && trayPresence.isInTray;
  }

  bool get isUntouched {
    return loginItem.calls.isEmpty && trayPresence.calls.isEmpty;
  }
}
