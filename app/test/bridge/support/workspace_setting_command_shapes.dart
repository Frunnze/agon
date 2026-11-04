import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';

const List<CommandShape> workspaceSettingCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'change_workspace_approval_policy',
    argumentFields: <String>{'workspace_id', 'approval_policy'},
    buildCommand: _buildChangeWorkspaceApprovalPolicy,
    buildReplyJson: randomWorkspaceJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildChangeWorkspaceApprovalPolicy(Random random) {
  return ChangeWorkspaceApprovalPolicyCommand(
    workspaceId: randomWorkspaceId(random),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
}
