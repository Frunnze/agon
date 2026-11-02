import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/models/audit.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_list_entries_property_newest_first', () {
    final FakeAuditRepository repository = FakeAuditRepository(
      entries: galleryAuditEntries,
      summary: const ChainSummary(entryCount: 1284, headHash: 'head'),
    );
    final List<AuditEntry> entries = repository.listEntries();

    for (int index = 1; index < entries.length; index += 1) {
      expect(entries[index - 1].index > entries[index].index, isTrue);
    }
  });

  test('test_verify_chain_property_broken_links_detected', () async {
    final Random random = seededRandom(908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AuditEntry> entries = <AuditEntry>[...galleryAuditEntries];
      final int brokenIndex = random.nextInt(entries.length);
      final AuditEntry original = entries[brokenIndex];
      final bool breaksChain = random.nextBool() && brokenIndex > 0;
      if (breaksChain) {
        entries[brokenIndex] = AuditEntry(
          index: original.index,
          at: original.at,
          deviceId: original.deviceId,
          event: original.event,
          detail: original.detail,
          previousHash: original.previousHash,
          hash: 'tampered',
        );
      }
      final FakeAuditRepository repository = FakeAuditRepository(
        entries: entries,
        summary: const ChainSummary(entryCount: 1284, headHash: 'head'),
      );

      if (breaksChain) {
        await expectLater(
          repository.verifyChain(),
          throwsA(isA<StateError>()),
        );
      } else {
        expect((await repository.verifyChain()).entryCount, 1284);
      }
    }
  });
}
