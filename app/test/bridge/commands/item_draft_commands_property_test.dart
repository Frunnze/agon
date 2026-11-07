import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/item_draft_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/random_item_drafts.dart';
import 'support/drafting_and_file_command_properties.dart';

const int _firstMemberSeed = 9814000;
const int _firstReplySeed = 9815000;
const int _firstDraftChangeSeed = 9816000;
const Set<String> _rustDraftChangeFields = <String>{'draft', 'note'};

const List<ModelledCommandRow> _itemDraftCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'draft_item_command',
    commandName: 'draft_item',
    build: _buildDraftItem,
  ),
  ModelledCommandRow(
    typeName: 'item_draft_status_command',
    commandName: 'item_draft_status',
    build: _buildItemDraftStatus,
  ),
];

const Map<DraftKind, String> _rustDraftKindNames = <DraftKind, String>{
  DraftKind.task: 'task',
  DraftKind.job: 'job',
  DraftKind.skill: 'skill',
  DraftKind.rule: 'rule',
};

typedef _ModelledDraftChange = ({
  DraftChange? change,
  Object? expectedJson,
});

void main() {
  testModelledCommandRows(_itemDraftCommandRows, _firstMemberSeed);
  testCommandReplyRows(_itemDraftCommandRows, _firstReplySeed);
  _testDraftChangeConstructorProperties();
  _testDraftChangeToJsonProperties();
}

void _testDraftChangeConstructorProperties() {
  test('test_draft_change_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(_firstDraftChangeSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraft draft = randomTypedItemDraft(random);
      final String note = randomHostileText(random);

      final DraftChange change = DraftChange(draft: draft, note: note);

      expect(identical(change.draft, draft), isTrue);
      expect(change.note, note);
    }
  });

  test('test_draft_change_constructor_property_keeps_the_note_verbatim', () {
    final Random random = seededRandom(_firstDraftChangeSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String core = randomHostileText(random);
      final String paddedNote = ' \t$core\n ';

      final DraftChange change = DraftChange(
        draft: randomTypedItemDraft(random),
        note: paddedNote,
      );

      expect(change.note, paddedNote);
      expect(change.note.length, paddedNote.length);
    }
  });

  test('test_draft_change_constructor_property_same_fields_same_json', () {
    final Random random = seededRandom(_firstDraftChangeSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> draftJson = randomItemDraftJson(random);
      final String note = randomHostileText(random);

      final DraftChange first = DraftChange(
        draft: ItemDraft.fromJson(draftJson),
        note: note,
      );
      final DraftChange second = DraftChange(
        draft: ItemDraft.fromJson(draftJson),
        note: note,
      );

      expect(jsonEncode(second.toJson()), jsonEncode(first.toJson()));
    }
  });
}

void _testDraftChangeToJsonProperties() {
  test('test_draft_change_to_json_property_sends_the_draft_and_note', () {
    final Random random = seededRandom(_firstDraftChangeSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> draftJson = randomItemDraftJson(random);
      final String note = randomHostileText(random);
      final DraftChange change = DraftChange(
        draft: ItemDraft.fromJson(draftJson),
        note: note,
      );

      expect(
        rereadThroughWire(change.toJson()),
        equals(<String, Object?>{'draft': draftJson, 'note': note}),
      );
    }
  });

  test('test_draft_change_to_json_property_draft_decodes_back', () {
    final Random random = seededRandom(_firstDraftChangeSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraft draft = randomTypedItemDraft(random);
      final DraftChange change = DraftChange(
        draft: draft,
        note: randomHostileText(random),
      );
      final JsonObject rereadJson = decodeObject(
        rereadThroughWire(change.toJson()),
      );

      final ItemDraft rereadDraft = ItemDraft.fromJson(rereadJson['draft']);

      expect(rereadDraft.runtimeType, draft.runtimeType);
      expect(rereadDraft.toJson(), equals(draft.toJson()));
    }
  });

  test('test_draft_change_to_json_property_fits_the_rust_fields', () {
    final Random random = seededRandom(_firstDraftChangeSeed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftChange change = DraftChange(
        draft: randomTypedItemDraft(random),
        note: randomHostileText(random),
      );
      final JsonObject changeJson = change.toJson();
      final JsonObject draftJson = decodeObject(changeJson['draft']);

      expect(changeJson.keys.toSet(), equals(_rustDraftChangeFields));
      expect(changeJson['note'], isA<String>());
      expect(nodeDraftKinds, contains(draftJson['kind']));
    }
  });
}

_ModelledDraftChange _randomModelledDraftChange(Random random) {
  if (random.nextBool()) {
    return (change: null, expectedJson: null);
  }
  final Map<String, Object?> draftJson = randomItemDraftJson(random);
  final String note = randomHostileText(random);
  final DraftChange change = DraftChange(
    draft: ItemDraft.fromJson(draftJson),
    note: note,
  );
  return (
    change: change,
    expectedJson: <String, Object?>{'draft': draftJson, 'note': note},
  );
}

ModelledCommand _buildDraftItem(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final DraftKind kind = pickOne(random, DraftKind.values);
  final String wish = randomHostileText(random);
  final String? startedFrom = random.nextBool()
      ? null
      : randomHostileText(random);
  final _ModelledDraftChange modelledChange = _randomModelledDraftChange(
    random,
  );
  final DraftItemCommand command = DraftItemCommand(
    workspaceId: workspaceId,
    kind: kind,
    wish: wish,
    startedFrom: startedFrom,
    change: modelledChange.change,
  );
  return (
    command: command,
    givenFields: <Object?>[
      workspaceId,
      kind,
      wish,
      startedFrom,
      modelledChange.change,
    ],
    keptFields: <Object?>[
      command.workspaceId,
      command.kind,
      command.wish,
      command.startedFrom,
      command.change,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'kind': _rustDraftKindNames[kind],
      'request': wish,
      'started_from': startedFrom,
      'change': modelledChange.expectedJson,
    },
  );
}

ModelledCommand _buildItemDraftStatus(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final TaskId taskId = TaskId(randomHostileText(random));
  final DraftKind kind = pickOne(random, DraftKind.values);
  final ItemDraftStatusCommand command = ItemDraftStatusCommand(
    workspaceId: workspaceId,
    taskId: taskId,
    kind: kind,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, taskId, kind],
    keptFields: <Object?>[command.workspaceId, command.taskId, command.kind],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'task_id': taskId.value,
      'kind': _rustDraftKindNames[kind],
    },
  );
}
