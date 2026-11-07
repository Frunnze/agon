import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_item_drafts.dart';
import '../../../support/random_inputs.dart';

const int _largestOverflow = 1000;

Map<String, Object?> _randomImpossibleScheduleJson(Random random) {
  final int overflow = random.nextInt(_largestOverflow);
  final List<Map<String, Object?>> schedules = <Map<String, Object?>>[
    <String, Object?>{'every': 'hour', 'minute': 60 + overflow},
    <String, Object?>{
      'every': 'day',
      'at': <String, Object?>{'hour': 24 + overflow, 'minute': 0},
    },
    <String, Object?>{
      'every': 'week',
      'on': 'Mon',
      'at': <String, Object?>{'hour': 0, 'minute': 60 + overflow},
    },
  ];
  return pickOne(random, schedules);
}

void main() {
  test('test_map_work_from_node_property_keeps_every_work_field', () {
    final Random random = seededRandom(72508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkItemDraft wire = randomWorkItemDraft(random);

      final DraftedItem item = mapDraftedItemFromNode(wire);

      expect(item, isA<DraftedWork>());
      final DraftedWork work = item as DraftedWork;
      expect(work.title, wire.title);
      expect(work.details, wire.details);
      expect(work.projectId, wire.projectId);
      expect(work.skills, wire.skills);
      expect(work.usesAutomaticSkills, wire.usesAutomaticSkills);
      expect(mapTaskDoerToNode(work.doer).toJson(), wire.doer.toJson());
      expect(
        mapRunnerTargetToNode(work.runsOn).toJson(),
        wire.runsOn.toJson(),
      );
      expect(mapAgentPlaceToNode(work.agentPlace), wire.agentPlace);
      expect(
        mapOptionalApprovalPolicyToNode(work.approvalPolicy),
        wire.approvalPolicy,
      );
    }
  });

  test('test_map_work_from_node_property_schedule_is_absent_or_kept', () {
    final Random random = seededRandom(72509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkItemDraft wire = randomWorkItemDraft(random);

      final DraftedWork work = mapDraftedItemFromNode(wire) as DraftedWork;

      if (wire.schedule == null) {
        expect(work.schedule, isNull);
        continue;
      }
      expect(work.schedule, isNotNull);
      expect(
        mapScheduleToNode(work.schedule!).toJson(),
        wire.schedule!.toJson(),
      );
    }
  });

  test('test_map_work_from_node_property_rejects_an_impossible_schedule', () {
    final Random random = seededRandom(72510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = <String, Object?>{
        ...randomWorkItemDraft(random).toJson(),
        'schedule': _randomImpossibleScheduleJson(random),
      };
      final node.ItemDraft wire = node.ItemDraft.fromJson(json);

      expect(() => mapDraftedItemFromNode(wire), throwsFormatException);
    }
  });

  test('test_map_work_to_node_property_keeps_the_task_or_job_kind', () {
    final Random random = seededRandom(72511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedItem work = mapDraftedItemFromNode(
        randomWorkItemDraft(random),
      );
      final DraftKind kind = pickOne(random, <DraftKind>[
        DraftKind.task,
        DraftKind.job,
      ]);

      final node.ItemDraft wire = mapDraftedItemToNode(work, kind);

      expect(wire, isA<node.WorkItemDraft>());
      expect((wire as node.WorkItemDraft).kind, mapDraftKindToNode(kind));
    }
  });

  test('test_map_work_to_node_property_keeps_every_field_besides_kind', () {
    final Random random = seededRandom(72512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.WorkItemDraft original = randomWorkItemDraft(random);
      final DraftKind otherKind = original.kind == node.DraftKind.task
          ? DraftKind.job
          : DraftKind.task;

      final node.ItemDraft wire = mapDraftedItemToNode(
        mapDraftedItemFromNode(original),
        otherKind,
      );

      final Map<String, Object?> expectedJson = <String, Object?>{
        ...original.toJson(),
        'kind': otherKind.name,
      };
      expect(wire.toJson(), expectedJson);
    }
  });

  test('test_map_work_to_node_property_keeps_hostile_title_and_details', () {
    final Random random = seededRandom(72513);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomHostileText(random);
      final String details = randomHostileText(random);
      final Map<String, Object?> json = <String, Object?>{
        ...randomWorkItemDraft(random).toJson(),
        'title': title,
        'details': details,
      };
      final node.ItemDraft original = node.ItemDraft.fromJson(json);
      final DraftKind kind = DraftKind.values.byName(json['kind']! as String);

      final node.ItemDraft wire = mapDraftedItemToNode(
        mapDraftedItemFromNode(original),
        kind,
      );

      final node.WorkItemDraft work = wire as node.WorkItemDraft;
      expect(work.title, title);
      expect(work.details, details);
    }
  });
}
