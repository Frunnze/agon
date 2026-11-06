import 'package:agent_orchestration/bridge/codecs/device_values.dart';

import '../support/node_wire_names.dart';
import '../support/wire_name_decoder_properties.dart';

const int _firstSeed = 50201;
const int _seedsPerFamily = 2;

const List<WireNameDecoderFamily> _families = <WireNameDecoderFamily>[
  WireNameDecoderFamily(
    typeName: 'device_role',
    choices: DeviceRole.values,
    nodeNames: nodeDeviceRoles,
    decode: DeviceRole.decode,
  ),
  WireNameDecoderFamily(
    typeName: 'device_kind',
    choices: DeviceKind.values,
    nodeNames: nodeDeviceKinds,
    decode: DeviceKind.decode,
  ),
  WireNameDecoderFamily(
    typeName: 'hardware_key_kind',
    choices: HardwareKeyKind.values,
    nodeNames: nodeHardwareKeyKinds,
    decode: HardwareKeyKind.decode,
  ),
  WireNameDecoderFamily(
    typeName: 'runner_link',
    choices: RunnerLink.values,
    nodeNames: nodeRunnerLinks,
    decode: RunnerLink.decode,
  ),
];

void main() {
  for (int index = 0; index < _families.length; index += 1) {
    final WireNameDecoderFamily family = _families[index];
    final int seed = _firstSeed + index * _seedsPerFamily;

    testDecodeReadsEveryNodeName(family);
    testDecodeRejectsNearMissNames(family, seed);
    testDecodeRejectsAnythingButANodeName(family, seed + 1);
  }
}
