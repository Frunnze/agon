import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../fakes/support/notification_counter.dart';
import 'held_next_reply_transport.dart';
import 'simulated_approval_node.dart';

const String listApprovalsCommand = 'list_approvals';
const String _decideCommand = 'decide_approval';
const int _largestAddedCount = 5;

final class ApprovalRig {
  ApprovalRig() {
    repository.addListener(notifications.record);
  }

  final SimulatedApprovalNode node = SimulatedApprovalNode(
    thisDeviceId: 'approving-device',
  );
  final NotificationCounter notifications = NotificationCounter();
  late final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: _answerLikeTheRustNode,
  );
  late final NodeBackedApprovalRepository repository =
      NodeBackedApprovalRepository(
        channel: NodeCommandChannel(transport: transport),
      );
  String? listRefusal;

  void addApprovals(Random random) {
    final int count = random.nextInt(_largestAddedCount);
    for (int i = 0; i < count; i += 1) {
      node.addApprovalFromElsewhere(random);
    }
  }

  String _answerLikeTheRustNode(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final Object? commandName = command['command'];
    final String? refusal = listRefusal;
    if (commandName == listApprovalsCommand && refusal != null) {
      return encodeErrorReply(refusal);
    }

    final Object? approvalId = command['approval_id'];
    final bool isUnknown = !node.approvals.containsKey(approvalId);
    if (commandName == _decideCommand && isUnknown) {
      return encodeErrorReply('approval $approvalId was not found');
    }
    return node.answer(inputJson);
  }
}

List<String> listApprovalIdentifiers(List<ApprovalRequest> approvals) {
  return <String>[
    for (final ApprovalRequest approval in approvals) approval.id.value,
  ];
}

List<String> listPendingIdentifiers(SimulatedApprovalNode simulated) {
  return <String>[
    for (final MapEntry<String, Map<String, Object?>> entry
        in simulated.approvals.entries)
      if (entry.value['decision'] == null) entry.key,
  ];
}
