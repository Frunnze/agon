import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_item_drafts.dart';

const List<DraftKind> _libraryDraftKinds = <DraftKind>[
  DraftKind.skill,
  DraftKind.rule,
];

WorkItemDraft _copyWithKind(WorkItemDraft draft, DraftKind kind) {
  return WorkItemDraft(
    kind: kind,
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
    schedule: draft.schedule,
  );
}

void main() {
  test('test_work_item_draft_property_refuses_library_kinds', () {
    final Random random = seededRandom(9951);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft workDraft = randomWorkItemDraft(random);
      final DraftKind libraryKind = pickOne(random, _libraryDraftKinds);

      expect(() => _copyWithKind(workDraft, libraryKind), throwsArgumentError);
    }
  });

  test('test_work_item_draft_property_work_kinds_survive_the_wire', () {
    final Random random = seededRandom(9952);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind workKind = pickOne(random, workDraftKinds);
      final WorkItemDraft draft = _copyWithKind(
        randomWorkItemDraft(random),
        workKind,
      );

      final ItemDraft decoded = ItemDraft.fromJson(draft.toJson());

      expect(decoded, isA<WorkItemDraft>());
      expect((decoded as WorkItemDraft).kind, workKind);
      expect(decoded.title, draft.title);
    }
  });

  test('test_work_item_draft_property_every_kind_is_work_or_library', () {
    final Random random = seededRandom(9953);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft workDraft = randomWorkItemDraft(random);
      final DraftKind kind = pickOne(random, DraftKind.values);
      final bool isWorkKind = workDraftKinds.contains(kind);

      if (isWorkKind) {
        expect(_copyWithKind(workDraft, kind).kind, kind);
      } else {
        expect(() => _copyWithKind(workDraft, kind), throwsArgumentError);
      }
    }
  });
}
