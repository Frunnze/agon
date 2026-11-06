import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/node_wire_names.dart';
import '../support/random_item_drafts.dart';

const Set<String> _nodeWorkDraftFields = <String>{
  'kind',
  'title',
  'details',
  'project_id',
  'doer',
  'runs_on',
  'agent_place',
  'skills',
  'uses_automatic_skills',
  'approval_policy',
  'schedule',
};

const List<String> _workKindNames = <String>['task', 'job'];

const List<String?> _nodeApprovalPoliciesOrNone = <String?>[
  null,
  ...nodeApprovalPolicies,
];

const Set<String> _optionalWorkDraftFields = <String>{
  'project_id',
  'approval_policy',
  'schedule',
};

JsonObject _randomWorkDraftJson(Random random) {
  JsonObject json = randomItemDraftJson(random);
  while (!_workKindNames.contains(json['kind'])) {
    json = randomItemDraftJson(random);
  }
  json['title'] = randomHostileText(random);
  json['details'] = randomHostileText(random);
  return json;
}

void _expectSameWorkDraft(WorkItemDraft actual, WorkItemDraft expected) {
  expect(actual.kind, same(expected.kind));
  expect(actual.title, expected.title);
  expect(actual.details, expected.details);
  expect(actual.projectId, expected.projectId);
  expect(actual.doer.toJson(), equals(expected.doer.toJson()));
  expect(actual.runsOn.toJson(), equals(expected.runsOn.toJson()));
  expect(actual.agentPlace, same(expected.agentPlace));
  expect(actual.skills, orderedEquals(expected.skills));
  expect(actual.usesAutomaticSkills, expected.usesAutomaticSkills);
  expect(actual.approvalPolicy, expected.approvalPolicy);
  expect(actual.schedule?.toJson(), expected.schedule?.toJson());
}

void main() {
  test('test_work_item_draft_from_fields_property_keeps_node_values', () {
    final Random random = seededRandom(50801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomWorkDraftJson(random);
      final DraftKind kind = DraftKind.decode(json['kind']);

      final WorkItemDraft draft = WorkItemDraft.fromFields(kind, json);

      expect(draft.title, json['title']);
      expect(draft.details, json['details']);
      expect(draft.projectId, json['project_id']);
      expect(draft.doer.toJson(), equals(json['doer']));
      expect(draft.runsOn.toJson(), equals(json['runs_on']));
      expect(draft.agentPlace.wireName, json['agent_place']);
      expect(draft.skills, orderedEquals(json['skills']! as List<Object?>));
      expect(draft.usesAutomaticSkills, json['uses_automatic_skills']);
      expect(draft.approvalPolicy?.wireName, json['approval_policy']);
      expect(draft.schedule?.toJson(), equals(json['schedule']));
    }
  });

  test('test_work_item_draft_from_fields_property_only_options_may_go', () {
    final Random random = seededRandom(50802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomWorkDraftJson(random);
      final DraftKind kind = DraftKind.decode(json['kind']);
      final String missingField = pickOne(random, json.keys.toList());
      json.remove(missingField);

      if (missingField == 'kind') {
        expect(WorkItemDraft.fromFields(kind, json).kind, same(kind));
      } else if (_optionalWorkDraftFields.contains(missingField)) {
        final JsonObject encoded = WorkItemDraft.fromFields(
          kind,
          json,
        ).toJson();
        expect(encoded[missingField], isNull);
      } else {
        expect(
          () => WorkItemDraft.fromFields(kind, json),
          throwsFormatException,
        );
      }
    }
  });

  test('test_work_item_draft_from_fields_property_uses_the_given_kind', () {
    final Random random = seededRandom(50803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomWorkDraftJson(random);
      final DraftKind givenKind = pickOne(random, workDraftKinds);
      json['kind'] = pickOne(random, nodeDraftKinds);

      final WorkItemDraft draft = WorkItemDraft.fromFields(givenKind, json);

      expect(draft.kind, same(givenKind));
      expect(draft.toJson()['kind'], givenKind.wireName);
    }
  });

  test('test_work_item_draft_to_json_property_round_trips_as_text', () {
    final Random random = seededRandom(50804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft draft = randomWorkItemDraft(random);

      final String jsonText = jsonEncode(draft.toJson());
      final ItemDraft decoded = ItemDraft.fromJson(jsonDecode(jsonText));

      _expectSameWorkDraft(decoded as WorkItemDraft, draft);
    }
  });

  test('test_work_item_draft_to_json_property_writes_the_node_fields', () {
    final Random random = seededRandom(50805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft draft = randomWorkItemDraft(random);
      final List<String> skillTexts = <String>[];
      for (final SkillId skill in draft.skills) {
        skillTexts.add(skill.value);
      }

      final JsonObject json = draft.toJson();

      expect(json.keys.toSet(), equals(_nodeWorkDraftFields));
      expect(json['kind'], isIn(_workKindNames));
      expect(json['project_id'], draft.projectId?.value);
      expect(json['skills'], orderedEquals(skillTexts));
      expect(json['agent_place'], isIn(nodeAgentPlaces));
      expect(json['approval_policy'], isIn(_nodeApprovalPoliciesOrNone));
    }
  });

  test('test_work_item_draft_to_json_property_is_stable_across_trips', () {
    final Random random = seededRandom(50806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomWorkDraftJson(random);
      final DraftKind kind = DraftKind.decode(json['kind']);

      final JsonObject encoded = WorkItemDraft.fromFields(kind, json).toJson();

      expect(encoded, equals(json));
    }
  });
}
