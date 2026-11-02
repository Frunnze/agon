import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

final class AccountArrival {
  AccountArrival({
    required NodeCommandChannel channel,
    required Listenable accountSignals,
  }) : _channel = channel,
       _accountSignals = accountSignals;

  final NodeCommandChannel _channel;
  final Listenable _accountSignals;
  final Completer<node.AccountSummary> _arrival =
      Completer<node.AccountSummary>();

  Future<node.AccountSummary> waitForAccount() {
    _accountSignals.addListener(_checkForAccount);
    return _arrival.future;
  }

  void _checkForAccount() {
    unawaited(_completeWhenAccountExists());
  }

  Future<void> _completeWhenAccountExists() async {
    final node.StatusView status = await executeNodeCommand(
      _channel,
      const node.StatusCommand(),
    );
    final node.AccountSummary? account = status.account;
    if (account == null || _arrival.isCompleted) {
      return;
    }

    _accountSignals.removeListener(_checkForAccount);
    _arrival.complete(account);
  }
}
