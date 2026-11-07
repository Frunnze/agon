import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../../support/random_inputs.dart';
import '../../support/random_account_json.dart';

const String lowercaseHexadecimalDigits = '0123456789abcdef';

String randomIdentityKeyOfLength(Random random, int length) {
  final StringBuffer key = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    key.write(pickOne(random, lowercaseHexadecimalDigits.split('')));
  }
  return key.toString();
}

IdentityStoreSettings randomIdentityStore(Random random) {
  final List<IdentityStoreSettings> stores = <IdentityStoreSettings>[
    const KeychainIdentityStore(),
    const FileIdentityStore(),
    EncryptedFileIdentityStore(
      key: randomIdentityKeyOfLength(random, identityKeyHexadecimalLength),
    ),
  ];
  return pickOne(random, stores);
}

RunnerChoice randomRunnerChoice(Random random) {
  final List<RunnerChoice> runners = <RunnerChoice>[
    const DetectedRunnerSettings(),
    const NoRunner(),
    RunnerSettings.fromJson(randomRunnerSettingsJson(random)),
  ];
  return pickOne(random, runners);
}

String randomDataDirectory(Random random) {
  return '<home>/${randomText(random)}/node';
}

int? randomOptionalPort(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return random.nextInt(largestAppServerPort + 1);
}

NodeStartConfiguration randomStartConfiguration(Random random) {
  return NodeStartConfiguration(
    dataDirectory: randomDataDirectory(random),
    identityStore: randomIdentityStore(random),
    runner: randomRunnerChoice(random),
    peerRelay: pickOne(random, PeerRelayChoice.values),
    appServerPort: randomOptionalPort(random),
  );
}
