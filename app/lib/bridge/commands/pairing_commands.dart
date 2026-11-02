import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class StartPairingCommand implements NodeCommand<PairingRequestScreen> {
  const StartPairingCommand();

  @override
  String get name => 'start_pairing';

  @override
  JsonObject get arguments => noArguments;

  @override
  PairingRequestScreen decodeReply(Object? okValue) {
    return PairingRequestScreen.fromJson(okValue);
  }
}

final class PairingRequestCommand
    implements NodeCommand<PairingRequestScreen> {
  const PairingRequestCommand({required this.code});

  final String code;

  @override
  String get name => 'pairing_request';

  @override
  JsonObject get arguments => <String, Object?>{'code': code};

  @override
  PairingRequestScreen decodeReply(Object? okValue) {
    return PairingRequestScreen.fromJson(okValue);
  }
}

final class ApprovePairingCommand implements NodeCommand<void> {
  ApprovePairingCommand({
    required this.code,
    required List<WorkspaceId> workspaceIds,
  }) : workspaceIds = List<WorkspaceId>.unmodifiable(workspaceIds);

  final String code;
  final List<WorkspaceId> workspaceIds;

  @override
  String get name => 'approve_pairing';

  @override
  JsonObject get arguments {
    return <String, Object?>{'code': code, 'workspace_ids': workspaceIds};
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class RejectPairingCommand implements NodeCommand<void> {
  const RejectPairingCommand({required this.code});

  final String code;

  @override
  String get name => 'reject_pairing';

  @override
  JsonObject get arguments => <String, Object?>{'code': code};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class CancelPairingCommand implements NodeCommand<void> {
  const CancelPairingCommand({required this.code});

  final String code;

  @override
  String get name => 'cancel_pairing';

  @override
  JsonObject get arguments => <String, Object?>{'code': code};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class JoinWithCodeCommand implements NodeCommand<PendingJoin> {
  const JoinWithCodeCommand({
    required this.serverAddress,
    required this.code,
    required this.deviceName,
    required this.role,
  });

  final String? serverAddress;
  final String code;
  final String deviceName;
  final DeviceRole role;

  @override
  String get name => 'join_with_code';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'server_address': serverAddress,
      'code': code,
      'device_name': deviceName,
      'role': role.wireName,
    };
  }

  @override
  PendingJoin decodeReply(Object? okValue) => PendingJoin.fromJson(okValue);
}

final class JoinStatusCommand implements NodeCommand<JoinStatusView> {
  const JoinStatusCommand();

  @override
  String get name => 'join_status';

  @override
  JsonObject get arguments => noArguments;

  @override
  JoinStatusView decodeReply(Object? okValue) {
    return JoinStatusView.fromJson(okValue);
  }
}
