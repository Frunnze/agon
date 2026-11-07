import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/random_catalog_json.dart';
import 'held_next_reply_transport.dart';
import 'simulated_device_node.dart';

const String rigThisDeviceId = 'rig-this-device';
const int _largestOtherDeviceCount = 4;

typedef DeviceRig = ({
  SimulatedDeviceNode node,
  HeldNextReplyTransport transport,
  NodeBackedDeviceRepository repository,
});

DeviceRig buildDeviceRig(Random random) {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: rigThisDeviceId,
  );
  final Map<String, Object?> thisDevice = randomDeviceJson(random);
  thisDevice['id'] = rigThisDeviceId;
  thisDevice['revoked'] = false;
  simulated.devices[rigThisDeviceId] = thisDevice;
  final int otherDeviceCount = random.nextInt(_largestOtherDeviceCount);
  for (int i = 0; i < otherDeviceCount; i += 1) {
    simulated.addDeviceFromElsewhere(random);
  }

  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  return (
    node: simulated,
    transport: transport,
    repository: NodeBackedDeviceRepository(
      channel: NodeCommandChannel(transport: transport),
    ),
  );
}

String addUnrevokedDeviceFromElsewhere(
  Random random,
  SimulatedDeviceNode node,
) {
  final String deviceId = node.addDeviceFromElsewhere(random);
  node.devices[deviceId]!['revoked'] = false;
  return deviceId;
}

List<Object?> describeListedDevices(List<Device> devices) {
  return <Object?>[
    for (final Device device in devices)
      <Object?>[
        device.id.value,
        device.revoked,
        <String>[
          for (final WorkspaceId workspaceId in device.workspaces)
            workspaceId.value,
        ],
      ],
  ];
}

List<Object?> describeNodeDevices(SimulatedDeviceNode node) {
  return <Object?>[
    for (final Map<String, Object?> device in node.devices.values)
      <Object?>[
        device['id'],
        device['revoked'],
        List<Object?>.of(device['workspaces']! as List<Object?>),
      ],
  ];
}

void expectRepositoryMirrorsNode(DeviceRig rig) {
  expect(
    describeListedDevices(rig.repository.listDevices()),
    describeNodeDevices(rig.node),
  );
}
