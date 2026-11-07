import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/notification_counter.dart';
import 'held_next_reply_transport.dart';
import 'simulated_device_node.dart';

const String listAuditCommand = 'list_audit';
const String genesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';
const int _largestAppendedCount = 4;

final class AuditRig {
  AuditRig() {
    repository.addListener(notifications.record);
  }

  final SimulatedDeviceNode node = SimulatedDeviceNode(
    thisDeviceId: 'auditing-device',
  );
  final NotificationCounter notifications = NotificationCounter();
  late final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: _answer,
  );
  late final NodeBackedAuditRepository repository = NodeBackedAuditRepository(
    channel: NodeCommandChannel(transport: transport),
  );
  String? listRefusal;

  void appendLinkedEntries(Random random) {
    final int count = random.nextInt(_largestAppendedCount);
    for (int i = 0; i < count; i += 1) {
      final List<Map<String, Object?>> chain = node.auditChain;
      final Object? previousHash = chain.isEmpty
          ? genesisHash
          : chain.last['hash'];
      node.appendAuditEntry(random);
      chain.last['previous_hash'] = previousHash;
      chain.last['hash'] = 'hash-${chain.length}-${random.nextInt(1 << 30)}';
    }
  }

  List<Object?> listNodeHashesNewestFirst() {
    return <Object?>[
      for (final Map<String, Object?> entry in node.auditChain.reversed)
        entry['hash'],
    ];
  }

  String _answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String? refusal = listRefusal;
    if (command['command'] == listAuditCommand && refusal != null) {
      return encodeErrorReply(refusal);
    }
    return node.answer(inputJson);
  }
}

List<Object?> listEntryHashes(List<AuditEntry> entries) {
  return <Object?>[for (final AuditEntry entry in entries) entry.hash];
}

node.ChangeTopic randomAuditTopic(Random random) {
  if (random.nextBool()) {
    return node.RunChanged(runId: RunId(randomText(random)));
  }
  return node.AreaChanged(area: pickOne(random, node.ChangeArea.values));
}
