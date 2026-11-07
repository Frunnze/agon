import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/audit.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_audit_rig.dart';

const String _prefix = 'test_node_backed_audit_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 6;

Future<AuditRig> _buildLoadedRig(Random random) async {
  final AuditRig rig = AuditRig();
  rig.appendLinkedEntries(random);
  await rig.repository.load();
  return rig;
}

void main() {
  test('${_prefix}_new_property_starts_empty_and_sends_nothing', () async {
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = AuditRig();
      await pumpEventQueue();

      expect(rig.repository.listEntries(), isEmpty);
      expect(rig.node.receivedCommands, isEmpty);
      expect(rig.notifications.count, 0);
    }
  });

  test('${_prefix}_new_property_empty_chain_matches_an_empty_fake', () async {
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = AuditRig();
      final FakeAuditRepository fake = FakeAuditRepository(
        entries: rig.repository.listEntries(),
      );

      final ChainSummary fromNode = await rig.repository.verifyChain();
      final ChainSummary fromFake = await fake.verifyChain();

      expect(fromNode.entryCount, fromFake.entryCount);
      expect(fromNode.headHash, fromFake.headHash);
      expect(fromNode.headHash, genesisHash);
    }
  });

  test('${_prefix}_new_property_repositories_keep_their_own_list', () async {
    final Random random = seededRandom(75901);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig loaded = await _buildLoadedRig(random);
      final AuditRig untouched = AuditRig();
      untouched.appendLinkedEntries(random);

      expect(
        listEntryHashes(loaded.repository.listEntries()),
        loaded.listNodeHashesNewestFirst(),
      );
      expect(untouched.repository.listEntries(), isEmpty);
      expect(untouched.node.receivedCommands, isEmpty);
    }
  });

  test('${_prefix}_list_entries_property_newest_first', () async {
    final Random random = seededRandom(75902);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);

      final List<AuditEntry> entries = rig.repository.listEntries();

      expect(listEntryHashes(entries), rig.listNodeHashesNewestFirst());
      for (int index = 1; index < entries.length; index += 1) {
        expect(entries[index - 1].index, entries[index].index + 1);
        expect(entries[index - 1].previousHash, entries[index].hash);
      }
    }
  });

  test('${_prefix}_list_entries_property_cannot_be_changed', () async {
    final Random random = seededRandom(75903);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      final List<AuditEntry> entries = rig.repository.listEntries();

      expect(entries.clear, throwsUnsupportedError);
    }
  });

  test('${_prefix}_list_entries_property_reads_without_the_node', () async {
    final Random random = seededRandom(75904);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      final List<AuditEntry> first = rig.repository.listEntries();
      final int sentBefore = rig.node.receivedCommands.length;
      rig.appendLinkedEntries(random);

      expect(rig.repository.listEntries(), same(first));
      expect(rig.node.receivedCommands.length, sentBefore);
    }
  });

  test('${_prefix}_load_property_mirrors_the_node_after_appends', () async {
    final Random random = seededRandom(75905);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = AuditRig();
      final int loadCount = 1 + random.nextInt(_longestSequence);

      for (int load = 0; load < loadCount; load += 1) {
        rig.appendLinkedEntries(random);
        await rig.repository.load();

        expect(
          listEntryHashes(rig.repository.listEntries()),
          rig.listNodeHashesNewestFirst(),
        );
      }
    }
  });

  test('${_prefix}_load_property_notifies_once_per_load', () async {
    final Random random = seededRandom(75906);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = AuditRig();
      final int loadCount = random.nextInt(_longestSequence);

      for (int load = 0; load < loadCount; load += 1) {
        rig.appendLinkedEntries(random);
        await rig.repository.load();
      }

      expect(rig.notifications.count, loadCount);
    }
  });

  test('${_prefix}_load_property_refusal_keeps_the_entries', () async {
    final Random random = seededRandom(75907);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      final List<AuditEntry> before = rig.repository.listEntries();
      final int notifiedBefore = rig.notifications.count;
      rig.appendLinkedEntries(random);
      rig.listRefusal = 'the app server answered 503: ${randomText(random)}';

      await expectLater(rig.repository.load(), throwsStateError);

      expect(rig.repository.listEntries(), same(before));
      expect(rig.notifications.count, notifiedBefore);
    }
  });
}
