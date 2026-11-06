import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_decoder_properties.dart';

const String _policyField = 'approval_policy';
const String _protectedFilesField = 'protected_files';
const String _patternsField = 'patterns';
const int _unknownFieldSuffixSpan = 1 << 31;

const Set<String> _requiredWorkspaceFields = <String>{
  'id',
  'name',
  'app_server_address',
  _protectedFilesField,
};

const Set<String> _everyWorkspaceField = <String>{
  ..._requiredWorkspaceFields,
  _policyField,
};

const WireNameDecoderFamily _agentAccessFamily = WireNameDecoderFamily(
  typeName: 'agent_access',
  choices: AgentAccess.values,
  nodeNames: nodeAgentAccesses,
  decode: AgentAccess.decode,
);

const WireCodec _repositoryCodec = WireCodec(
  typeName: 'repository',
  seed: 54000,
  buildJson: randomRepositoryJson,
  decode: Repository.fromJson,
  requiredFields: <String>{'address', 'default_branch', 'agent_access'},
  optionalFields: <String>{},
);

Workspace _buildWorkspaceWithPatterns(Random random, List<String> patterns) {
  final Workspace template = Workspace.fromJson(randomWorkspaceJson(random));
  return Workspace(
    id: template.id,
    name: template.name,
    appServerAddress: template.appServerAddress,
    protectedFiles: patterns,
    approvalPolicy: template.approvalPolicy,
  );
}

List<String> _readPatterns(Workspace workspace) => workspace.protectedFiles;

JsonObject _withPatternsHolder(Random random, Object? holder) {
  return replaceWireField(
    randomWorkspaceJson(random),
    _protectedFilesField,
    holder,
  );
}

void main() {
  testDecodeReadsEveryNodeName(_agentAccessFamily);
  testDecodeRejectsNearMissNames(_agentAccessFamily, 54010);
  testDecodeRejectsAnythingButANodeName(_agentAccessFamily, 54011);

  testWireDecodingProperties(_repositoryCodec);
  testWireEncodingProperties(_repositoryCodec);

  testListCopyProperties(
    const ListCopy<Workspace, String>(
      testNamePrefix: 'test_workspace_constructor_property_protected_files',
      seed: 54020,
      buildElement: randomHostileText,
      construct: _buildWorkspaceWithPatterns,
      readList: _readPatterns,
    ),
  );

  test('test_workspace_from_json_property_needs_every_required_field', () {
    final Random random = seededRandom(54030);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkspaceJson(random);
      expect(wireJson.keys.toSet(), equals(_everyWorkspaceField));

      for (final String field in _requiredWorkspaceFields) {
        final JsonObject shortenedJson = removeWireField(wireJson, field);
        final JsonObject nulledJson = replaceWireField(wireJson, field, null);

        expect(() => Workspace.fromJson(shortenedJson), throwsFormatException);
        expect(() => Workspace.fromJson(nulledJson), throwsFormatException);
      }
    }
  });

  test('test_workspace_from_json_property_ignores_unknown_fields', () {
    final Random random = seededRandom(54031);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkspaceJson(random);
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final Workspace workspace = Workspace.fromJson(widenedJson);

      expect(reencodeAsJsonText(workspace), equals(wireJson));
    }
  });

  test('test_workspace_from_json_property_rejects_wrongly_typed_fields', () {
    final Random random = seededRandom(54032);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkspaceJson(random);

      expectWrongKindFieldsRejected(random, wireJson, Workspace.fromJson);
    }
  });

  test('test_workspace_to_json_property_is_plain_json_that_decodes_back', () {
    final Random random = seededRandom(54033);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace workspace = _buildWorkspaceWithPatterns(
        random,
        randomHostileTexts(random),
      );
      final JsonObject encoded = workspace.toJson();

      final Workspace decodedAgain = Workspace.fromJson(encoded);

      expect(reencodeAsJsonText(workspace), equals(encoded));
      expect(decodedAgain.toJson(), equals(encoded));
    }
  });

  test('test_workspace_to_json_property_reproduces_the_node_json', () {
    final Random random = seededRandom(54034);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomWorkspaceJson(random);

      final Workspace workspace = Workspace.fromJson(wireJson);

      expect(reencodeAsJsonText(workspace), equals(wireJson));
    }
  });

  test('test_workspace_to_json_property_writes_every_node_field', () {
    final Random random = seededRandom(54035);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject requiredJson = removeWireField(
        randomWorkspaceJson(random),
        _policyField,
      );

      final JsonObject encoded = Workspace.fromJson(requiredJson).toJson();

      expect(encoded.keys.toSet(), equals(_everyWorkspaceField));
      expect(encoded[_policyField], ApprovalPolicy.neverAsk.wireName);
    }
  });

  test('test_decode_protected_patterns_property_keeps_patterns_as_given', () {
    final Random random = seededRandom(54040);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = randomHostileTexts(random);
      if (patterns.isNotEmpty) {
        patterns.add(patterns.first);
      }
      final JsonObject wireJson = _withPatternsHolder(
        random,
        <String, Object?>{_patternsField: patterns},
      );

      final Workspace workspace = Workspace.fromJson(wireJson);

      expect(workspace.protectedFiles, orderedEquals(patterns));
    }
  });

  test('test_decode_protected_patterns_property_'
      'rejects_a_holder_without_a_pattern_list', () {
    final Random random = seededRandom(54041);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = randomHostileTexts(random);
      final Object? arbitraryPatterns = randomArbitraryJson(random);
      final List<Object?> brokenHolders = <Object?>[
        patterns,
        <String, Object?>{},
        <String, Object?>{_patternsField: null},
        <String, Object?>{'pattern': patterns},
        randomHostileText(random),
      ];
      if (arbitraryPatterns is! List<Object?>) {
        brokenHolders.add(<String, Object?>{
          _patternsField: arbitraryPatterns,
        });
      }
      final Object? brokenHolder = pickOne(random, brokenHolders);

      final JsonObject wireJson = _withPatternsHolder(random, brokenHolder);

      expect(() => Workspace.fromJson(wireJson), throwsFormatException);
    }
  });

  test('test_decode_protected_patterns_property_'
      'ignores_unknown_holder_fields', () {
    final Random random = seededRandom(54042);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = randomHostileTexts(random);
      final int unknownSuffix = random.nextInt(_unknownFieldSuffixSpan);
      final String unknownField = 'unknown_$unknownSuffix';
      final JsonObject wireJson = _withPatternsHolder(
        random,
        <String, Object?>{
          _patternsField: patterns,
          unknownField: randomArbitraryJson(random),
        },
      );

      final Workspace workspace = Workspace.fromJson(wireJson);

      expect(workspace.protectedFiles, orderedEquals(patterns));
      final JsonObject encoded = workspace.toJson();
      expect(
        encoded[_protectedFilesField],
        equals(<String, Object?>{_patternsField: patterns}),
      );
    }
  });
}
