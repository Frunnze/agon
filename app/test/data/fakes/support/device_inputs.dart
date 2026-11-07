import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../../support/random_inputs.dart';
import 'notification_counter.dart';

const DeviceId deviceTestThisDevice = DeviceId('this-device');
const List<String> sampleFolderParts = <String>[
  'code',
  'My Code',
  'café',
  'Ünïcødé',
  '-dash',
  '.hidden',
  'a..b',
];
const List<String> _trailingFolderNoise = <String>[
  '/',
  '//',
  ' ',
  '\u3000',
  '/ /',
  '\\',
];
const int _largestFolderDepth = 4;
const int _largestOtherDeviceCount = 5;
const int _largestWorkspaceCount = 3;

const List<WorkspaceId> sampleDeviceWorkspaceIds = <WorkspaceId>[
  WorkspaceId('workspace-acme'),
  WorkspaceId('workspace-personal'),
  WorkspaceId('workspace-lab'),
  WorkspaceId('workspace-ünïcødé'),
];

typedef CountedDevices = ({
  FakeDeviceRepository repository,
  NotificationCounter notifications,
  List<Device> seeds,
});

List<WorkspaceId> randomDeviceWorkspaces(Random random) {
  final Set<WorkspaceId> workspaces = <WorkspaceId>{};
  final int count = random.nextInt(_largestWorkspaceCount);
  for (int i = 0; i < count; i += 1) {
    workspaces.add(pickOne(random, sampleDeviceWorkspaceIds));
  }
  return workspaces.toList();
}

Device randomDeviceWithId(
  Random random,
  DeviceId deviceId, {
  required bool isRevoked,
}) {
  return Device(
    id: deviceId,
    name: randomText(random),
    role: pickOne(random, DeviceRole.values),
    kind: pickOne(random, DeviceKind.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    signingPublicKey: <int>[random.nextInt(256)],
    sealingPublicKey: <int>[random.nextInt(256)],
    workspaces: randomDeviceWorkspaces(random),
    pairedAt: randomUtcMoment(random),
    approvedBy: random.nextBool() ? null : deviceTestThisDevice,
    lastSeen: randomUtcMoment(random),
    revoked: isRevoked,
  );
}

List<Device> randomDeviceSeeds(Random random) {
  final List<Device> others = <Device>[];
  final int otherCount = random.nextInt(_largestOtherDeviceCount);
  for (int i = 0; i < otherCount; i += 1) {
    final DeviceId deviceId = DeviceId('device-$i-${randomText(random)}');
    others.add(
      randomDeviceWithId(random, deviceId, isRevoked: random.nextBool()),
    );
  }

  final Device thisDevice = randomDeviceWithId(
    random,
    deviceTestThisDevice,
    isRevoked: false,
  );
  final int thisDevicePlace = random.nextInt(others.length + 1);
  others.insert(thisDevicePlace, thisDevice);
  return others;
}

FakeDeviceRepository buildDeviceRepository(List<Device> seeds) {
  return FakeDeviceRepository(
    devices: seeds,
    currentDeviceId: deviceTestThisDevice,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
}

CountedDevices buildCountedDeviceRepository(Random random) {
  final List<Device> seeds = randomDeviceSeeds(random);
  final FakeDeviceRepository repository = buildDeviceRepository(seeds);
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (repository: repository, notifications: notifications, seeds: seeds);
}

List<String> describeDeviceIds(List<Device> devices) {
  final List<String> identifiers = <String>[];
  for (final Device device in devices) {
    identifiers.add(device.id.value);
  }
  return identifiers;
}

Future<void> changeRandomDeviceValidly(
  Random random,
  FakeDeviceRepository repository,
) async {
  final Device device = pickOne(random, repository.listDevices());
  final WorkspaceId workspaceId = pickOne(random, sampleDeviceWorkspaceIds);
  final bool isOther = device.id != deviceTestThisDevice;
  final bool canJoin =
      !device.revoked && !device.workspaces.contains(workspaceId);

  if (isOther && !device.revoked && random.nextBool()) {
    await repository.revokeDevice(device.id);
  } else if (canJoin) {
    await repository.addDeviceToWorkspace(device.id, workspaceId);
  } else if (device.workspaces.contains(workspaceId)) {
    await repository.removeDeviceFromWorkspace(device.id, workspaceId);
  }
}

Device? _pickOneOrNone(Random random, List<Device> candidates) {
  if (candidates.isEmpty) {
    return null;
  }
  return pickOne(random, candidates);
}

Device? pickActiveOtherDevice(Random random, List<Device> devices) {
  return _pickOneOrNone(random, <Device>[
    for (final Device device in devices)
      if (device.id != deviceTestThisDevice && !device.revoked) device,
  ]);
}

Device? pickRevokedOtherDevice(Random random, List<Device> devices) {
  return _pickOneOrNone(random, <Device>[
    for (final Device device in devices)
      if (device.id != deviceTestThisDevice && device.revoked) device,
  ]);
}

void expectOtherDevicesUnchanged(
  List<Device> before,
  List<Device> after, {
  required DeviceId changedId,
}) {
  expect(describeDeviceIds(after), describeDeviceIds(before));
  for (int index = 0; index < before.length; index += 1) {
    if (before[index].id != changedId) {
      expect(after[index], same(before[index]));
    }
  }
}

String randomAbsoluteFolderPath(Random random) {
  final List<String> parts = <String>[];
  final int depth = 1 + random.nextInt(_largestFolderDepth);
  for (int i = 0; i < depth; i += 1) {
    parts.add(pickOne(random, sampleFolderParts));
  }
  return '/${parts.join('/')}';
}

String randomTrailingFolderNoise(Random random) {
  final StringBuffer noise = StringBuffer();
  final int count = random.nextInt(3);
  for (int i = 0; i < count; i += 1) {
    noise.write(pickOne(random, _trailingFolderNoise));
  }
  return noise.toString();
}

FakeDeviceRepository buildFolderTestRepository(
  Set<String> gitlessFolderPaths,
) {
  return FakeDeviceRepository(
    devices: <Device>[
      randomDeviceWithId(Random(0), deviceTestThisDevice, isRevoked: false),
    ],
    currentDeviceId: deviceTestThisDevice,
    peerAddressProblem: null,
    gitlessFolderPaths: gitlessFolderPaths,
  );
}

String? readCheckedFolderPath(CheckedFolder checked) {
  return parseLocalFolderAddress(checked.repository.address)?.path;
}
