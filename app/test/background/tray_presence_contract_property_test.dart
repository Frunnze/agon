import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/channel_presence.dart';

import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';
import 'support/logged_computer.dart';
import 'support/switch_contract.dart';

const int _stayInTraySeed = 9490020;
const int _leaveTraySeed = 9490030;
const MethodChannel _workingChannel = MethodChannel(
  'test/tray_presence_contract/working',
);
const MethodChannel _refusingChannel = MethodChannel(
  'test/tray_presence_contract/refusing',
);
const MethodChannel _missingChannel = MethodChannel(
  'test/tray_presence_contract/missing',
);

const List<SwitchSubjectMaker> _subjectMakers = <SwitchSubjectMaker>[
  _makeChannelSubject,
  _makeRecordingSubject,
  _makeLoggedComputerSubject,
];

SwitchSubject _makeChannelSubject(Random random) {
  final NativeSwitchSide nativeSide = listenAsNativeSwitchSide(
    channel: _workingChannel,
    onMethod: stayInTrayMethod,
    offMethod: leaveTrayMethod,
  );
  const ChannelTrayPresence trayPresence = ChannelTrayPresence(
    channel: _workingChannel,
  );
  return SwitchSubject(
    implementationName: 'ChannelTrayPresence',
    switchOn: trayPresence.stayInTray,
    switchOff: trayPresence.leaveTray,
    readIsOn: () => nativeSide.isOn,
  );
}

SwitchSubject _makeRecordingSubject(Random random) {
  final RecordingTrayPresence trayPresence = RecordingTrayPresence();
  return SwitchSubject(
    implementationName: 'RecordingTrayPresence',
    switchOn: trayPresence.stayInTray,
    switchOff: trayPresence.leaveTray,
    readIsOn: () => trayPresence.isInTray,
  );
}

SwitchSubject _makeLoggedComputerSubject(Random random) {
  final LoggedComputer computer = LoggedComputer(
    isStartAtLoginChosen: random.nextBool(),
  );
  return SwitchSubject(
    implementationName: 'LoggedComputer',
    switchOn: computer.stayInTray,
    switchOff: computer.leaveTray,
    readIsOn: () => computer.isInTray,
  );
}

ChannelTrayPresence _refusedChannelTrayPresence(Random random) {
  listenAsRefusingNativeSide(
    channel: _refusingChannel,
    failureMessage: randomText(random),
  );
  return const ChannelTrayPresence(channel: _refusingChannel);
}

PresenceCall _refusedChannelStayInTray(Random random) {
  return _refusedChannelTrayPresence(random).stayInTray;
}

PresenceCall _missingChannelStayInTray(Random random) {
  return const ChannelTrayPresence(channel: _missingChannel).stayInTray;
}

PresenceCall _refusingStayInTray(Random random) {
  return RefusingTrayPresence().stayInTray;
}

PresenceCall _failingLoggedComputerStayInTray(Random random) {
  return buildLoggedComputerFailingAt(
    random: random,
    failingEvent: stayInTrayEvent,
  ).stayInTray;
}

PresenceCall _refusedChannelLeaveTray(Random random) {
  return _refusedChannelTrayPresence(random).leaveTray;
}

PresenceCall _missingChannelLeaveTray(Random random) {
  return const ChannelTrayPresence(channel: _missingChannel).leaveTray;
}

PresenceCall _refusingLeaveTray(Random random) {
  return RefusingTrayPresence().leaveTray;
}

PresenceCall _failingLoggedComputerLeaveTray(Random random) {
  return buildLoggedComputerFailingAt(
    random: random,
    failingEvent: leaveTrayEvent,
  ).leaveTray;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testSwitchOnContract(
    testPrefix: 'test_tray_presence_stay_in_tray_property',
    seed: _stayInTraySeed,
    subjectMakers: _subjectMakers,
    failingCallMakers: <FailingCallMaker>[
      _refusedChannelStayInTray,
      _missingChannelStayInTray,
      _refusingStayInTray,
      _failingLoggedComputerStayInTray,
    ],
  );

  testSwitchOffContract(
    testPrefix: 'test_tray_presence_leave_tray_property',
    seed: _leaveTraySeed,
    subjectMakers: _subjectMakers,
    failingCallMakers: <FailingCallMaker>[
      _refusedChannelLeaveTray,
      _missingChannelLeaveTray,
      _refusingLeaveTray,
      _failingLoggedComputerLeaveTray,
    ],
  );
}
