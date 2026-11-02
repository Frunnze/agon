import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/node_json_primitives.dart';
import '../support/scripted_node_transport.dart';

const List<String> _nodePlainIdentityStores = <String>['keychain', 'file'];
const List<String> _nodePeerRelays = <String>['default', 'disabled'];
const String _hexadecimalDigits = '0123456789abcdef';
const int _identityKeyLength = 64;
const List<String> _nodeContainerEngines = <String>['docker', 'podman'];
const List<String> _blankTexts = <String>['', ' ', '\t', '\n  '];
const Set<String> _nodeConfigurationFields = <String>{
  'data_directory',
  'identity_store',
  'runner',
  'peer_relay',
};
const Set<String> _nodeRunnerFields = <String>{
  'labels',
  'slot_capacity',
  'sandbox',
  'clone_url_template',
};

List<String> _randomLabels(Random random) {
  final List<String> labels = <String>[];
  for (final Object? label in randomTexts(random)) {
    labels.add(label! as String);
  }
  return labels;
}

SandboxSettings _randomSandbox(Random random) {
  if (random.nextBool()) {
    return const LocalProcessSandbox();
  }
  return ContainerSandbox(
    engine: pickOne(random, ContainerEngineChoice.values),
    image: randomText(random),
    allowedHosts: _randomLabels(random),
  );
}

RunnerChoice _randomRunner(Random random) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    return const DetectedRunnerSettings();
  }
  if (choice == 1) {
    return const NoRunner();
  }
  return RunnerSettings(
    labels: _randomLabels(random),
    slotCapacity: randomCount(random),
    sandbox: _randomSandbox(random),
    cloneUrlTemplate: randomOptional(random, randomText) as String?,
  );
}

String _randomIdentityKey(Random random, int length) {
  final StringBuffer key = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    key.write(_hexadecimalDigits[random.nextInt(_hexadecimalDigits.length)]);
  }
  return key.toString();
}

IdentityStoreSettings _randomIdentityStore(Random random) {
  final List<IdentityStoreSettings> stores = <IdentityStoreSettings>[
    const KeychainIdentityStore(),
    const FileIdentityStore(),
    EncryptedFileIdentityStore(
      key: _randomIdentityKey(random, _identityKeyLength),
    ),
  ];
  return pickOne(random, stores);
}

NodeStartConfiguration _randomConfiguration(Random random) {
  return NodeStartConfiguration(
    dataDirectory: '/data/${randomText(random)}',
    identityStore: _randomIdentityStore(random),
    runner: _randomRunner(random),
    peerRelay: pickOne(random, PeerRelayChoice.values),
  );
}

void _expectNodeRunner(Object? encoded, RunnerChoice runner) {
  switch (runner) {
    case DetectedRunnerSettings():
      expect(encoded, isNull);
    case NoRunner():
      expect(encoded, 'off');
    case RunnerSettings():
      expect(encoded, runner.toJson());
  }
}

void _expectNodeIdentityStore(Object? encoded, IdentityStoreSettings store) {
  if (store is EncryptedFileIdentityStore) {
    expect(encoded, <String, Object?>{
      'encrypted_file': <String, Object?>{'key': store.key},
    });
    return;
  }
  expect(_nodePlainIdentityStores, contains(encoded));
}

