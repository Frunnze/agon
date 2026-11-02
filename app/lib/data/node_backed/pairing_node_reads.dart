import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

Future<node.PairingRequestScreen?> readPairingRequestWhileCurrent({
  required NodeCommandChannel channel,
  required String code,
  required bool Function(String code) isCurrentCode,
}) async {
  try {
    return await channel.execute(node.PairingRequestCommand(code: code));
  } on NodeCommandFailure catch (failure, stackTrace) {
    if (!isCurrentCode(code)) {
      return null;
    }
    Error.throwWithStackTrace(translateNodeFailure(failure), stackTrace);
  }
}

Future<String?> findApproverName({
  required NodeCommandChannel channel,
  required node.AccountSummary account,
}) async {
  final DeviceId? approverId = account.device.approvedBy;
  if (approverId == null) {
    return null;
  }

  final List<node.DeviceView> devices = await executeNodeCommand(
    channel,
    const node.ListDevicesCommand(),
  );
  return findDeviceName(devices, approverId);
}
