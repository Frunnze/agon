import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../bridge/support/list_copy_properties.dart';
import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_audit_repository';
const int _largestChainLength = 7;
const int _largestFirstIndex = 2000;
const int _largestEntryCount = 5000;

enum _Tampering { changeHash, changePreviousHash, renumber, swap, duplicate }

AuditEntry _buildEntry({
  required Random random,
  required int index,
  required String previousHash,
  required String hash,
}) {
  return AuditEntry(
    index: index,
    at: randomUtcMoment(random),
    deviceId: DeviceId(randomText(random)),
    event: randomText(random),
    detail: randomText(random),
    previousHash: previousHash,
    hash: hash,
  );
}

AuditEntry _randomEntry(Random random) {
  return _buildEntry(
    random: random,
    index: random.nextInt(_largestFirstIndex),
    previousHash: randomText(random),
    hash: randomText(random),
  );
}

List<AuditEntry> _randomLinkedChain(Random random) {
  final int length = random.nextInt(_largestChainLength);
  final int oldestIndex = random.nextInt(_largestFirstIndex);
  final List<AuditEntry> oldestFirst = <AuditEntry>[];
  String previousHash = 'genesis-${randomText(random)}';
  for (int i = 0; i < length; i += 1) {
    final String hash = 'hash-$i-${randomText(random)}';
    oldestFirst.add(
      _buildEntry(
        random: random,
        index: oldestIndex + i,
        previousHash: previousHash,
        hash: hash,
      ),
    );
    previousHash = hash;
  }
  return oldestFirst.reversed.toList();
}

AuditEntry _copyEntry(
  AuditEntry entry, {
  required int index,
  required String previousHash,
  required String hash,
}) {
  return AuditEntry(
    index: index,
    at: entry.at,
    deviceId: entry.deviceId,
    event: entry.event,
    detail: entry.detail,
    previousHash: previousHash,
    hash: hash,
  );
}

List<AuditEntry> _tamper(Random random, List<AuditEntry> chain) {
  final List<AuditEntry> tampered = List<AuditEntry>.of(chain);
  if (tampered.isEmpty) {
    return tampered;
  }
  final int position = random.nextInt(tampered.length);
  final AuditEntry entry = tampered[position];
  final String changedText = 'tampered-${randomText(random)}';
  switch (pickOne(random, _Tampering.values)) {
    case _Tampering.changeHash:
      tampered[position] = _copyEntry(
        entry,
        index: entry.index,
        previousHash: entry.previousHash,
        hash: changedText,
      );
    case _Tampering.changePreviousHash:
      tampered[position] = _copyEntry(
        entry,
        index: entry.index,
        previousHash: changedText,
        hash: entry.hash,
      );
    case _Tampering.renumber:
      tampered[position] = _copyEntry(
        entry,
        index: entry.index + 1 + random.nextInt(3),
        previousHash: entry.previousHash,
        hash: entry.hash,
      );
    case _Tampering.swap:
      final int other = random.nextInt(tampered.length);
      tampered[position] = tampered[other];
      tampered[other] = entry;
    case _Tampering.duplicate:
      tampered.insert(position, entry);
  }
  return tampered;
}

int? _findNewestBrokenIndex(List<AuditEntry> newestFirst) {
  for (int position = 1; position < newestFirst.length; position += 1) {
    final AuditEntry newer = newestFirst[position - 1];
    final AuditEntry older = newestFirst[position];
    final bool isLinked = newer.previousHash == older.hash;
    final bool isNext = newer.index == older.index + 1;
    if (!isLinked || !isNext) {
      return newer.index;
    }
  }
  return null;
}

ChainSummary _randomSummary(Random random) {
  return ChainSummary(
    entryCount: random.nextInt(_largestEntryCount),
    headHash: randomText(random),
  );
}

FakeAuditRepository _buildRepository(Random random, List<AuditEntry> entries) {
  return FakeAuditRepository(
    entries: entries,
    summary: _randomSummary(random),
  );
}

List<AuditEntry> _readEntries(FakeAuditRepository repository) {
  return repository.listEntries();
}

void main() {
  testListCopyProperties(
    const ListCopy<FakeAuditRepository, AuditEntry>(
      testNamePrefix: '${_typePrefix}_constructor_property_entries',
      seed: 63901,
      buildElement: _randomEntry,
      construct: _buildRepository,
      readList: _readEntries,
    ),
  );

  test('${_typePrefix}_list_entries_property_verifying_changes_'
      'nothing', () async {
    final Random random = seededRandom(63904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AuditEntry> chain = random.nextBool()
          ? _randomLinkedChain(random)
          : _tamper(random, _randomLinkedChain(random));
      final FakeAuditRepository repository = _buildRepository(random, chain);
      final List<AuditEntry> before = repository.listEntries();

      await isRefused(repository.verifyChain, isRefusal: refusesWithStateError);

      expect(identical(repository.listEntries(), before), isTrue);
      expect(repository.listEntries(), orderedEquals(chain));
    }
  });

  test('${_typePrefix}_list_entries_property_reading_does_not_notify', () {
    final Random random = seededRandom(63905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeAuditRepository repository = _buildRepository(
        random,
        _randomLinkedChain(random),
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);

      final List<AuditEntry> firstRead = repository.listEntries();
      final List<AuditEntry> secondRead = repository.listEntries();

      expect(identical(secondRead, firstRead), isTrue);
      expect(notifications.count, 0);
    }
  });

  test('${_typePrefix}_verify_chain_property_intact_chain_gives_the_'
      'summary', () async {
    final Random random = seededRandom(63906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChainSummary summary = _randomSummary(random);
      final FakeAuditRepository repository = FakeAuditRepository(
        entries: _randomLinkedChain(random),
        summary: summary,
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);

      final ChainSummary verified = await repository.verifyChain();

      expect(identical(verified, summary), isTrue);
      expect(notifications.count, 0);
    }
  });

  test('${_typePrefix}_verify_chain_property_refuses_exactly_the_broken_'
      'chains', () async {
    final Random random = seededRandom(63907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AuditEntry> chain = _tamper(
        random,
        _randomLinkedChain(random),
      );
      final int? brokenIndex = _findNewestBrokenIndex(chain);
      final FakeAuditRepository repository = _buildRepository(random, chain);

      if (brokenIndex == null) {
        await expectLater(repository.verifyChain(), completes);
      } else {
        await expectLater(
          repository.verifyChain(),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              matches(RegExp('\\b$brokenIndex\\b')),
            ),
          ),
        );
      }
    }
  });
}
