import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/notification_counter.dart';
import 'held_next_reply_transport.dart';
import 'pairing_repository_harness.dart';
import 'simulated_node_replies.dart';
import 'simulated_pairing_node.dart';

const String endedPairingSessionMessage =
    'the app server answered 404: the pairing session ended';
const Duration rigPairingLifetime = Duration(minutes: 5);
const Duration _rigPollInterval = Duration(milliseconds: 1);
const int _survivalIterations = 15;
const String startPairingCommand = 'start_pairing';
const String pairingRequestCommand = 'pairing_request';
const String approvePairingCommand = 'approve_pairing';
const String rejectPairingCommand = 'reject_pairing';
const String cancelPairingCommand = 'cancel_pairing';
const String joinWithCodeCommand = 'join_with_code';
const String joinStatusCommand = 'join_status';
const Set<String> _closingCommands = <String>{
  approvePairingCommand,
  rejectPairingCommand,
  cancelPairingCommand,
};
const Set<String> _sessionCommands = <String>{
  pairingRequestCommand,
  ..._closingCommands,
};

const List<String> _badNameSamples = <String>[
  '',
  'Laptop',
  'my laptop',
  'café',
  'tab\tname',
  'UPPER-case',
];

typedef SimulatedReply = Map<String, Object?>;

final class FreshCodePairingNode {
  FreshCodePairingNode({required this.simulated, required this.clock});

  final SimulatedPairingNode simulated;
  final Clock clock;
  final List<String> commandNames = <String>[];
  final List<Object?> sentCodes = <Object?>[];
  final Set<String> failingCommands = <String>{};
  final Set<String> _endedCodes = <String>{};
  int startCount = 0;

  String get currentCode => 'K${startCount}Q';

  String get currentDisplayCode => 'K-${startCount}Q';

  int countCommands(String commandName) {
    int count = 0;
    for (final String sentName in commandNames) {
      if (sentName == commandName) {
        count += 1;
      }
    }
    return count;
  }

  String answer(String inputJson) {
    final SimulatedCommand command = jsonDecode(inputJson) as SimulatedCommand;
    final String commandName = command['command']! as String;
    commandNames.add(commandName);
    if (failingCommands.contains(commandName)) {
      return encodeErrorReply(simulatedOutageMessage);
    }
    if (commandName == startPairingCommand) {
      return _startPairing(inputJson);
    }
    if (!_sessionCommands.contains(commandName)) {
      return simulated.answer(inputJson);
    }
    return _answerSessionCommand(command, commandName);
  }

  String _startPairing(String inputJson) {
    startCount += 1;
    simulated.cancelledCodes.clear();
    final SimulatedReply reply =
        jsonDecode(simulated.answer(inputJson)) as SimulatedReply;
    final SimulatedReply screen = reply['ok']! as SimulatedReply;
    final DateTime now = clock.now();
    screen['started_at'] = now.toIso8601String();
    screen['expires_at'] = now.add(rigPairingLifetime).toIso8601String();
    return _renameCode(reply);
  }

  String _answerSessionCommand(SimulatedCommand command, String commandName) {
    final Object? code = command['code'];
    sentCodes.add(code);
    final bool isOpenCode =
        code == currentCode && !_endedCodes.contains(currentCode);
    if (!isOpenCode) {
      return encodeErrorReply(endedPairingSessionMessage);
    }

    command['code'] = simulatedPairingCode;
    final SimulatedReply reply =
        jsonDecode(simulated.answer(jsonEncode(command))) as SimulatedReply;
    final bool isAnswered = reply.containsKey('ok');
    if (isAnswered && _closingCommands.contains(commandName)) {
      _endedCodes.add(currentCode);
    }
    if (isAnswered && commandName == pairingRequestCommand) {
      return _renameCode(reply);
    }
    return jsonEncode(reply);
  }

  String _renameCode(SimulatedReply reply) {
    final SimulatedReply screen = reply['ok']! as SimulatedReply;
    screen['code'] = currentCode;
    screen['display_code'] = currentDisplayCode;
    return jsonEncode(reply);
  }
}

final class PairingRig {
  PairingRig({
    required this.node,
    required this.transport,
    required this.clock,
    required this.repository,
    required this.notifications,
  });

  final FreshCodePairingNode node;
  final HeldNextReplyTransport transport;
  final MovableClock clock;
  final NodeBackedPairingRepository repository;
  final NotificationCounter notifications;

  void dispose() {
    repository.removeListener(notifications.record);
    repository.dispose();
  }
}

PairingRig buildPairingRig({
  required int pollsBeforeJoin,
  int joinPollsBeforeAnswer = 0,
  String joinAnswer = 'approved',
  List<String> runnerLabels = pairingRunnerLabels,
}) {
  final MovableClock clock = MovableClock(pairingStart);
  final FreshCodePairingNode node = FreshCodePairingNode(
    simulated: buildPairingNode(
      pollsBeforeJoin: pollsBeforeJoin,
      joinPollsBeforeAnswer: joinPollsBeforeAnswer,
      joinAnswer: joinAnswer,
    ),
    clock: clock,
  );
  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: node.answer,
  );
  final NodeBackedPairingRepository repository = NodeBackedPairingRepository(
    channel: NodeCommandChannel(transport: transport),
    clock: clock,
    pollInterval: _rigPollInterval,
    runnerLabels: runnerLabels,
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return PairingRig(
    node: node,
    transport: transport,
    clock: clock,
    repository: repository,
    notifications: notifications,
  );
}

Future<void> startAndWaitForRequest(PairingRig rig) async {
  await rig.repository.startPairing();
  await waitUntil(() => rig.repository.findPendingRequest() != null);
}

Future<void> waitForPolls(int pollCount) {
  return Future<void>.delayed(pairingWaitStep * pollCount);
}

String randomBadName(Random random) {
  final String candidate = pickOne(random, <String>[
    pickOne(random, _badNameSamples),
    randomText(random),
    'a' * (nameMaximumLength + 1 + random.nextInt(5)),
  ]);
  if (describeNameProblem(candidate) == null) {
    return '$candidate!';
  }
  return candidate;
}

String _reportNotRefused(Object? outcome) {
  fail('the attempt was not refused: $outcome');
}

bool _isArgumentError(Object error) => error is ArgumentError;

String _describeArgumentError(Object error) {
  if (error is ArgumentError) {
    return '${error.message}';
  }
  return '$error';
}

Future<String> describeArgumentRefusal(Future<Object?> attempt) {
  final Future<String> notRefused = attempt.then(_reportNotRefused);
  return notRefused.catchError(_describeArgumentError, test: _isArgumentError);
}

Future<void> expectANewerSessionSurvives(
  Future<void> Function(PairingRig rig) decide,
  String commandName,
) async {
  for (int i = 0; i < _survivalIterations; i += 1) {
    final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
    await startAndWaitForRequest(rig);
    rig.transport.holdNextReply(commandName);
    final Future<void> deciding = decide(rig);
    await rig.transport.heldReplyArrival;

    final PairingSession newer = await rig.repository.startPairing();
    rig.transport.releaseHeldReply();
    await deciding;

    expect(rig.repository.findActiveSession()?.code, newer.code);
    await waitUntil(() => rig.repository.findPendingRequest() != null);
    expect(rig.repository.findPendingRequest()?.codeUsed, newer.code);
    rig.dispose();
  }
}
