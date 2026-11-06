import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/decoding_outcome.dart';
import '../support/hostile_texts.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/random_item_drafts.dart';
import '../support/random_typed_values.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_decoder_properties.dart';

const WireNameDecoderFamily _draftKindFamily = WireNameDecoderFamily(
  typeName: 'draft_kind',
  choices: DraftKind.values,
  nodeNames: nodeDraftKinds,
  decode: DraftKind.decode,
);

const String _kindField = 'kind';

const List<String> _kindsTheAppDoesNotDraft = <String>[
  'project',
  'Task',
  'jobs',
  'work',
  '',
];

WorkItemDraft _copyWorkDraftWithSkills(
  WorkItemDraft draft,
  List<SkillId> skills,
) {
  return WorkItemDraft(
    kind: draft.kind,
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
    schedule: draft.schedule,
  );
}

Object? _randomKindTheAppDoesNotDraft(Random random) {
  final Object? arbitraryKind = randomArbitraryJson(random);
  if (nodeDraftKinds.contains(arbitraryKind)) {
    return pickOne(random, _kindsTheAppDoesNotDraft);
  }
  if (random.nextBool()) {
    return pickOne(random, _kindsTheAppDoesNotDraft);
  }
  return arbitraryKind;
}

void main() {
  testDecodeReadsEveryNodeName(_draftKindFamily);
  testDecodeRejectsNearMissNames(_draftKindFamily, 50701);
  testDecodeRejectsAnythingButANodeName(_draftKindFamily, 50702);

  test('test_item_draft_from_json_property_kind_picks_the_variant', () {
    final Random random = seededRandom(50703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftJson(random);

      final ItemDraft draft = ItemDraft.fromJson(json);

      switch (json[_kindField]) {
        case 'task' || 'job':
          final WorkItemDraft workDraft = draft as WorkItemDraft;
          expect(workDraft.kind.wireName, json[_kindField]);
        case 'skill':
          expect(draft, isA<SkillItemDraft>());
        case 'rule':
          expect(draft, isA<RuleItemDraft>());
        default:
          fail('the generator made an unknown kind ${json[_kindField]}');
      }
    }
  });

  test('test_item_draft_from_json_property_round_trips_node_json', () {
    final Random random = seededRandom(50704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftJson(random);

      final String jsonText = jsonEncode(ItemDraft.fromJson(json).toJson());

      expect(jsonDecode(jsonText), equals(json));
    }
  });

  test('test_item_draft_from_json_property_rejects_unknown_kinds', () {
    final Random random = seededRandom(50705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftJson(random);
      final JsonObject withoutKind = Map<String, Object?>.of(json);
      withoutKind.remove(_kindField);
      json[_kindField] = _randomKindTheAppDoesNotDraft(random);

      expect(() => ItemDraft.fromJson(json), throwsFormatException);
      expect(() => ItemDraft.fromJson(withoutKind), throwsFormatException);
    }
  });

  test('test_work_item_draft_constructor_property_keeps_its_own_copy', () {
    final Random random = seededRandom(50706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft template = randomWorkItemDraft(random);
      final List<SkillId> skills = List<SkillId>.of(template.skills);

      final WorkItemDraft draft = _copyWorkDraftWithSkills(template, skills);

      expectListIgnoresCallerChanges(
        skills,
        draft.skills,
        SkillId(randomHostileText(random)),
      );
    }
  });

  test('test_work_item_draft_constructor_property_skills_reject_changes', () {
    final Random random = seededRandom(50707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft draft = randomWorkItemDraft(random);

      expectListRefusesChanges(draft.skills, SkillId(randomText(random)));
    }
  });

  test('test_work_item_draft_constructor_property_keeps_skill_order', () {
    final Random random = seededRandom(50708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId repeatedSkill = SkillId(randomHostileText(random));
      final List<SkillId> skills = <SkillId>[
        repeatedSkill,
        ...randomSkillIds(random),
        repeatedSkill,
      ];

      final WorkItemDraft draft = _copyWorkDraftWithSkills(
        randomWorkItemDraft(random),
        skills,
      );

      expect(draft.skills, orderedEquals(skills));
    }
  });

  test('test_item_draft_from_json_property_malformed_json_raises_format', () {
    final Random random = seededRandom(50709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? mutatedJson = mutateJson(
        random,
        randomItemDraftJson(random),
      );

      expect(
        attemptDecoding(() => ItemDraft.fromJson(mutatedJson)),
        isIn(DecodingOutcome.values),
      );
    }
  });
}
