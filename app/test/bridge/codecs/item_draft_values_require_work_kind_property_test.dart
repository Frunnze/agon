import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/random_item_drafts.dart';
import 'support/codec_rows.dart';
import 'support/item_draft_codec_rows.dart';

const int _firstSeed = 9405000;
const String _kindField = 'kind';
const List<DraftKind> _otherDraftKinds = <DraftKind>[
  DraftKind.skill,
  DraftKind.rule,
];

void main() {
  test('test_require_work_kind_property_task_and_job_kinds_are_kept', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft draft = randomWorkItemDraft(random);
      final DraftKind kind = pickOne(random, workDraftKinds);
      final WorkItemDraft rebuilt = rebuildWorkItemDraft(
        draft: draft,
        kind: kind,
      );
      final Object? wireJson = rereadThroughWire(rebuilt.toJson());
      final ItemDraft reread = ItemDraft.fromJson(wireJson);

      expect(rebuilt.kind, kind);
      expect(rebuilt.toJson()[_kindField], kind.wireName);
      expect(reread, isA<WorkItemDraft>());
      expect((reread as WorkItemDraft).kind, kind);
    }
  });

  test('test_require_work_kind_property_other_kinds_are_refused', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkItemDraft draft = randomWorkItemDraft(random);
      final DraftKind kind = pickOne(random, _otherDraftKinds);

      expect(
        () => rebuildWorkItemDraft(draft: draft, kind: kind),
        throwsA(
          isA<ArgumentError>()
              .having(
                (ArgumentError error) => error.invalidValue,
                'invalidValue',
                kind,
              )
              .having((ArgumentError error) => error.name, 'name', 'kind'),
        ),
      );
    }
  });

  test(
    'test_require_work_kind_property_decoded_work_drafts_keep_the_kind',
    () {
      final Random random = seededRandom(_firstSeed + 2);
      int workDraftCount = 0;

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject draftJson = randomItemDraftJson(random);
        final ItemDraft draft = ItemDraft.fromJson(draftJson);
        if (draft is! WorkItemDraft) {
          continue;
        }
        workDraftCount += 1;

        expect(workDraftKinds, contains(draft.kind));
        expect(draft.kind.wireName, draftJson[_kindField]);
      }

      expect(workDraftCount, greaterThan(0));
    },
  );
}
