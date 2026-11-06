import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'hostile_texts.dart';
import 'node_json_primitives.dart';
import 'random_moments.dart';
import 'random_typed_values.dart';

Device randomDevice(Random random) {
  return Device(
    id: randomDeviceId(random),
    name: randomHostileText(random),
    role: pickOne(random, DeviceRole.values),
    kind: pickOne(random, DeviceKind.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    signingPublicKey: randomBytes(random),
    sealingPublicKey: randomBytes(random),
    workspaces: randomWorkspaceIds(random),
    pairedAt: randomPreciseMoment(random),
    approvedBy: random.nextBool() ? null : randomDeviceId(random),
    lastSeen: randomPreciseMoment(random),
    revoked: random.nextBool(),
  );
}

Device copyDeviceWithLists(
  Device device,
  List<int> signingPublicKey,
  List<int> sealingPublicKey,
  List<WorkspaceId> workspaces,
) {
  return Device(
    id: device.id,
    name: device.name,
    role: device.role,
    kind: device.kind,
    keyKind: device.keyKind,
    signingPublicKey: signingPublicKey,
    sealingPublicKey: sealingPublicKey,
    workspaces: workspaces,
    pairedAt: device.pairedAt,
    approvedBy: device.approvedBy,
    lastSeen: device.lastSeen,
    revoked: device.revoked,
  );
}

void expectSameDevice(Device actual, Device expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.role, same(expected.role));
  expect(actual.kind, same(expected.kind));
  expect(actual.keyKind, same(expected.keyKind));
  expect(actual.signingPublicKey, equals(expected.signingPublicKey));
  expect(actual.sealingPublicKey, equals(expected.sealingPublicKey));
  expect(actual.workspaces, equals(expected.workspaces));
  expect(actual.pairedAt.isAtSameMomentAs(expected.pairedAt), isTrue);
  expect(actual.approvedBy, expected.approvedBy);
  expect(actual.lastSeen.isAtSameMomentAs(expected.lastSeen), isTrue);
  expect(actual.revoked, expected.revoked);
}
