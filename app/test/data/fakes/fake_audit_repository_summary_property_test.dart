import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_device_node.dart';
import '../node_backed/support/simulated_work_node.dart';

const String _typePrefix = 'test_fake_audit_repository_verify_chain';
const String _rustGenesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';
const String _thisDeviceText = 'this-device';
const int _largestChainLength = 7;
const int _largestFirstIndex = 2000;
const int _sequenceIterations = 60;

List<AuditEntry> _randomLinkedChain(Random random, {required int firstIndex}) {
  final int length = 1 + random.nextInt(_largestChainLength);
  final List<AuditEntry> newestFirst = <AuditEntry>[];
  String previousHash = '${randomText(random)}-before';
  for (int i = 0; i < length; i += 1) {
    final String hash = 'hash-$i-${randomText(random)}';
    final AuditEntry entry = AuditEntry(
      index: firstIndex + i,
      at: randomUtcMoment(random),
      deviceId: DeviceId(randomText(random)),
      event: randomText(random),
      detail: randomText(random),
      previousHash: previousHash,
      hash: hash,
    );
    newestFirst.insert(0, entry);
    previousHash = hash;
  }
  return newestFirst;
}

void _linkSimulatedChain(Random random, List<WireRecord> chain) {
  String previousHash = _rustGenesisHash;
  for (final WireRecord entry in chain) {
    final String hash = 'hash-${entry['index']}-${randomText(random)}';
    entry['previous_hash'] = previousHash;
    entry['hash'] = hash;
    previousHash = hash;
  }
}

void main() {
  test('${_typePrefix}_property_summary_matches_the_newest_entry', () async {
    final Random random = seededRandom(66501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AuditEntry> chain = _randomLinkedChain(
        random,
        firstIndex: random.nextInt(_largestFirstIndex),
      );
      final FakeAuditRepository repository = FakeAuditRepository(
        entries: chain,
      );

      final ChainSummary summary = await repository.verifyChain();

      expect(summary.headHash, chain.first.hash);
      expect(summary.entryCount, chain.first.index + 1);
    }
  });

  test('${_typePrefix}_property_a_whole_chain_counts_its_entries', () async {
    final Random random = seededRandom(66502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AuditEntry> chain = random.nextInt(5) == 0
          ? const <AuditEntry>[]
          : _randomLinkedChain(random, firstIndex: 0);
      final FakeAuditRepository repository = FakeAuditRepository(
        entries: chain,
      );

      final ChainSummary summary = await repository.verifyChain();

      expect(summary.entryCount, chain.length);
      expect(
        summary.headHash,
        chain.isEmpty ? _rustGenesisHash : chain.first.hash,
      );
    }
  });

  test('${_typePrefix}_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(66503);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SimulatedDeviceNode simulated = SimulatedDeviceNode(
        thisDeviceId: _thisDeviceText,
      );
      final int length = 1 + random.nextInt(_largestChainLength);
      for (int entry = 0; entry < length; entry += 1) {
        simulated.appendAuditEntry(random);
      }
      _linkSimulatedChain(random, simulated.auditChain);
      final NodeBackedAuditRepository nodeBacked = NodeBackedAuditRepository(
        channel: buildSimulatedChannel(simulated.answer),
      );
      await nodeBacked.load();
      final FakeAuditRepository fake = FakeAuditRepository(
        entries: nodeBacked.listEntries(),
      );

      final ChainSummary fromFake = await fake.verifyChain();
      final ChainSummary fromNode = await nodeBacked.verifyChain();

      expect(fromFake.entryCount, fromNode.entryCount);
      expect(fromFake.headHash, fromNode.headHash);
    }
  });
}
