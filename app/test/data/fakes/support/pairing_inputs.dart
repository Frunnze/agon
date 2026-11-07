import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../support/random_inputs.dart';
import 'notification_counter.dart';

const Duration pairingLifetime = Duration(minutes: 5);
const WorkspaceId foreignWorkspaceId = WorkspaceId('workspace-elsewhere');
const List<WorkspaceId> approverWorkspaceIds = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];
const String _deviceNameAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const int _longestDeviceName = 12;
const int _largestSessionAgeSeconds = 600;
const int _largestWorkspaceChoice = 5;
const String _requestCode = '4F7-K2Q';
const List<String> _requestWords = <String>['maple', 'orbit', 'cinder'];

typedef PairingSetup = ({
  FakePairingRepository pairing,
  FakeDeviceRepository devices,
  NotificationCounter notifications,
  DateTime now,
});

PairingSetup buildPairingSetup({
  required PairingSession? session,
  required PairingRequest? request,
  required DateTime now,
}) {
  final FakeDeviceRepository devices = FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
  final FakePairingRepository pairing = FakePairingRepository(
    session: session,
    request: request,
    clock: FixedClock(now),
    deviceRepository: devices,
    joinOutcome: galleryPairingOutcome,
    startedPairingRendezvousProblem: null,
  );
  final NotificationCounter notifications = NotificationCounter();
  pairing.addListener(notifications.record);
  return (
    pairing: pairing,
    devices: devices,
    notifications: notifications,
    now: now,
  );
}

PairingSession randomPairingSession(Random random, DateTime now) {
  final Duration age = Duration(
    seconds: random.nextInt(_largestSessionAgeSeconds),
  );
  final DateTime createdAt = now.subtract(age);
  return PairingSession(
    code: randomText(random),
    createdAt: createdAt,
    expiresAt: createdAt.add(pairingLifetime),
    rendezvousProblem: random.nextBool() ? null : randomText(random),
  );
}

PairingSession liveSessionAt(DateTime now) {
  return PairingSession(
    code: _requestCode,
    createdAt: now,
    expiresAt: now.add(pairingLifetime),
    rendezvousProblem: null,
  );
}

bool isLiveAt(PairingSession? session, DateTime now) {
  if (session == null) {
    return false;
  }
  return session.expiresAt.isAfter(now);
}

String randomDeviceName(Random random) {
  final int length = 1 + random.nextInt(_longestDeviceName);
  final StringBuffer name = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    name.write(pickOne(random, _deviceNameAlphabet.split('')));
  }
  return name.toString();
}

PairingRequest randomPairingRequest(Random random) {
  return PairingRequest(
    deviceName: randomDeviceName(random),
    role: pickOne(random, DeviceRole.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    codeUsed: _requestCode,
    fingerprintWords: _requestWords,
    link: pickOne(random, <RunnerLink?>[null, ...RunnerLink.values]),
  );
}

List<WorkspaceId> randomApproverWorkspaces(Random random) {
  final int count = 1 + random.nextInt(_largestWorkspaceChoice);
  return <WorkspaceId>[
    for (int i = 0; i < count; i += 1) pickOne(random, approverWorkspaceIds),
  ];
}

List<WorkspaceId> listDistinctInOrder(List<WorkspaceId> workspaces) {
  final List<WorkspaceId> distinct = <WorkspaceId>[];
  for (final WorkspaceId workspace in workspaces) {
    if (!distinct.contains(workspace)) {
      distinct.add(workspace);
    }
  }
  return distinct;
}

DateTime randomPairingMoment(Random random) {
  return galleryNow.add(Duration(seconds: random.nextInt(3600)));
}

PairingSetup buildWaitingPairingSetup(Random random) {
  final DateTime now = randomPairingMoment(random);
  return buildPairingSetup(
    session: liveSessionAt(now),
    request: randomPairingRequest(random),
    now: now,
  );
}