void main() {
  test('test_node_start_configuration_to_json_property_node_fields', () {
    final Random random = seededRandom(5201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeStartConfiguration configuration = _randomConfiguration(
        random,
      );
      final JsonObject encoded = configuration.toJson();

      expect(encoded.keys.toSet(), equals(_nodeConfigurationFields));
      expect(encoded['data_directory'], configuration.dataDirectory);
      _expectNodeIdentityStore(
        encoded['identity_store'],
        configuration.identityStore,
      );
      expect(_nodePeerRelays, contains(encoded['peer_relay']));
      _expectNodeRunner(encoded['runner'], configuration.runner);
      expect(jsonDecode(jsonEncode(encoded)), equals(encoded));
    }
  });

  test('test_node_start_configuration_property_rejects_blank_folder', () {
    final Random random = seededRandom(5202);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => NodeStartConfiguration(
          dataDirectory: pickOne(random, _blankTexts),
          identityStore: _randomIdentityStore(random),
          runner: _randomRunner(random),
          peerRelay: pickOne(random, PeerRelayChoice.values),
        ),
        throwsArgumentError,
      );
    }
  });

  test('test_encrypted_file_identity_store_property_needs_64_hex', () {
    final Random random = seededRandom(5209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = random.nextInt(_identityKeyLength * 2);
      final String key = _randomIdentityKey(random, length);
      if (length == _identityKeyLength) {
        expect(EncryptedFileIdentityStore(key: key).key, key);
        continue;
      }
      expect(() => EncryptedFileIdentityStore(key: key), throwsArgumentError);
    }
    expect(
      () => EncryptedFileIdentityStore(key: 'G' * _identityKeyLength),
      throwsArgumentError,
    );
  });

  test('test_runner_settings_to_json_property_node_fields', () {
    final Random random = seededRandom(5203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = _randomLabels(random);
      final SandboxSettings sandbox = _randomSandbox(random);
      final RunnerSettings runner = RunnerSettings(
        labels: labels,
        slotCapacity: randomCount(random),
        sandbox: sandbox,
        cloneUrlTemplate: null,
      );
      final JsonObject encoded = runner.toJson();
      final JsonObject sandboxJson = decodeObject(encoded['sandbox']);

      expect(encoded.keys.toSet(), equals(_nodeRunnerFields));
      expect(encoded['labels'], equals(labels));
      expect(<String>[
        'local_process',
        'container',
      ], contains(sandboxJson['kind']));
      if (sandbox is ContainerSandbox) {
        expect(_nodeContainerEngines, contains(sandboxJson['engine']));
        expect(sandboxJson.keys.toSet(), <String>{
          'kind',
          'engine',
          'image',
          'allowed_hosts',
        });
      }
    }
  });

  test('test_start_node_property_sends_configuration_to_start', () async {
    final Random random = seededRandom(5204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeStartConfiguration configuration = _randomConfiguration(
        random,
      );
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeSuccessReply(null),
      );

      await startNode(transport: transport, configuration: configuration);

      expect(transport.exchanges.single.entryPoint, NodeEntryPoint.start);
      expect(
        jsonDecode(transport.exchanges.single.inputJson),
        equals(configuration.toJson()),
      );
    }
  });

  test('test_start_node_property_raises_the_node_refusal', () async {
    final Random random = seededRandom(5205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeErrorReply(message),
      );

      await expectLater(
        startNode(
          transport: transport,
          configuration: _randomConfiguration(random),
        ),
        throwsA(isA<NodeCommandFailure>()),
      );
    }
  });

  test('test_stop_node_property_asks_the_node_to_stop_once', () async {
    final ScriptedNodeTransport transport = ScriptedNodeTransport(
      answer: (String inputJson) => encodeSuccessReply(null),
    );

    await stopNode(transport);

    expect(transport.stopRequests, 1);
    expect(transport.exchanges, isEmpty);
  });

  test('test_stop_node_property_rejects_unexpected_ok_values', () async {
    final Random random = seededRandom(5208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? okValue = randomArbitraryJson(random);
      if (okValue == null) {
        continue;
      }
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeSuccessReply(okValue),
      );

      await expectLater(stopNode(transport), throwsFormatException);
    }
  });

  test('test_stop_node_property_raises_the_node_refusal', () async {
    final Random random = seededRandom(5207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: (String inputJson) => encodeErrorReply(message),
      );

      await expectLater(
        stopNode(transport),
        throwsA(
          isA<NodeCommandFailure>().having(
            (NodeCommandFailure failure) => failure.message,
            'message',
            message,
          ),
        ),
      );
    }
  });
}
