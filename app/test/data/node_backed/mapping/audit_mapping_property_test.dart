import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/audit_values.dart' as node;
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../support/random_inputs.dart';

const int _largestEntryCount = 6;
const int _largestSafeCount = 9007199254740991;
const List<int> _boundaryCounts = <int>[0, 1, _largestSafeCount];

node.AuditEntryView _randomHostileEntry(Random random) {
  return node.AuditEntryView(
    index: randomCount(random),
    at: randomPreciseMoment(random),
    deviceId: randomDeviceId(random),
    event: randomHostileText(random),
    detail: random.nextBool() ? null : randomHostileText(random),
    previousHash: randomHostileText(random),
    hash: randomHostileText(random),
  );
}

List<node.AuditEntryView> _randomEntries(Random random) {
  final int count = random.nextInt(_largestEntryCount);
  return <node.AuditEntryView>[
    for (int i = 0; i < count; i += 1) _randomHostileEntry(random),
  ];
}

node.AuditView _buildView(Random random, List<node.AuditEntryView> entries) {
  return node.AuditView(
    entries: entries,
    entryCount: random.nextBool()
        ? entries.length
        : pickOne(random, _boundaryCounts),
    headHash: randomHostileText(random),
    intact: random.nextBool(),
  );
}

void _expectSameEntry(AuditEntry entry, node.AuditEntryView wire) {
  expect(entry.index, wire.index);
  expect(entry.at, wire.at);
  expect(entry.deviceId, wire.deviceId);
  expect(entry.event, wire.event);
  expect(entry.detail, wire.detail ?? '');
  expect(entry.previousHash, wire.previousHash);
  expect(entry.hash, wire.hash);
}

void main() {
  test('test_map_audit_entry_from_node_property_keeps_hostile_texts', () {
    final Random random = seededRandom(71701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditEntryView wire = _randomHostileEntry(random);

      _expectSameEntry(mapAuditEntryFromNode(wire), wire);
    }
  });

  test(
    'test_map_audit_entry_from_node_property_given_detail_is_untouched',
    () {
      final Random random = seededRandom(71702);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, Object?> entryJson = randomAuditEntryJson(random);
        final String detail = randomHostileText(random);
        entryJson['detail'] = detail;

        final AuditEntry entry = mapAuditEntryFromNode(
          node.AuditEntryView.fromJson(entryJson),
        );

        expect(entry.detail, detail);
      }
    },
  );

  test('test_map_audit_entry_from_node_property_keeps_the_instant', () {
    final Random random = seededRandom(71703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> entryJson = randomAuditEntryJson(random);
      final DateTime at = randomPreciseMoment(random);
      entryJson['at'] = writeMomentWithRandomOffset(random, at);

      final AuditEntry entry = mapAuditEntryFromNode(
        node.AuditEntryView.fromJson(entryJson),
      );

      expect(entry.at.isAtSameMomentAs(at), isTrue);
    }
  });

  test('test_map_audit_entries_from_node_property_reversed_is_node_order', () {
    final Random random = seededRandom(71704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.AuditEntryView> wireEntries = _randomEntries(random);

      final List<AuditEntry> entries = mapAuditEntriesFromNode(
        _buildView(random, wireEntries),
      );

      expect(entries.length, wireEntries.length);
      final List<AuditEntry> oldestFirst = entries.reversed.toList();
      for (int j = 0; j < wireEntries.length; j += 1) {
        _expectSameEntry(oldestFirst[j], wireEntries[j]);
      }
    }
  });

  test(
    'test_map_audit_entries_from_node_property_later_entries_come_first',
    () {
      final Random random = seededRandom(71705);
      for (int i = 0; i < propertyIterations; i += 1) {
        final List<node.AuditEntryView> earlier = _randomEntries(random);
        final List<node.AuditEntryView> later = _randomEntries(random);

        final List<AuditEntry> joined = mapAuditEntriesFromNode(
          _buildView(random, <node.AuditEntryView>[...earlier, ...later]),
        );
        final List<AuditEntry> laterAlone = mapAuditEntriesFromNode(
          _buildView(random, later),
        );
        final List<AuditEntry> earlierAlone = mapAuditEntriesFromNode(
          _buildView(random, earlier),
        );

        expect(joined.map((AuditEntry entry) => entry.hash), <String>[
          for (final AuditEntry entry in laterAlone) entry.hash,
          for (final AuditEntry entry in earlierAlone) entry.hash,
        ]);
      }
    },
  );

  test('test_map_audit_entries_from_node_property_cannot_be_changed', () {
    final Random random = seededRandom(71706);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditView wire = node.AuditView.fromJson(
        randomAuditViewJson(random),
      );
      final List<AuditEntry> entries = mapAuditEntriesFromNode(wire);
      final AuditEntry extraEntry = mapAuditEntryFromNode(
        _randomHostileEntry(random),
      );

      expect(() => entries.add(extraEntry), throwsUnsupportedError);
      expect(entries.clear, throwsUnsupportedError);
    }
  });

  test('test_map_chain_summary_from_node_property_keeps_boundary_counts', () {
    final Random random = seededRandom(71707);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditView wire = _buildView(random, _randomEntries(random));

      final ChainSummary summary = mapChainSummaryFromNode(wire);

      expect(summary.entryCount, wire.entryCount);
      expect(summary.headHash, wire.headHash);
    }
  });

  test('test_map_chain_summary_from_node_property_ignores_listed_entries', () {
    final Random random = seededRandom(71708);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditView wire = _buildView(random, _randomEntries(random));
      final node.AuditView otherEntries = node.AuditView(
        entries: _randomEntries(random),
        entryCount: wire.entryCount,
        headHash: wire.headHash,
        intact: !wire.intact,
      );

      final ChainSummary summary = mapChainSummaryFromNode(wire);
      final ChainSummary otherSummary = mapChainSummaryFromNode(otherEntries);

      expect(otherSummary.entryCount, summary.entryCount);
      expect(otherSummary.headHash, summary.headHash);
    }
  });

  test('test_map_chain_summary_from_node_property_head_hash_is_untouched', () {
    final Random random = seededRandom(71709);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> auditJson = randomAuditViewJson(random);
      final String headHash = randomHostileText(random);
      auditJson['head_hash'] = headHash;

      final ChainSummary summary = mapChainSummaryFromNode(
        node.AuditView.fromJson(auditJson),
      );

      expect(summary.headHash, headHash);
    }
  });
}
