import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/random_catalog_json.dart';
import '../support/wire_json_edits.dart';

const String _passedEnvironmentField = 'passed_environment';
const Set<String> _nodeRunnerFields = <String>{
  'labels',
  'slot_capacity',
  'sandbox',
  'clone_url_template',
  'passed_environment',
};
const Set<String> _nodeContainerSandboxFields = <String>{
  'kind',
  'engine',
  'image',
  'allowed_hosts',
};
const List<String> _nodeSandboxKinds = <String>['local_process', 'container'];
const String _sampleDataDirectory = 'data/node';
const List<String> _sampleVariableNames = <String>[
  'CLAUDE_CODE_OAUTH_TOKEN',
  'ANTHROPIC_API_KEY',
  'HTTPS_PROXY',
  'Ünïcødé_NAME',
  '',
  ' ',
];
const List<Object?> _nonTextElements = <Object?>[
  null,
  true,
  7,
  2.5,
  <Object?>['HOME'],
  <String, Object?>{'name': 'HOME'},
];
const List<Object?> _nonListFields = <Object?>[
  null,
  true,
  7,
  'HOME',
  <String, Object?>{'name': 'HOME'},
];

List<String> _randomVariableNames(Random random) {
  final List<String> names = <String>[];
  final int count = random.nextInt(6);
  for (int i = 0; i < count; i += 1) {
    if (random.nextBool()) {
      names.add(pickOne(random, _sampleVariableNames));
    } else {
      names.add(randomText(random));
    }
  }
  return names;
}

RunnerSettings _buildRunnerPassing(Random random, List<String> names) {
  final RunnerSettings decoded = RunnerSettings.fromJson(
    randomRunnerSettingsJson(random),
  );
  return RunnerSettings(
    labels: decoded.labels,
    slotCapacity: decoded.slotCapacity,
    sandbox: decoded.sandbox,
    cloneUrlTemplate: decoded.cloneUrlTemplate,
    passedEnvironment: names,
  );
}

List<String> _readPassedEnvironment(RunnerSettings settings) {
  return settings.passedEnvironment;
}

JsonObject _runnerJsonWith(Random random, Object? passedEnvironment) {
  return replaceWireField(
    randomRunnerSettingsJson(random),
    _passedEnvironmentField,
    passedEnvironment,
  );
}

