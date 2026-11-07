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
  test('${_prefix}_apply_change_property_every_topic_reloads', () async {
    final Random random = seededRandom(76001);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = AuditRig();
      final int topicCount = 1 + random.nextInt(_longestSequence);

      for (int topic = 0; topic < topicCount; topic += 1) {
        rig.appendLinkedEntries(random);
        await rig.repository.applyChange(randomAuditTopic(random));

        expect(
          listEntryHashes(rig.repository.listEntries()),
          rig.listNodeHashesNewestFirst(),
        );
      }
    }
  });

  test('${_prefix}_apply_change_property_notifies_once_per_topic', () async {
    final Random random = seededRandom(76002);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = AuditRig();
      final int topicCount = random.nextInt(_longestSequence);

      for (int topic = 0; topic < topicCount; topic += 1) {
        await rig.repository.applyChange(randomAuditTopic(random));
      }

      expect(rig.notifications.count, topicCount);
    }
  });

  test('${_prefix}_apply_change_property_late_older_reply_loses', () async {
    final Random random = seededRandom(76003);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      rig.transport.holdNextReply(listAuditCommand);
      final Future<void> olderChange = rig.repository.applyChange(
        randomAuditTopic(random),
      );
      await rig.transport.heldReplyArrival;
      rig.appendLinkedEntries(random);

      await rig.repository.applyChange(randomAuditTopic(random));
      rig.transport.releaseHeldReply();
      await olderChange;

      expect(
        listEntryHashes(rig.repository.listEntries()),
        rig.listNodeHashesNewestFirst(),
      );
    }
  });

  test('${_prefix}_verify_chain_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(76004);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AuditRig rig = AuditRig();
      rig.appendLinkedEntries(random);

      final ChainSummary fromNode = await rig.repository.verifyChain();
      final FakeAuditRepository fake = FakeAuditRepository(
        entries: rig.repository.listEntries(),
      );
      final ChainSummary fromFake = await fake.verifyChain();

      expect(fromNode.entryCount, fromFake.entryCount);
      expect(fromNode.headHash, fromFake.headHash);
      expect(fromNode.entryCount, rig.node.auditChain.length);
    }
  });

  test('${_prefix}_verify_chain_property_broken_chain_still_lists', () async {
    final Random random = seededRandom(76005);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      rig.appendLinkedEntries(random);
      rig.node.isAuditIntact = false;

      await expectLater(rig.repository.verifyChain(), throwsStateError);

      expect(
        listEntryHashes(rig.repository.listEntries()),
        rig.listNodeHashesNewestFirst(),
      );
    }
  });

  test('${_prefix}_verify_chain_property_refusal_is_a_state_error', () async {
    final Random random = seededRandom(76006);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      final List<AuditEntry> before = rig.repository.listEntries();
      rig.listRefusal = 'the app server answered 502: ${randomText(random)}';

      await expectLater(rig.repository.verifyChain(), throwsStateError);

      expect(rig.repository.listEntries(), same(before));
    }
  });

  test('${_prefix}_fetch_audit_property_newest_started_fetch_wins', () async {
    final Random random = seededRandom(76007);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      rig.transport.holdNextReply(listAuditCommand);
      final Future<void> olderCheck = rig.repository.verifyChain();
      await rig.transport.heldReplyArrival;
      rig.appendLinkedEntries(random);

      await rig.repository.load();
      rig.transport.releaseHeldReply();
      await olderCheck;

      expect(
        listEntryHashes(rig.repository.listEntries()),
        rig.listNodeHashesNewestFirst(),
      );
    }
  });

  test(
    '${_prefix}_fetch_audit_property_stale_reply_does_not_notify',
    () async {
      final Random random = seededRandom(76008);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final AuditRig rig = await _buildLoadedRig(random);
        rig.transport.holdNextReply(listAuditCommand);
        final Future<void> olderLoad = rig.repository.load();
        await rig.transport.heldReplyArrival;
        await rig.repository.load();
        final int notifiedBefore = rig.notifications.count;

        rig.transport.releaseHeldReply();
        await olderLoad;

        expect(rig.notifications.count, notifiedBefore);
      }
    },
  );

  test('${_prefix}_fetch_audit_property_keeps_working_after_stale', () async {
    final Random random = seededRandom(76009);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final AuditRig rig = await _buildLoadedRig(random);
      rig.transport.holdNextReply(listAuditCommand);
      final Future<void> olderLoad = rig.repository.load();
      await rig.transport.heldReplyArrival;
      await rig.repository.load();
      rig.transport.releaseHeldReply();
      await olderLoad;
      rig.appendLinkedEntries(random);

      await rig.repository.load();

      expect(
        listEntryHashes(rig.repository.listEntries()),
        rig.listNodeHashesNewestFirst(),
      );
    }
  });
}
