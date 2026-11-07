import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/wire_name_properties.dart';

typedef _RunnerChoiceBuilder = RunnerChoice Function(Random random);

const String _sampleDataDirectory = 'data/node';
const String _nodeRunnerOff = 'off';
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

final class _WireNamedFamily {
  const _WireNamedFamily({
    required this.typeName,
    required this.choices,
    required this.nodeNames,
    required this.decode,
  });

  final String typeName;
  final List<WireNamed> choices;
  final List<String> nodeNames;
  final WireNamed Function(Object? json) decode;
}

final class _RunnerChoiceRow {
  const _RunnerChoiceRow({
    required this.typeName,
    required this.build,
    required this.nodeJson,
  });

  final String typeName;
  final _RunnerChoiceBuilder build;
  final Object? nodeJson;
}

const List<_WireNamedFamily> _wireNamedFamilies = <_WireNamedFamily>[
  _WireNamedFamily(
    typeName: 'container_engine_choice',
    choices: ContainerEngineChoice.values,
    nodeNames: nodeContainerEngines,
    decode: ContainerEngineChoice.decode,
  ),
  _WireNamedFamily(
    typeName: 'agent_place',
    choices: AgentPlace.values,
    nodeNames: nodeAgentPlaces,
    decode: AgentPlace.decode,
  ),
];

RunnerChoice _buildDetected(Random random) => const DetectedRunnerSettings();

RunnerChoice _buildNoRunner(Random random) => const NoRunner();

const List<_RunnerChoiceRow> _constantChoiceRows = <_RunnerChoiceRow>[
  _RunnerChoiceRow(
    typeName: 'detected_runner_settings',
    build: _buildDetected,
    nodeJson: null,
  ),
  _RunnerChoiceRow(
    typeName: 'no_runner',
    build: _buildNoRunner,
    nodeJson: _nodeRunnerOff,
  ),
];

RunnerChoice _buildGivenRunner(Random random) {
  return RunnerSettings.fromJson(randomRunnerSettingsJson(random));
}

Object? _sendInStartConfiguration(Random random, RunnerChoice runner) {
  final NodeStartConfiguration configuration = NodeStartConfiguration(
    dataDirectory: _sampleDataDirectory,
    identityStore: const FileIdentityStore(),
    runner: runner,
    peerRelay: pickOne(random, PeerRelayChoice.values),
  );
  final Object? sent = jsonDecode(jsonEncode(configuration.toJson()));
  return decodeObject(sent)['runner'];
}

RunnerSettings _buildRunnerWithLabels(Random random, List<String> labels) {
  final RunnerSettings decoded = RunnerSettings.fromJson(
    randomRunnerSettingsJson(random),
  );
  return RunnerSettings(
    labels: labels,
    slotCapacity: decoded.slotCapacity,
    sandbox: decoded.sandbox,
    cloneUrlTemplate: decoded.cloneUrlTemplate,
    passedEnvironment: decoded.passedEnvironment,
  );
}

List<String> _readLabels(RunnerSettings settings) => settings.labels;

void _testWireNameProperties(_WireNamedFamily family, int seed) {
  testWireNameDecodeProperties(
    WireNameCodec<WireNamed>(
      typeName: family.typeName,
      seed: seed,
      choices: family.choices,
      decode: family.decode,
      nodeNames: family.nodeNames,
    ),
  );

  final String testPrefix = 'test_${family.typeName}_wire_name_property';

  test('${testPrefix}_names_every_node_choice', () {
    final Set<String> wireNames = <String>{};
    for (final WireNamed choice in family.choices) {
      wireNames.add(choice.wireName);
    }

    expect(wireNames, equals(family.nodeNames.toSet()));
  });

  test('${testPrefix}_is_unique_snake_case', () {
    final Set<String> wireNames = <String>{};

    for (final WireNamed choice in family.choices) {
      expect(wireNames.add(choice.wireName), isTrue, reason: '$choice');
      expect(_snakeCaseName.hasMatch(choice.wireName), isTrue);
    }
  });

  test('${testPrefix}_survives_a_json_round_trip', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WireNamed choice = pickOne(random, family.choices);
      final Object? reread = jsonDecode(jsonEncode(choice.wireName));

      expect(identical(family.decode(reread), choice), isTrue);
    }
  });
}

void _testConstantChoice(_RunnerChoiceRow row, int seed) {
  final String constructorPrefix = 'test_${row.typeName}_constructor_property';
  final String toJsonPrefix = 'test_${row.typeName}_to_json_property';

  test('${constructorPrefix}_is_one_value', () {
    final Random random = seededRandom(seed);

    expect(identical(row.build(random), row.build(random)), isTrue);
  });

  test('${constructorPrefix}_is_a_runner_choice', () {
    final Random random = seededRandom(seed + 1);

    expect(row.build(random), isA<RunnerChoice>());
    expect(row.build(random), isA<JsonEncodable>());
  });

  test('${constructorPrefix}_encodes_the_same_every_time', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(row.build(random).toJson(), row.build(random).toJson());
    }
  });

  test('${toJsonPrefix}_is_what_the_node_reads', () {
    final Random random = seededRandom(seed + 3);

    expect(row.build(random).toJson(), row.nodeJson);
  });

  test('${toJsonPrefix}_never_collides_with_another_choice', () {
    final Random random = seededRandom(seed + 4);
    final Object? encoded = row.build(random).toJson();

    for (final _RunnerChoiceRow other in _constantChoiceRows) {
      if (other.typeName != row.typeName) {
        expect(encoded, isNot(other.build(random).toJson()));
      }
    }
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(encoded, isNot(isA<Map<String, Object?>>()));
      expect(_buildGivenRunner(random).toJson(), isNot(encoded));
    }
  });

  test('${toJsonPrefix}_survives_the_start_configuration', () {
    final Random random = seededRandom(seed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerChoice choice = row.build(random);

      expect(_sendInStartConfiguration(random, choice), row.nodeJson);
    }
  });
}

void main() {
  for (int i = 0; i < _wireNamedFamilies.length; i += 1) {
    _testWireNameProperties(_wireNamedFamilies[i], 64301 + i * 10);
  }

  for (int i = 0; i < _constantChoiceRows.length; i += 1) {
    _testConstantChoice(_constantChoiceRows[i], 64401 + i * 10);
  }

  test('test_no_runner_wire_name_property_is_the_node_off_choice', () {
    expect(NoRunner.wireName, _nodeRunnerOff);
    expect(_snakeCaseName.hasMatch(NoRunner.wireName), isTrue);
  });

  test('test_no_runner_wire_name_property_is_what_no_runner_sends', () {
    expect(const NoRunner().toJson(), NoRunner.wireName);
  });

  test('test_no_runner_wire_name_property_survives_json_text', () {
    final Object? reread = jsonDecode(jsonEncode(NoRunner.wireName));

    expect(reread, NoRunner.wireName);
    expect(reread, const NoRunner().toJson());
  });

  testListCopyProperties(
    const ListCopy<RunnerSettings, String>(
      testNamePrefix: 'test_runner_settings_constructor_property_labels',
      seed: 64501,
      buildElement: randomHostileText,
      construct: _buildRunnerWithLabels,
      readList: _readLabels,
    ),
  );
}
