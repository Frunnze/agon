import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_device_node.dart';

const String _rustGenesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';
const int _sequenceIterations = 40;

NodeBackedAuditRepository _buildNodeBacked(SimulatedDeviceNode simulated) {
  return NodeBackedAuditRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
}

void main() {
  test(
    'test_fake_audit_repository_verify_chain_property_an_empty_chain_agrees_'
    'with_the_node_backed_repository',
    () async {
      final Random random = seededRandom(64501);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SimulatedDeviceNode simulated = SimulatedDeviceNode(
          thisDeviceId: randomText(random),
        );
        final NodeBackedAuditRepository nodeBacked = _buildNodeBacked(
          simulated,
        );
        await nodeBacked.load();
        final FakeAuditRepository fake = FakeAuditRepository(
          entries: nodeBacked.listEntries(),
        );

        final ChainSummary fromFake = await fake.verifyChain();
        final ChainSummary fromNode = await nodeBacked.verifyChain();

        expect(fromNode.headHash, _rustGenesisHash);
        expect(fromFake.headHash, fromNode.headHash);
        expect(fromFake.entryCount, fromNode.entryCount);
      }
    },
  );

  test('test_fake_audit_repository_verify_chain_property_the_node_backed_head_'
      'leaves_genesis_once_entries_exist', () async {
    final Random random = seededRandom(64502);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SimulatedDeviceNode simulated = SimulatedDeviceNode(
        thisDeviceId: randomText(random),
      );
      final NodeBackedAuditRepository nodeBacked = _buildNodeBacked(simulated);
      final ChainSummary empty = await nodeBacked.verifyChain();
      simulated.appendAuditEntry(random);

      final ChainSummary filled = await nodeBacked.verifyChain();

      expect(empty.headHash, _rustGenesisHash);
      expect(empty.entryCount, 0);
      expect(filled.headHash, simulated.auditChain.last['hash']);
      expect(filled.entryCount, 1);
    }
  });
}
