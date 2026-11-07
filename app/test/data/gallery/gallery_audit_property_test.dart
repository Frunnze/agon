import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/device.dart';

import '../../support/random_inputs.dart';
import 'support/gallery_records.dart';

const String _tamperedHash =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

AuditEntry _withPreviousHash(AuditEntry entry, String previousHash) {
  return AuditEntry(
    index: entry.index,
    at: entry.at,
    deviceId: entry.deviceId,
    event: entry.event,
    detail: entry.detail,
    previousHash: previousHash,
    hash: entry.hash,
  );
}

void main() {
  test('test_gallery_audit_entries_property_each_links_to_the_older_one', () {
    for (int index = 1; index < galleryAuditEntries.length; index += 1) {
      final AuditEntry newer = galleryAuditEntries[index - 1];
      final AuditEntry older = galleryAuditEntries[index];

      expect(newer.previousHash, older.hash, reason: '${newer.index}');
    }
  });

  test('test_gallery_audit_entries_property_indexes_count_down_by_one', () {
    expect(galleryAuditEntries, isNotEmpty);

    for (int index = 1; index < galleryAuditEntries.length; index += 1) {
      final int newerIndex = galleryAuditEntries[index - 1].index;
      final int olderIndex = galleryAuditEntries[index].index;

      expect(newerIndex, olderIndex + 1);
    }
    expect(galleryAuditEntries.last.index, greaterThanOrEqualTo(0));
  });

  test('test_gallery_audit_entries_property_fake_repository_verifies_'
      'the_chain', () async {
    final FakeAuditRepository repository = FakeAuditRepository(
      entries: galleryAuditEntries,
    );

    final ChainSummary summary = await repository.verifyChain();

    expect(summary.entryCount, galleryAuditEntryCount);
    expect(summary.headHash, galleryAuditEntries.first.hash);
  });

  test('test_gallery_audit_entries_property_hashes_are_unique_sha256_'
      'digests', () {
    final List<String> hashes = <String>[
      for (final AuditEntry entry in galleryAuditEntries) entry.hash,
    ];

    for (final AuditEntry entry in galleryAuditEntries) {
      expect(entry.hash, matches(sha256HexPattern), reason: '${entry.index}');
      expect(entry.previousHash, matches(sha256HexPattern));
    }
    expect(hasNoRepeats(hashes), isTrue);
  });

  test('test_gallery_audit_entries_property_newest_first_and_not_in_the_'
      'future', () {
    for (int index = 0; index < galleryAuditEntries.length; index += 1) {
      final AuditEntry entry = galleryAuditEntries[index];
      expect(entry.at.isAfter(galleryNow), isFalse, reason: entry.event);
      if (index > 0) {
        final DateTime newerAt = galleryAuditEntries[index - 1].at;
        expect(entry.at.isAfter(newerAt), isFalse, reason: entry.event);
      }
    }
  });

  test('test_gallery_audit_entries_property_written_by_paired_devices', () {
    for (final AuditEntry entry in galleryAuditEntries) {
      final Device device = findGalleryDevice(entry.deviceId);

      expect(device.pairedAt.isAfter(entry.at), isFalse, reason: entry.event);
      expect(device.revoked, isFalse);
      expect(entry.event.trim(), isNotEmpty);
    }
  });

  test('test_gallery_audit_entries_property_any_tampered_link_is_'
      'detected', () async {
    final Random random = seededRandom(68201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int tamperedIndex = random.nextInt(galleryAuditEntries.length - 1);
      final List<AuditEntry> tampered = List<AuditEntry>.of(
        galleryAuditEntries,
      );
      tampered[tamperedIndex] = _withPreviousHash(
        tampered[tamperedIndex],
        _tamperedHash,
      );
      final FakeAuditRepository repository = FakeAuditRepository(
        entries: tampered,
      );

      await expectLater(repository.verifyChain(), throwsStateError);
    }
  });

  test('test_gallery_audit_entry_count_property_counts_up_to_the_newest', () {
    final int newestIndex = galleryAuditEntries.first.index;

    expect(galleryAuditEntryCount, newestIndex + 1);
    expect(galleryAuditEntryCount, greaterThanOrEqualTo(1));
    expect(
      galleryAuditEntryCount,
      greaterThanOrEqualTo(galleryAuditEntries.length),
    );
  });
}
