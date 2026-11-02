import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListRunnersCommand implements NodeCommand<RunnersView> {
  const ListRunnersCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_runners';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  RunnersView decodeReply(Object? okValue) => RunnersView.fromJson(okValue);
}

final class PauseRunnerCommand implements NodeCommand<void> {
  const PauseRunnerCommand({required this.deviceId});

  final DeviceId deviceId;

  @override
  String get name => 'pause_runner';

  @override
  JsonObject get arguments => <String, Object?>{'device_id': deviceId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ChooseAgentPlaceCommand implements NodeCommand<void> {
  const ChooseAgentPlaceCommand({required this.place});

  final AgentPlace place;

  @override
  String get name => 'choose_agent_place';

  @override
  JsonObject get arguments => <String, Object?>{'place': place.wireName};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ResumeRunnerCommand implements NodeCommand<void> {
  const ResumeRunnerCommand({required this.deviceId});

  final DeviceId deviceId;

  @override
  String get name => 'resume_runner';

  @override
  JsonObject get arguments => <String, Object?>{'device_id': deviceId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}
