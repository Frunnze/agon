import 'dart:convert';
import 'dart:math';

import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import 'simulated_work_node.dart';

const String _decisionField = 'decision';
const String _identifierPrefix = 'approval-';

final class SimulatedApprovalNode {
  SimulatedApprovalNode({required this.thisDeviceId});

  final String thisDeviceId;
  final Map<String, WireRecord> approvals = <String, WireRecord>{};
  final List<String> receivedCommands = <String>[];
  int _createdCount = 0;

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String name = command['command']! as String;
    receivedCommands.add(name);
    return switch (name) {
      'list_approvals' => encodeSuccessReply(_listApprovals()),
      'decide_approval' => _decideApproval(command),
      _ => encodeErrorReply('unknown command: $name'),
    };
  }

  String addApprovalFromElsewhere(Random random) {
    final WireRecord approval = randomApprovalRequestJson(random);
    _createdCount += 1;
    final String approvalId = '$_identifierPrefix$_createdCount';
    approval['id'] = approvalId;
    approvals[approvalId] = approval;
    return approvalId;
  }

  WireRecord _listApprovals() {
    final List<Object?> views = <Object?>[
      for (final WireRecord approval in approvals.values)
        <String, Object?>{
          'approval': approval,
          'description': '',
          'is_waiting': approval[_decisionField] == null,
        },
    ];
    return <String, Object?>{'waiting_count': 0, 'approvals': views};
  }

  String _decideApproval(WireRecord command) {
    final WireRecord? approval = approvals[command['approval_id']];
    if (approval == null) {
      return encodeErrorReply('approval ${command['approval_id']} not found');
    }
    if (approval[_decisionField] != null) {
      return encodeErrorReply('the approval is already decided');
    }
    approval[_decisionField] = <String, Object?>{
      _decisionField: command[_decisionField],
      'decided_by': thisDeviceId,
      'decided_at': simulatedMoment,
      'signature': <Object?>[1, 2, 3],
    };
    return encodeSuccessReply(null);
  }
}
