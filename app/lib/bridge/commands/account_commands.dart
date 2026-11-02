import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

final class StatusCommand implements NodeCommand<StatusView> {
  const StatusCommand();

  @override
  String get name => 'status';

  @override
  JsonObject get arguments => noArguments;

  @override
  StatusView decodeReply(Object? okValue) => StatusView.fromJson(okValue);
}

final class CreateAccountCommand implements NodeCommand<AccountSummary> {
  const CreateAccountCommand({
    required this.serverAddress,
    required this.setupCode,
    required this.deviceName,
    required this.role,
    required this.workspaceName,
  });

  final String serverAddress;
  final String setupCode;
  final String deviceName;
  final DeviceRole role;
  final String workspaceName;

  @override
  String get name => 'create_account';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'server_address': serverAddress,
      'setup_code': setupCode,
      'device_name': deviceName,
      'role': role.wireName,
      'workspace_name': workspaceName,
    };
  }

  @override
  AccountSummary decodeReply(Object? okValue) {
    return AccountSummary.fromJson(okValue);
  }
}

final class CreateHostedAccountCommand implements NodeCommand<AccountSummary> {
  const CreateHostedAccountCommand({
    required this.workspaceName,
    required this.deviceName,
    required this.role,
  });

  final String workspaceName;
  final String deviceName;
  final DeviceRole role;

  @override
  String get name => 'create_hosted_account';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_name': workspaceName,
      'device_name': deviceName,
      'role': role.wireName,
    };
  }

  @override
  AccountSummary decodeReply(Object? okValue) {
    return AccountSummary.fromJson(okValue);
  }
}

final class RetryServerCommand implements NodeCommand<ServerHealthView> {
  const RetryServerCommand();

  @override
  String get name => 'retry_server';

  @override
  JsonObject get arguments => noArguments;

  @override
  ServerHealthView decodeReply(Object? okValue) {
    return ServerHealthView.fromJson(okValue);
  }
}

final class StartServerBackupCommand implements NodeCommand<AppServersView> {
  const StartServerBackupCommand();

  @override
  String get name => 'start_server_backup';

  @override
  JsonObject get arguments => noArguments;

  @override
  AppServersView decodeReply(Object? okValue) {
    return AppServersView.fromJson(okValue);
  }
}

final class StopServerBackupCommand implements NodeCommand<AppServersView> {
  const StopServerBackupCommand();

  @override
  String get name => 'stop_server_backup';

  @override
  JsonObject get arguments => noArguments;

  @override
  AppServersView decodeReply(Object? okValue) {
    return AppServersView.fromJson(okValue);
  }
}

final class PollEventsCommand implements NodeCommand<EventsResponse> {
  const PollEventsCommand({required this.after});

  final int after;

  @override
  String get name => 'poll_events';

  @override
  JsonObject get arguments => <String, Object?>{'after': after};

  @override
  EventsResponse decodeReply(Object? okValue) {
    return EventsResponse.fromJson(okValue);
  }
}

final class ForgetThisDeviceCommand implements NodeCommand<void> {
  const ForgetThisDeviceCommand();

  @override
  String get name => 'forget_this_device';

  @override
  JsonObject get arguments => noArguments;

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}
