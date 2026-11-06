import 'dart:math';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/start_at_login_choice_store.dart';
import 'package:agent_orchestration/background/tray_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';

import '../../support/random_inputs.dart';

typedef PresenceState = ({
  bool isRegistered,
  bool isInTray,
  bool isStartAtLoginChosen,
});

const String registerEvent = 'register';
const String unregisterEvent = 'unregister';
const String stayInTrayEvent = 'stayInTray';
const String leaveTrayEvent = 'leaveTray';
const String readChoiceEvent = 'readChoice';
const String saveOnEvent = 'saveOn';
const String saveOffEvent = 'saveOff';
const List<String> presenceEvents = <String>[
  registerEvent,
  unregisterEvent,
  stayInTrayEvent,
  leaveTrayEvent,
  readChoiceEvent,
  saveOnEvent,
  saveOffEvent,
];
const int largestHistoryLength = 8;

enum PresenceChange { keepForRole, startAtLogin, stopStartingAtLogin, remove }

final class LoggedComputer
    implements LoginItem, TrayPresence, StartAtLoginChoiceStore {
  LoggedComputer({required this.isStartAtLoginChosen});

  final List<String> events = <String>[];
  bool isRegistered = false;
  bool isInTray = false;
  bool isStartAtLoginChosen;
  String? failingEvent;

  RunnerPresence get presence {
    return RunnerPresence(
      loginItem: this,
      trayPresence: this,
      startAtLoginChoiceStore: this,
    );
  }

  PresenceState get state {
    return (
      isRegistered: isRegistered,
      isInTray: isInTray,
      isStartAtLoginChosen: isStartAtLoginChosen,
    );
  }

  void _record(String event) {
    events.add(event);
    if (event == failingEvent) {
      throw StateError(event);
    }
  }

  @override
  Future<void> register() async {
    _record(registerEvent);
    isRegistered = true;
  }

  @override
  Future<void> unregister() async {
    _record(unregisterEvent);
    isRegistered = false;
  }

  @override
  Future<void> stayInTray() async {
    _record(stayInTrayEvent);
    isInTray = true;
  }

  @override
  Future<void> leaveTray() async {
    _record(leaveTrayEvent);
    isInTray = false;
  }

  @override
  Future<bool> readIsStartAtLoginChosen() async {
    _record(readChoiceEvent);
    return isStartAtLoginChosen;
  }

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) async {
    _record(isChosen ? saveOnEvent : saveOffEvent);
    isStartAtLoginChosen = isChosen;
  }
}

Future<void> applyPresenceChange({
  required PresenceChange change,
  required DeviceRole role,
  required RunnerPresence presence,
}) async {
  switch (change) {
    case PresenceChange.keepForRole:
      await presence.keepForRole(role);
    case PresenceChange.startAtLogin:
      await presence.startAtLogin();
    case PresenceChange.stopStartingAtLogin:
      await presence.stopStartingAtLogin();
    case PresenceChange.remove:
      await presence.remove();
  }
}

Future<void> applyRandomHistory(Random random, LoggedComputer computer) async {
  final int historyLength = random.nextInt(largestHistoryLength);
  for (int i = 0; i < historyLength; i += 1) {
    await applyPresenceChange(
      change: pickOne(random, PresenceChange.values),
      role: pickOne(random, DeviceRole.values),
      presence: computer.presence,
    );
  }
  computer.events.clear();
}
