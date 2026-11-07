import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';

const int _settlingTurns = 20;
const String _commandField = 'command';
const String _accountField = 'account';
const List<String> _missingRecordKinds = <String>['account', 'device'];

enum StatusReplyKind { withAccount, withoutAccount, nodeProblem }

final class SignalSource extends ChangeNotifier {
  void signal() => notifyListeners();
}

final class HeldNodeReply {
  HeldNodeReply({required this.inputJson});

  final String inputJson;
  final Completer<String> _reply = Completer<String>();

  bool get isAnswered => _reply.isCompleted;

  Future<String> get arrivingReply => _reply.future;

  String readCommandName() {
    final JsonObject command = decodeObject(jsonDecode(inputJson));
    return readField(command, _commandField, decodeText);
  }

  void answer(String replyJson) => _reply.complete(replyJson);
}

final class HeldNodeTransport implements NodeTransport {
  final List<HeldNodeReply> heldReplies = <HeldNodeReply>[];

  late final NodeCommandChannel channel = NodeCommandChannel(transport: this);

  List<HeldNodeReply> listUnanswered() {
    return <HeldNodeReply>[
      for (final HeldNodeReply held in heldReplies)
        if (!held.isAnswered) held,
    ];
  }

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) {
    final HeldNodeReply held = HeldNodeReply(inputJson: inputJson);
    heldReplies.add(held);
    return held.arrivingReply;
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a held node transport is never stopped');
  }
}

final class StatusReply {
  const StatusReply({required this.replyJson, required this.accountJson});

  final String replyJson;
  final Map<String, Object?>? accountJson;
}

StatusReply buildStatusReply(Random random, StatusReplyKind kind) {
  return switch (kind) {
    StatusReplyKind.withAccount => _buildStatusReplyWithAccount(
      random,
      randomAccountSummaryJson(random),
    ),
    StatusReplyKind.withoutAccount => _buildStatusReplyWithAccount(
      random,
      null,
    ),
    StatusReplyKind.nodeProblem => StatusReply(
      replyJson: encodeErrorReply(_randomNodeProblem(random)),
      accountJson: null,
    ),
  };
}

StatusReply _buildStatusReplyWithAccount(
  Random random,
  Map<String, Object?>? accountJson,
) {
  final Map<String, Object?> statusJson = randomStatusViewJson(random);
  statusJson[_accountField] = accountJson;
  return StatusReply(
    replyJson: encodeSuccessReply(statusJson),
    accountJson: accountJson,
  );
}

String _randomNodeProblem(Random random) {
  if (random.nextBool()) {
    final String kind = pickOne(random, _missingRecordKinds);
    return '$kind ${randomUuidText(random)} was not found';
  }
  return 'the app server is unreachable ${randomText(random)}';
}

void signalCatchingEscapes(SignalSource source, List<Object> escaped) {
  runZonedGuarded(
    source.signal,
    (Object problem, StackTrace _) => escaped.add(problem),
  );
}

Future<void> settleAccountChecks() async {
  for (int turn = 0; turn < _settlingTurns; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

String describeAccount(node.AccountSummary? account) {
  return jsonEncode(account?.toJson());
}

String describeAccountJson(Map<String, Object?>? accountJson) {
  if (accountJson == null) {
    return jsonEncode(null);
  }
  return describeAccount(node.AccountSummary.fromJson(accountJson));
}
