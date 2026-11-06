import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_file_json.dart';
import '../support/random_repository_file_values.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const WireFields _repositoryEntryFields = WireFields(
  requiredFields: <String>['name', 'kind'],
  optionalFields: <String>['size'],
  defaultedListFields: <String>[],
);

const WireFields _repositoryFolderFields = WireFields(
  requiredFields: <String>['entries'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

void main() {
  test('test_repository_entry_kind_decode_property_reads_every_wire_name', () {
    expectDecodesEveryWireName(
      RepositoryEntryKind.values,
      RepositoryEntryKind.decode,
    );
  });

  test('test_repository_entry_kind_decode_property_rejects_near_misses', () {
    final Random random = seededRandom(52501);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsNearMissWireNames(
        random,
        RepositoryEntryKind.values,
        RepositoryEntryKind.decode,
      );
    }
  });

  test('test_repository_entry_kind_decode_property_rejects_non_text', () {
    final Random random = seededRandom(52502);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsWireNamesOfAnotherKind(
        random,
        RepositoryEntryKind.values,
        RepositoryEntryKind.decode,
      );
    }
  });

  test(
    'test_repository_entry_from_json_property_missing_fields_follow_node',
    () {
      final Random random = seededRandom(52503);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryEntryJson(random);

        expectRequiredFieldsAreNeeded(
          json,
          _repositoryEntryFields,
          RepositoryEntry.fromJson,
        );
        expectOptionalFieldsMayBeLeftOut(
          random,
          json,
          _repositoryEntryFields,
          RepositoryEntry.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_entry_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52504);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomRepositoryEntryJson(random),
          RepositoryEntry.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_entry_from_json_property_reads_each_field_by_name',
    () {
      final Random random = seededRandom(52505);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryEntryJson(random);

        final RepositoryEntry entry = RepositoryEntry.fromJson(
          withUnknownFields(random, json),
        );

        expect(entry.name, json['name']);
        expect(entry.kind.wireName, json['kind']);
        expect(entry.size, json['size']);
      }
    },
  );

  test(
    'test_repository_entry_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52506);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject encoded = randomRepositoryEntry(random).toJson();

        expect(
          encoded.keys.toSet(),
          equals(_repositoryEntryFields.everyField),
        );
      }
    },
  );

  test('test_repository_entry_to_json_property_values_mirror_the_entry', () {
    final Random random = seededRandom(52507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryEntry entry = randomRepositoryEntry(random);

      final JsonObject encoded = entry.toJson();

      expect(encoded['name'], entry.name);
      expect(encoded['kind'], entry.kind.wireName);
      expect(encoded['size'], entry.size);
    }
  });

  test('test_repository_entry_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52508);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        randomRepositoryEntry(random),
        RepositoryEntry.fromJson,
      );
    }
  });

  test('test_repository_folder_view_property_keeps_entries_in_order', () {
    final Random random = seededRandom(52509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryEntry> entries = randomRepositoryEntries(random);

      final RepositoryFolderView folder = RepositoryFolderView(
        entries: entries,
      );

      expect(folder.entries, orderedEquals(entries));
    }
  });

  test('test_repository_folder_view_property_ignores_caller_changes', () {
    final Random random = seededRandom(52510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryEntry> entries = randomRepositoryEntries(random);

      final RepositoryFolderView folder = RepositoryFolderView(
        entries: entries,
      );

      expectListIgnoresCallerChanges(
        entries,
        folder.entries,
        randomRepositoryEntry(random),
      );
    }
  });

  test('test_repository_folder_view_property_entries_refuse_changes', () {
    final Random random = seededRandom(52511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryFolderView folder = RepositoryFolderView(
        entries: randomRepositoryEntries(random),
      );

      expectListRefusesChanges(folder.entries, randomRepositoryEntry(random));
    }
  });

  test(
    'test_repository_folder_view_from_json_property_missing_fields_follow',
    () {
      final Random random = seededRandom(52512);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectRequiredFieldsAreNeeded(
          randomRepositoryFolderJson(random),
          _repositoryFolderFields,
          RepositoryFolderView.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_folder_view_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52513);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomRepositoryFolderJson(random),
          RepositoryFolderView.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_folder_view_from_json_property_entries_keep_their_order',
    () {
      final Random random = seededRandom(52514);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryFolderJson(random);

        final RepositoryFolderView folder = RepositoryFolderView.fromJson(
          withUnknownFields(random, json),
        );

        expect(encodeList(folder.entries), equals(json['entries']));
      }
    },
  );

  test(
    'test_repository_folder_view_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52515);

      for (int i = 0; i < propertyIterations; i += 1) {
        final RepositoryFolderView folder = RepositoryFolderView(
          entries: randomRepositoryEntries(random),
        );

        final Set<String> fields = folder.toJson().keys.toSet();

        expect(fields, equals(_repositoryFolderFields.everyField));
      }
    },
  );

  test('test_repository_folder_view_to_json_property_entries_in_order', () {
    final Random random = seededRandom(52516);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryEntry> entries = randomRepositoryEntries(random);

      final JsonObject encoded = RepositoryFolderView(entries: entries)
          .toJson();
      final List<Object?> encodedEntries =
          encoded['entries']! as List<Object?>;

      expect(encodedEntries.length, entries.length);
      for (int j = 0; j < entries.length; j += 1) {
        expect(encodedEntries[j], equals(entries[j].toJson()));
      }
    }
  });

  test(
    'test_repository_folder_view_to_json_property_plain_json_decodes_back',
    () {
      final Random random = seededRandom(52517);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectPlainJsonThatDecodesBack(
          RepositoryFolderView(entries: randomRepositoryEntries(random)),
          RepositoryFolderView.fromJson,
        );
      }
    },
  );
}
