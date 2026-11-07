import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/tagged_wire_union_properties.dart';
import '../support/wire_json_edits.dart';

const String _kindField = 'kind';
const String _localProcessKind = 'local_process';
const String _containerKind = 'container';
const List<String> _nodeSandboxKinds = <String>[
  _localProcessKind,
  _containerKind,
];
const Set<String> _nodeContainerFields = <String>{
  'kind',
  'engine',
  'image',
  'allowed_hosts',
};
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

String _readSandboxKind(JsonEncodable sandbox) {
  return decodeText(decodeObject(sandbox.toJson())[_kindField]);
}

ContainerSandbox _randomContainer(Random random, List<String> allowedHosts) {
  return ContainerSandbox(
    engine: pickOne(random, ContainerEngineChoice.values),
    image: randomHostileText(random),
    allowedHosts: allowedHosts,
  );
}

List<String> _readAllowedHosts(ContainerSandbox sandbox) {
  return sandbox.allowedHosts;
}

void main() {
  testTaggedWireUnionProperties(
    const TaggedWireUnion(
      typeName: 'sandbox_settings',
      seed: 64201,
      tagField: _kindField,
      nodeTags: _nodeSandboxKinds,
      buildJson: randomSandboxSettingsJson,
      decode: SandboxSettings.fromJson,
      readVariantTag: _readSandboxKind,
    ),
  );

  test('test_sandbox_settings_from_json_property_reads_the_container_'
      'fields', () {
    final Random random = seededRandom(64204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = replaceWireField(
        randomSandboxSettingsJson(random),
        _kindField,
        _containerKind,
      );
      final JsonObject containerJson = <String, Object?>{
        ...wireJson,
        'engine': pickOne(random, nodeContainerEngines),
        'image': randomHostileText(random),
        'allowed_hosts': randomHostileTexts(random),
      };

      final SandboxSettings sandbox = SandboxSettings.fromJson(containerJson);

      expect(sandbox, isA<ContainerSandbox>());
      expect(reencodeAsJsonText(sandbox), equals(containerJson));
    }
  });

  test('test_local_process_sandbox_constructor_property_is_one_value', () {
    const LocalProcessSandbox first = LocalProcessSandbox();
    const LocalProcessSandbox second = LocalProcessSandbox();

    expect(identical(first, second), isTrue);
    expect(first.toJson(), equals(second.toJson()));
  });

  test('test_local_process_sandbox_constructor_property_is_a_sandbox', () {
    const Object sandbox = LocalProcessSandbox();

    expect(sandbox, isA<SandboxSettings>());
    expect(sandbox, isA<JsonEncodable>());
  });

  test('test_local_process_sandbox_constructor_property_matches_the_'
      'decoded_value', () {
    final Random random = seededRandom(64205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = addUnknownWireFields(
        random,
        <String, Object?>{_kindField: _localProcessKind},
      );

      final SandboxSettings decoded = SandboxSettings.fromJson(wireJson);

      expect(identical(decoded, const LocalProcessSandbox()), isTrue);
    }
  });

  test('test_local_process_sandbox_kind_property_is_the_node_kind', () {
    expect(LocalProcessSandbox.kind, _localProcessKind);
    expect(_snakeCaseName.hasMatch(LocalProcessSandbox.kind), isTrue);
  });

  test('test_local_process_sandbox_kind_property_differs_from_every_'
      'other_kind', () {
    expect(LocalProcessSandbox.kind, isNot(ContainerSandbox.kind));
    expect(_nodeSandboxKinds, contains(LocalProcessSandbox.kind));
  });

  test('test_local_process_sandbox_kind_property_picks_the_variant', () {
    final Object? rereadJson = reencodeAsJsonText(const LocalProcessSandbox());

    expect(decodeObject(rereadJson)[_kindField], LocalProcessSandbox.kind);
    expect(SandboxSettings.fromJson(rereadJson), isA<LocalProcessSandbox>());
  });

  test('test_local_process_sandbox_to_json_property_writes_only_the_'
      'kind', () {
    expect(
      const LocalProcessSandbox().toJson(),
      equals(<String, Object?>{_kindField: _localProcessKind}),
    );
  });

  test('test_local_process_sandbox_to_json_property_is_fresh_on_every_'
      'read', () {
    final Random random = seededRandom(64206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject firstRead = const LocalProcessSandbox().toJson();
      firstRead[randomText(random)] = randomText(random);
      firstRead.remove(_kindField);

      expect(
        const LocalProcessSandbox().toJson(),
        equals(<String, Object?>{_kindField: _localProcessKind}),
      );
    }
  });

  test('test_local_process_sandbox_to_json_property_survives_json_text', () {
    final Object? rereadJson = reencodeAsJsonText(const LocalProcessSandbox());

    expect(rereadJson, equals(const LocalProcessSandbox().toJson()));
  });

  testListCopyProperties(
    const ListCopy<ContainerSandbox, String>(
      testNamePrefix:
          'test_container_sandbox_constructor_property_allowed_hosts',
      seed: 64207,
      buildElement: randomHostileText,
      construct: _randomContainer,
      readList: _readAllowedHosts,
    ),
  );

  test('test_container_sandbox_kind_property_is_the_node_kind', () {
    expect(ContainerSandbox.kind, _containerKind);
    expect(_snakeCaseName.hasMatch(ContainerSandbox.kind), isTrue);
  });

  test('test_container_sandbox_kind_property_differs_from_every_'
      'other_kind', () {
    expect(ContainerSandbox.kind, isNot(LocalProcessSandbox.kind));
    expect(_nodeSandboxKinds, contains(ContainerSandbox.kind));
  });

  test('test_container_sandbox_kind_property_picks_the_variant', () {
    final Random random = seededRandom(64210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ContainerSandbox sandbox = _randomContainer(
        random,
        randomHostileTexts(random),
      );
      final Object? rereadJson = reencodeAsJsonText(sandbox);

      expect(decodeObject(rereadJson)[_kindField], ContainerSandbox.kind);
      expect(SandboxSettings.fromJson(rereadJson), isA<ContainerSandbox>());
    }
  });

  test('test_container_sandbox_to_json_property_writes_exactly_the_node_'
      'fields', () {
    final Random random = seededRandom(64211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> allowedHosts = randomHostileTexts(random);
      final ContainerSandbox sandbox = _randomContainer(random, allowedHosts);

      final JsonObject encoded = sandbox.toJson();

      expect(encoded.keys.toSet(), equals(_nodeContainerFields));
      expect(encoded['engine'], sandbox.engine.wireName);
      expect(nodeContainerEngines, contains(encoded['engine']));
      expect(encoded['image'], sandbox.image);
      expect(encoded['allowed_hosts'], orderedEquals(allowedHosts));
    }
  });

  test('test_container_sandbox_to_json_property_round_trips', () {
    final Random random = seededRandom(64212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ContainerSandbox sandbox = _randomContainer(
        random,
        randomHostileTexts(random),
      );

      final SandboxSettings decoded = SandboxSettings.fromJson(
        reencodeAsJsonText(sandbox),
      );

      expect(decoded, isA<ContainerSandbox>());
      expect(decoded.toJson(), equals(sandbox.toJson()));
    }
  });

  test('test_container_sandbox_to_json_property_is_fresh_on_every_'
      'read', () {
    final Random random = seededRandom(64213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ContainerSandbox sandbox = _randomContainer(
        random,
        randomHostileTexts(random),
      );
      final JsonObject expected = sandbox.toJson();
      final JsonObject firstRead = sandbox.toJson();

      firstRead.remove(pickOne(random, firstRead.keys.toList()));
      firstRead[randomText(random)] = randomText(random);

      expect(sandbox.toJson(), equals(expected));
    }
  });
}
