import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/random_typed_values.dart';
import '../support/tagged_wire_union_properties.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';

const String _kindField = 'kind';
const String _runIdField = 'run_id';

const List<WireCodec> _skillChangeCodecs = <WireCodec>[
  WireCodec(
    typeName: 'person_edit',
    seed: 53100,
    buildJson: _buildPersonEditJson,
    decode: SkillChangeOrigin.fromJson,
    requiredFields: <String>{_kindField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'approved_agent_run',
    seed: 53110,
    buildJson: _buildApprovedAgentRunJson,
    decode: SkillChangeOrigin.fromJson,
    requiredFields: <String>{_kindField, _runIdField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'automatic_agent_run',
    seed: 53120,
    buildJson: _buildAutomaticAgentRunJson,
    decode: SkillChangeOrigin.fromJson,
    requiredFields: <String>{_kindField, _runIdField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'skill_change',
    seed: 53130,
    buildJson: randomSkillChangeJson,
    decode: SkillChange.fromJson,
    requiredFields: <String>{'origin', 'saved_at', 'replaced_instructions'},
    optionalFields: <String>{},
  ),
];

JsonObject _buildPersonEditJson(Random random) {
  return <String, Object?>{_kindField: PersonEdit.kind};
}

JsonObject _buildApprovedAgentRunJson(Random random) {
  return <String, Object?>{
    _kindField: ApprovedAgentRun.kind,
    _runIdField: randomUuidText(random),
  };
}

JsonObject _buildAutomaticAgentRunJson(Random random) {
  return <String, Object?>{
    _kindField: AutomaticAgentRun.kind,
    _runIdField: randomUuidText(random),
  };
}

String _readOriginKind(JsonEncodable origin) {
  return switch (origin) {
    PersonEdit() => 'person_edit',
    ApprovedAgentRun() => 'approved_agent_run',
    AutomaticAgentRun() => 'automatic_agent_run',
    _ => throw StateError('not a skill change origin: $origin'),
  };
}

SkillChangeOrigin _buildOrigin(Random random) {
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(runId: randomRunId(random)),
    AutomaticAgentRun(runId: randomRunId(random)),
  ]);
}

void main() {
  for (final WireCodec codec in _skillChangeCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testTaggedWireUnionProperties(
    const TaggedWireUnion(
      typeName: 'skill_change_origin',
      seed: 53140,
      tagField: _kindField,
      nodeTags: nodeSkillChangeOrigins,
      buildJson: randomSkillChangeOriginJson,
      decode: SkillChangeOrigin.fromJson,
      readVariantTag: _readOriginKind,
    ),
  );

  test('test_skill_change_origin_from_json_property_'
      'person_edit_drops_a_stray_run_id', () {
    final Random random = seededRandom(53150);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject strayRunJson = <String, Object?>{
        _kindField: PersonEdit.kind,
        _runIdField: randomUuidText(random),
      };

      final SkillChangeOrigin origin = SkillChangeOrigin.fromJson(
        strayRunJson,
      );

      expect(origin, isA<PersonEdit>());
      expect(origin.toJson(), equals(_buildPersonEditJson(random)));
    }
  });

  test('test_skill_change_origin_from_json_property_'
      'agent_runs_keep_the_run_id', () {
    final Random random = seededRandom(53151);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillChangeOrigin original = _buildOrigin(random);

      final SkillChangeOrigin decoded = SkillChangeOrigin.fromJson(
        reencodeAsJsonText(original),
      );

      expect(_readOriginKind(decoded), _readOriginKind(original));
      final JsonObject originalJson = decodeObject(original.toJson());
      final JsonObject decodedJson = decodeObject(decoded.toJson());
      expect(decodedJson[_runIdField], originalJson[_runIdField]);
    }
  });

  test('test_skill_change_to_json_property_writes_saved_at_as_utc_text', () {
    final Random random = seededRandom(53152);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime savedAt = randomMicrosecondMoment(random);
      final SkillChange change = SkillChange(
        origin: _buildOrigin(random),
        savedAt: savedAt,
        replacedInstructions: randomHostileText(random),
      );

      expectUtcMomentText(change.toJson()['saved_at'], savedAt);
    }
  });

  test('test_skill_change_from_json_property_'
      'keeps_hostile_instructions_and_offset_moments', () {
    final Random random = seededRandom(53153);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String instructions = randomHostileText(random);
      final DateTime savedAt = randomMicrosecondMoment(random).toUtc();
      final JsonObject wireJson = <String, Object?>{
        ...randomSkillChangeJson(random),
        'saved_at': writeMomentAtRandomOffset(random, savedAt),
        'replaced_instructions': instructions,
      };

      final SkillChange change = SkillChange.fromJson(wireJson);

      expect(change.replacedInstructions, instructions);
      expect(change.savedAt, equals(savedAt));
    }
  });
}
