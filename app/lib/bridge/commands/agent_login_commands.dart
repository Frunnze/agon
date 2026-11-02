import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

final class AgentLoginStatusCommand
    implements NodeCommand<AgentLoginStatusView> {
  const AgentLoginStatusCommand();

  @override
  String get name => 'agent_login_status';

  @override
  JsonObject get arguments => noArguments;

  @override
  AgentLoginStatusView decodeReply(Object? okValue) {
    return AgentLoginStatusView.fromJson(okValue);
  }
}

final class StartAgentLoginCommand implements NodeCommand<void> {
  const StartAgentLoginCommand({required this.place});

  final AgentPlace place;

  @override
  String get name => 'start_agent_login';

  @override
  JsonObject get arguments => <String, Object?>{'place': place.wireName};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ReadAgentLoginCommand implements NodeCommand<AgentLoginView?> {
  const ReadAgentLoginCommand();

  @override
  String get name => 'read_agent_login';

  @override
  JsonObject get arguments => noArguments;

  @override
  AgentLoginView? decodeReply(Object? okValue) {
    return decodeOptionalAgentLogin(okValue);
  }
}

final class TypeAgentLoginCommand implements NodeCommand<void> {
  const TypeAgentLoginCommand({required this.keys});

  final String keys;

  @override
  String get name => 'type_agent_login';

  @override
  JsonObject get arguments => <String, Object?>{'keys': keys};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class StopAgentLoginCommand implements NodeCommand<void> {
  const StopAgentLoginCommand();

  @override
  String get name => 'stop_agent_login';

  @override
  JsonObject get arguments => noArguments;

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class SaveAgentApiKeyCommand implements NodeCommand<void> {
  const SaveAgentApiKeyCommand({required this.apiKey});

  final String apiKey;

  @override
  String get name => 'save_agent_api_key';

  @override
  JsonObject get arguments => <String, Object?>{'api_key': apiKey};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ForgetAgentCredentialCommand implements NodeCommand<void> {
  const ForgetAgentCredentialCommand();

  @override
  String get name => 'forget_agent_credential';

  @override
  JsonObject get arguments => noArguments;

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}
