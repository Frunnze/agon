import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/audit_values.dart' as node;
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';

void main() {
  test('test_map_audit_entry_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9801);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditEntryView wire = node.AuditEntryView.fromJson(
        randomAuditEntryJson(random),
      );
      final AuditEntry entry = mapAuditEntryFromNode(wire);

      expect(entry.index, wire.index);
      expect(entry.at, wire.at);
      expect(entry.deviceId, wire.deviceId);
      expect(entry.event, wire.event);
      expect(entry.detail, wire.detail ?? '');
      expect(entry.previousHash, wire.previousHash);
      expect(entry.hash, wire.hash);
    }
  });

  test('test_map_audit_entries_from_node_property_newest_first', () {
    final Random random = seededRandom(9802);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditView wire = node.AuditView.fromJson(
        randomAuditViewJson(random),
      );
      final List<AuditEntry> entries = mapAuditEntriesFromNode(wire);

      expect(entries.map((AuditEntry entry) => entry.hash), <String>[
        for (final node.AuditEntryView entry in wire.entries.reversed)
          entry.hash,
      ]);
    }
  });

  test('test_map_chain_summary_from_node_property_keeps_count_and_head', () {
    final Random random = seededRandom(9803);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AuditView wire = node.AuditView.fromJson(
        randomAuditViewJson(random),
      );
      final ChainSummary summary = mapChainSummaryFromNode(wire);

      expect(summary.entryCount, wire.entryCount);
      expect(summary.headHash, wire.headHash);
    }
  });
}
