import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';
import 'support/autostart_expectations.dart';
import 'support/autostart_folders.dart';
import 'support/hostile_paths.dart';
import 'support/logged_computer.dart';
import 'support/switch_contract.dart';

const int _registerSeed = 9490000;
const int _unregisterSeed = 9490010;
const MethodChannel _workingChannel = MethodChannel(
  'test/login_item_contract/working',
);
const MethodChannel _refusingChannel = MethodChannel(
  'test/login_item_contract/refusing',
);
const MethodChannel _missingChannel = MethodChannel(
  'test/login_item_contract/missing',
);

const List<SwitchSubjectMaker> _subjectMakers = <SwitchSubjectMaker>[
  _makeChannelSubject,
  _makeXdgSubject,
  _makeRecordingSubject,
  _makeLoggedComputerSubject,
];

SwitchSubject _makeChannelSubject(Random random) {
  final NativeSwitchSide nativeSide = listenAsNativeSwitchSide(
    channel: _workingChannel,
    onMethod: registerLoginItemMethod,
    offMethod: unregisterLoginItemMethod,
  );
  const ChannelLoginItem loginItem = ChannelLoginItem(
    channel: _workingChannel,
  );
  return SwitchSubject(
    implementationName: 'ChannelLoginItem',
    switchOn: loginItem.register,
    switchOff: loginItem.unregister,
    readIsOn: () => nativeSide.isOn,
  );
}

SwitchSubject _makeXdgSubject(Random random) {
  final Map<String, String> environment = randomEnvironmentInside(
    random,
    createTemporaryFolder(),
  );
  final File entry = File(locateAutostartEntry(environment));
  final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
    environment: environment,
    executablePath: randomHostileAbsolutePath(random),
  );
  return SwitchSubject(
    implementationName: 'XdgAutostartLoginItem',
    switchOn: loginItem.register,
    switchOff: loginItem.unregister,
    readIsOn: entry.existsSync,
  );
}

SwitchSubject _makeRecordingSubject(Random random) {
  final RecordingLoginItem loginItem = RecordingLoginItem();
  return SwitchSubject(
    implementationName: 'RecordingLoginItem',
    switchOn: loginItem.register,
    switchOff: loginItem.unregister,
    readIsOn: () => loginItem.isRegistered,
  );
}

SwitchSubject _makeLoggedComputerSubject(Random random) {
  final LoggedComputer computer = LoggedComputer(
    isStartAtLoginChosen: random.nextBool(),
  );
  return SwitchSubject(
    implementationName: 'LoggedComputer',
    switchOn: computer.register,
    switchOff: computer.unregister,
    readIsOn: () => computer.isRegistered,
  );
}

ChannelLoginItem _refusedChannelLoginItem(Random random) {
  listenAsRefusingNativeSide(
    channel: _refusingChannel,
    failureMessage: randomText(random),
  );
  return const ChannelLoginItem(channel: _refusingChannel);
}

XdgAutostartLoginItem _blockedXdgLoginItem(Random random) {
  final Map<String, String> environment = randomEnvironmentInside(
    random,
    createTemporaryFolder(),
  );
  blockWithFolder(locateAutostartEntry(environment));
  return XdgAutostartLoginItem(
    environment: environment,
    executablePath: randomHostileAbsolutePath(random),
  );
}

PresenceCall _refusedChannelRegister(Random random) {
  return _refusedChannelLoginItem(random).register;
}

PresenceCall _missingChannelRegister(Random random) {
  return const ChannelLoginItem(channel: _missingChannel).register;
}

PresenceCall _blockedXdgRegister(Random random) {
  return _blockedXdgLoginItem(random).register;
}

PresenceCall _refusingRegister(Random random) {
  return RefusingLoginItem().register;
}

PresenceCall _failingLoggedComputerRegister(Random random) {
  return buildLoggedComputerFailingAt(
    random: random,
    failingEvent: registerEvent,
  ).register;
}

PresenceCall _refusedChannelUnregister(Random random) {
  return _refusedChannelLoginItem(random).unregister;
}

PresenceCall _missingChannelUnregister(Random random) {
  return const ChannelLoginItem(channel: _missingChannel).unregister;
}

PresenceCall _blockedXdgUnregister(Random random) {
  return _blockedXdgLoginItem(random).unregister;
}

PresenceCall _refusingUnregister(Random random) {
  return RefusingLoginItem().unregister;
}

PresenceCall _failingLoggedComputerUnregister(Random random) {
  return buildLoggedComputerFailingAt(
    random: random,
    failingEvent: unregisterEvent,
  ).unregister;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testSwitchOnContract(
    testPrefix: 'test_login_item_register_property',
    seed: _registerSeed,
    subjectMakers: _subjectMakers,
    failingCallMakers: <FailingCallMaker>[
      _refusedChannelRegister,
      _missingChannelRegister,
      _blockedXdgRegister,
      _refusingRegister,
      _failingLoggedComputerRegister,
    ],
  );

  testSwitchOffContract(
    testPrefix: 'test_login_item_unregister_property',
    seed: _unregisterSeed,
    subjectMakers: _subjectMakers,
    failingCallMakers: <FailingCallMaker>[
      _refusedChannelUnregister,
      _missingChannelUnregister,
      _blockedXdgUnregister,
      _refusingUnregister,
      _failingLoggedComputerUnregister,
    ],
  );
}
