import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_file_json.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../bridge/support/random_wire_values.dart';
import '../../../support/random_inputs.dart';

node.RepositoryHolder _rebuildNodeHolder(RepositoryHolder holder) {
  return node.RepositoryHolder(
    deviceId: holder.deviceId,
    name: holder.name,
    lastSeen: holder.lastSeen,
  );
}

node.RepositoryBranchesView _rebuildNodeSource(RepositoryFileSource source) {
  switch (source) {
    case FilesFromRunner():
      return node.AvailableRepositoryBranches(
        runner: node.FileRunner(
          deviceId: source.runnerId,
          name: source.runnerName,
        ),
        branches: source.branches,
        taskBranches: source.taskBranches,
      );
    case FilesWithoutRunner():
      return node.UnavailableRepositoryBranches(
        holders: <node.RepositoryHolder>[
          for (final RepositoryHolder holder in source.holders)
            _rebuildNodeHolder(holder),
        ],
      );
  }
}

node.RepositoryHolder _randomHostileNodeHolder(Random random) {
  return node.RepositoryHolder(
    deviceId: randomDeviceId(random),
    name: randomHostileText(random),
    lastSeen: randomPreciseMoment(random),
  );
}

void main() {
  test('test_map_repository_holder_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(72201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RepositoryHolder wireHolder = _randomHostileNodeHolder(
        random,
      );

      final RepositoryHolder holder = mapRepositoryHolderFromNode(wireHolder);

      expect(holder.deviceId, wireHolder.deviceId);
      expect(holder.name, wireHolder.name);
      expect(holder.lastSeen, wireHolder.lastSeen);
      expect(holder.lastSeen.isUtc, wireHolder.lastSeen.isUtc);
    }
  });

  test('test_map_repository_holder_from_node_property_round_trips_json', () {
    final Random random = seededRandom(72202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RepositoryHolder wireHolder = node.RepositoryHolder.fromJson(
        randomRepositoryHolderJson(random),
      );

      final RepositoryHolder holder = mapRepositoryHolderFromNode(wireHolder);

      expect(_rebuildNodeHolder(holder).toJson(), wireHolder.toJson());
    }
  });

  test('test_map_repository_holder_from_node_property_holders_keep_order', () {
    final Random random = seededRandom(72203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.RepositoryHolder> wireHolders = <node.RepositoryHolder>[
        for (final Object? json in randomListOf(
          random,
          randomRepositoryHolderJson,
        ))
          node.RepositoryHolder.fromJson(json),
      ];
      final RepositoryFileSource source = mapRepositoryFileSourceFromNode(
        node.UnavailableRepositoryBranches(holders: wireHolders),
      );

      final List<RepositoryHolder> holders =
          (source as FilesWithoutRunner).holders;
      expect(holders.length, wireHolders.length);
      for (int index = 0; index < holders.length; index += 1) {
        final RepositoryHolder expected = mapRepositoryHolderFromNode(
          wireHolders[index],
        );
        expect(holders[index].deviceId, expected.deviceId);
        expect(holders[index].lastSeen, expected.lastSeen);
      }
    }
  });

  test('test_map_repository_file_source_from_node_property_round_trips', () {
    final Random random = seededRandom(72204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRepositoryBranchesJson(random);
      final node.RepositoryBranchesView view =
          node.RepositoryBranchesView.fromJson(json);

      final RepositoryFileSource source = mapRepositoryFileSourceFromNode(
        view,
      );

      expect(_rebuildNodeSource(source).toJson(), view.toJson());
    }
  });

  test('test_map_repository_file_source_from_node_property_lists_frozen', () {
    final Random random = seededRandom(72205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryFileSource source = mapRepositoryFileSourceFromNode(
        node.RepositoryBranchesView.fromJson(
          randomRepositoryBranchesJson(random),
        ),
      );

      switch (source) {
        case FilesFromRunner():
          expect(() => source.branches.add(''), throwsUnsupportedError);
          expect(() => source.taskBranches.add(''), throwsUnsupportedError);
        case FilesWithoutRunner():
          expect(source.holders.clear, throwsUnsupportedError);
      }
    }
  });

  test('test_map_repository_entry_kind_from_node_property_is_one_to_one', () {
    final Set<RepositoryEntryKind> kinds = <RepositoryEntryKind>{
      for (final node.RepositoryEntryKind wireKind
          in node.RepositoryEntryKind.values)
        mapRepositoryEntryKindFromNode(wireKind),
    };

    expect(kinds, RepositoryEntryKind.values.toSet());
    expect(
      node.RepositoryEntryKind.values.length,
      RepositoryEntryKind.values.length,
    );
  });

  test('test_map_repository_entry_kind_from_node_property_keeps_the_name', () {
    for (final node.RepositoryEntryKind wireKind
        in node.RepositoryEntryKind.values) {
      final RepositoryEntryKind kind = mapRepositoryEntryKindFromNode(
        wireKind,
      );

      expect(kind.name, wireKind.wireName);
    }
  });

  test('test_map_repository_entry_kind_from_node_property_wire_table', () {
    expect(nodeRepositoryEntryKinds, isNotEmpty);
    final Set<RepositoryEntryKind> kinds = <RepositoryEntryKind>{};

    for (final String wireName in nodeRepositoryEntryKinds) {
      final RepositoryEntryKind kind = mapRepositoryEntryKindFromNode(
        node.RepositoryEntryKind.decode(wireName),
      );
      kinds.add(kind);

      expect(kind, RepositoryEntryKind.values.byName(wireName));
    }
    expect(kinds.length, nodeRepositoryEntryKinds.length);
  });

  test('test_map_repository_entry_from_node_property_round_trips_json', () {
    final Random random = seededRandom(72206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRepositoryEntryJson(random);

      final RepositoryEntry entry = mapRepositoryEntryFromNode(
        node.RepositoryEntry.fromJson(json),
      );
      final node.RepositoryEntry rebuilt = node.RepositoryEntry(
        name: entry.name,
        kind: node.RepositoryEntryKind.decode(entry.kind.name),
        size: entry.size,
      );

      expect(rebuilt.toJson(), equals(json));
    }
  });

  test('test_map_repository_entry_from_node_property_hostile_names_kept', () {
    final Random random = seededRandom(72207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileText(random);
      final int? size = random.nextBool() ? null : randomWholeNumber(random);

      final RepositoryEntry entry = mapRepositoryEntryFromNode(
        node.RepositoryEntry(
          name: name,
          kind: pickOne(random, node.RepositoryEntryKind.values),
          size: size,
        ),
      );

      expect(entry.name, name);
      expect(entry.size, size);
    }
  });
}
