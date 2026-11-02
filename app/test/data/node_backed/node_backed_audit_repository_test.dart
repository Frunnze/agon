import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_device_node.dart';

const int _sequenceIterations = 25;
const int _largestNewEntries = 4;

typedef _Fixture = ({
  SimulatedDeviceNode node,
  NodeBackedAuditRepository repository,
});

_Fixture _buildFixture() {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: 'me',
  );
  final NodeBackedAuditRepository repository = NodeBackedAuditRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
  return (node: simulated, repository: repository);
}

final class _HeldReplyTransport implements NodeTransport {
  _HeldReplyTransport({required this.node});

  final SimulatedDeviceNode node;
  final List<Completer<String>> _heldReplies = <Completer<String>>[];
  final List<String> _answers = <String>[];

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) {
    final Completer<String> reply = Completer<String>();
    _answers.add(node.answer(inputJson));
    _heldReplies.add(reply);
    return reply.future;
  }

  @override
  Future<String> stop() async => '';

  void releaseNewestFirst() {
    for (int i = _heldReplies.length - 1; i >= 0; i -= 1) {
      _heldReplies[i].complete(_answers[i]);
    }
    _heldReplies.clear();
    _answers.clear();
  }
}

node.ChangeTopic _randomTopic(Random random) {
  if (random.nextBool()) {
    return node.RunChanged(runId: RunId(randomText(random)));
  }
  return node.AreaChanged(area: pickOne(random, node.ChangeArea.values));
}

void main() {
  test(
    'test_apply_change_property_every_topic_reloads_newest_first',
    () async {
      final Random random = seededRandom(9961);
      final _Fixture fixture = _buildFixture();
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final int newEntries = random.nextInt(_largestNewEntries);
        for (int entry = 0; entry < newEntries; entry += 1) {
          fixture.node.appendAuditEntry(random);
        }

        await fixture.repository.applyChange(_randomTopic(random));

        final List<AuditEntry> entries = fixture.repository.listEntries();
        expect(entries.map((AuditEntry entry) => entry.index), <Object?>[
          for (final Map<String, Object?> entry
              in fixture.node.auditChain.reversed)
            entry['index'],
        ]);
      }
    },
  );

  test('test_verify_chain_property_intact_chain_gives_summary', () async {
    final Random random = seededRandom(9962);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      fixture.node.appendAuditEntry(random);
      fixture.node.isAuditIntact = true;

      final ChainSummary summary = await fixture.repository.verifyChain();

      expect(summary.entryCount, fixture.node.auditChain.length);
      expect(summary.headHash, fixture.node.auditChain.last['hash']);
      expect(fixture.repository.listEntries().length, summary.entryCount);
    }
  });

  test('test_verify_chain_property_broken_chain_is_refused', () async {
    final Random random = seededRandom(9963);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      fixture.node.appendAuditEntry(random);
      fixture.node.isAuditIntact = false;

      await expectLater(fixture.repository.verifyChain(), throwsStateError);
    }
  });

  test(
    'test_apply_change_property_late_older_reply_keeps_newer_entries',
    () async {
      final Random random = seededRandom(9964);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SimulatedDeviceNode simulated = SimulatedDeviceNode(
          thisDeviceId: 'me',
        );
        final _HeldReplyTransport transport = _HeldReplyTransport(
          node: simulated,
        );
        final NodeBackedAuditRepository repository = NodeBackedAuditRepository(
          channel: NodeCommandChannel(transport: transport),
        );
        simulated.appendAuditEntry(random);

        final Future<void> olderFetch = repository.applyChange(
          _randomTopic(random),
        );
        final int newEntries = 1 + random.nextInt(_largestNewEntries);
        for (int entry = 0; entry < newEntries; entry += 1) {
          simulated.appendAuditEntry(random);
        }
        final Future<ChainSummary> newerCheck = repository.verifyChain();
        transport.releaseNewestFirst();
        await olderFetch;
        final ChainSummary summary = await newerCheck;

        expect(summary.entryCount, simulated.auditChain.length);
        expect(repository.listEntries().length, summary.entryCount);
      }
    },
  );
}