void main() {
  test('test_runner_settings_to_json_property_node_fields', () {
    final Random random = seededRandom(5203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = _randomVariableNames(random);
      final SandboxSettings sandbox = SandboxSettings.fromJson(
        randomSandboxSettingsJson(random),
      );
      final RunnerSettings runner = RunnerSettings(
        labels: labels,
        slotCapacity: randomCount(random),
        sandbox: sandbox,
        cloneUrlTemplate: null,
        passedEnvironment: _randomVariableNames(random),
      );
      final JsonObject encoded = runner.toJson();
      final JsonObject sandboxJson = decodeObject(encoded['sandbox']);

      expect(encoded.keys.toSet(), equals(_nodeRunnerFields));
      expect(encoded['labels'], equals(labels));
      expect(_nodeSandboxKinds, contains(sandboxJson['kind']));
      if (sandbox is ContainerSandbox) {
        expect(nodeContainerEngines, contains(sandboxJson['engine']));
        expect(sandboxJson.keys.toSet(), _nodeContainerSandboxFields);
      }
    }
  });

  test('test_runner_settings_from_json_property_keeps_passed_environment', () {
    final Random random = seededRandom(73101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _randomVariableNames(random);

      final RunnerSettings settings = RunnerSettings.fromJson(
        _runnerJsonWith(random, names),
      );

      expect(settings.passedEnvironment, orderedEquals(names));
    }
  });

  test('test_runner_settings_from_json_property_'
      'missing_passed_environment_passes_nothing', () {
    final Random random = seededRandom(73102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject olderNodeJson = removeWireField(
        randomRunnerSettingsJson(random),
        _passedEnvironmentField,
      );

      final RunnerSettings settings = RunnerSettings.fromJson(olderNodeJson);

      expect(settings.passedEnvironment, isEmpty);
      expect(settings.toJson()[_passedEnvironmentField], isEmpty);
    }
  });

  test('test_runner_settings_from_json_property_'
      'rejects_passed_environment_that_is_not_names', () {
    final Random random = seededRandom(73103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> brokenNames = <Object?>[
        ..._randomVariableNames(random),
      ];
      brokenNames.insert(
        random.nextInt(brokenNames.length + 1),
        pickOne(random, _nonTextElements),
      );
      final JsonObject brokenElementJson = _runnerJsonWith(
        random,
        brokenNames,
      );
      final JsonObject brokenFieldJson = _runnerJsonWith(
        random,
        pickOne(random, _nonListFields),
      );

      expect(
        () => RunnerSettings.fromJson(brokenElementJson),
        throwsFormatException,
      );
      expect(
        () => RunnerSettings.fromJson(brokenFieldJson),
        throwsFormatException,
      );
    }
  });

  test('test_runner_settings_to_json_property_'
      'round_trips_passed_environment_through_json_text', () {
    final Random random = seededRandom(73104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _randomVariableNames(random);
      final RunnerSettings settings = _buildRunnerPassing(random, names);

      final String encodedText = jsonEncode(settings.toJson());
      final RunnerSettings decoded = RunnerSettings.fromJson(
        jsonDecode(encodedText),
      );

      expect(decoded.passedEnvironment, orderedEquals(names));
      expect(decoded.toJson(), equals(settings.toJson()));
    }
  });

  test('test_runner_settings_to_json_property_'
      'resent_settings_keep_the_node_passed_environment', () {
    final Random random = seededRandom(73105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _randomVariableNames(random);
      final RunnerSettings fromNode = RunnerSettings.fromJson(
        _runnerJsonWith(random, names),
      );

      final NodeStartConfiguration configuration = NodeStartConfiguration(
        dataDirectory: _sampleDataDirectory,
        identityStore: const FileIdentityStore(),
        runner: fromNode,
        peerRelay: pickOne(random, PeerRelayChoice.values),
      );
      final JsonObject sentConfiguration = decodeObject(
        jsonDecode(jsonEncode(configuration.toJson())),
      );
      final JsonObject sentRunner = decodeObject(sentConfiguration['runner']);

      expect(sentRunner[_passedEnvironmentField], orderedEquals(names));
    }
  });

  test('test_status_view_from_json_property_'
      'keeps_runner_passed_environment', () {
    final Random random = seededRandom(73106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _randomVariableNames(random);
      final JsonObject statusJson = replaceWireField(
        randomStatusViewJson(random),
        'runner_settings',
        _runnerJsonWith(random, names),
      );

      final StatusView status = StatusView.fromJson(statusJson);
      final JsonObject reencoded = decodeObject(reencodeAsJsonText(status));
      final JsonObject runnerJson = decodeObject(reencoded['runner_settings']);

      expect(status.runnerSettings?.passedEnvironment, orderedEquals(names));
      expect(runnerJson[_passedEnvironmentField], orderedEquals(names));
    }
  });

  test('test_runners_view_from_json_property_'
      'keeps_this_device_passed_environment', () {
    final Random random = seededRandom(73107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _randomVariableNames(random);
      final JsonObject runnersJson = replaceWireField(
        randomRunnersViewJson(random),
        'this_device_settings',
        _runnerJsonWith(random, names),
      );

      final RunnersView runners = RunnersView.fromJson(runnersJson);
      final RunnerSettings? settings = runners.thisDeviceSettings;

      expect(settings?.passedEnvironment, orderedEquals(names));
      expect(reencodeAsJsonText(runners), equals(runnersJson));
    }
  });

  testListCopyProperties(
    const ListCopy<RunnerSettings, String>(
      testNamePrefix:
          'test_runner_settings_constructor_property_passed_environment',
      seed: 73110,
      buildElement: randomText,
      construct: _buildRunnerPassing,
      readList: _readPassedEnvironment,
    ),
  );
}
