import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/agent_login_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/background_node_work.dart';
import 'package:agent_orchestration/data/node_backed/fetch_sequence.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed/node_command_execution.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';

final class NodeBackedAgentLoginRepository extends ChangeNotifier
    implements AgentLoginRepository {
  NodeBackedAgentLoginRepository({
    required NodeCommandChannel channel,
    required Duration pollInterval,
  }) : _channel = channel,
       _pollInterval = pollInterval;

  final NodeCommandChannel _channel;
  final Duration _pollInterval;
  final FetchSequence _statusChecks = FetchSequence();
  final FetchSequence _terminalReads = FetchSequence();
  AgentLoginStatus? _status;
  LoginTerminal? _terminal;
  int _openedTerminals = 0;

  @override
  AgentLoginStatus? findStatus() => _status;

  @override
  LoginTerminal? findTerminal() => _terminal;

  @override
  Future<void> checkStatus() async {
    final int check = _statusChecks.startFetch();
    final node.AgentLoginStatusView view = await executeNodeCommand(
      _channel,
      const node.AgentLoginStatusCommand(),
    );
    if (!_statusChecks.acceptIfNewest(check)) {
      return;
    }

    _status = mapAgentLoginStatusFromNode(view);
    notifyListeners();
  }

  @override
  Future<void> openTerminal(AgentPlace place) async {
    await executeNodeCommand(
      _channel,
      node.StartAgentLoginCommand(place: mapAgentPlaceToNode(place)),
    );
    _openedTerminals += 1;
    final int openedTerminal = _openedTerminals;
    await _readTerminal();
    startBackgroundNodeWork(() => _followTerminal(openedTerminal));
  }

  @override
  Future<void> typeIntoTerminal(String keys) async {
    await executeNodeCommand(_channel, node.TypeAgentLoginCommand(keys: keys));
    await _readTerminal();
  }

  @override
  Future<void> closeTerminal() async {
    _openedTerminals += 1;
    _terminal = null;
    notifyListeners();
    await executeNodeCommand(_channel, const node.StopAgentLoginCommand());
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    await executeNodeCommand(
      _channel,
      node.SaveAgentApiKeyCommand(apiKey: apiKey),
    );
    await checkStatus();
  }

  @override
  Future<void> forgetCredential() async {
    await executeNodeCommand(
      _channel,
      const node.ForgetAgentCredentialCommand(),
    );
    await checkStatus();
  }

  Future<void> _followTerminal(int openedTerminal) async {
    while (_isFollowing(openedTerminal)) {
      await Future<void>.delayed(_pollInterval);
      if (openedTerminal != _openedTerminals) {
        return;
      }
      await _readTerminal();
    }
    if (openedTerminal != _openedTerminals) {
      return;
    }

    if (_terminal?.state == LoginTerminalState.finished) {
      await closeTerminal();
    }
    await checkStatus();
  }

  bool _isFollowing(int openedTerminal) {
    final bool isCurrent = openedTerminal == _openedTerminals;
    return isCurrent && _terminal?.state == LoginTerminalState.running;
  }

  Future<void> _readTerminal() async {
    final int readTerminal = _openedTerminals;
    final int read = _terminalReads.startFetch();
    final node.AgentLoginView? view = await executeNodeCommand(
      _channel,
      const node.ReadAgentLoginCommand(),
    );
    if (readTerminal != _openedTerminals) {
      return;
    }
    if (!_terminalReads.acceptIfNewest(read)) {
      return;
    }

    _terminal = view == null ? null : mapLoginTerminalFromNode(view);
    notifyListeners();
  }
}
