import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';

const String _successReplyField = 'ok';
const String _noAnnouncementProblem = 'no change is waiting to be announced';
const Duration _retryInterval = Duration(seconds: 30);

typedef _HeldExchange = ({
  String inputJson,
  String? earlyReply,
  Completer<String> delivery,
});

final class OutOfOrderReplyTransport implements NodeTransport {
  OutOfOrderReplyTransport({required this.answer, required this.random});

  final NodeAnswer answer;
  final Random random;
  bool isHoldingReplies = false;
  final List<_HeldExchange> _heldExchanges = <_HeldExchange>[];

  int get heldReplyCount => _heldExchanges.length;

  void releaseRandomReply() {
    if (_heldExchanges.isEmpty) {
      return;
    }
    final int position = random.nextInt(_heldExchanges.length);
    final _HeldExchange held = _heldExchanges.removeAt(position);
    final String reply = held.earlyReply ?? answer(held.inputJson);
    held.delivery.complete(reply);
  }

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    if (!isHoldingReplies) {
      await Future<void>.delayed(Duration.zero);
      return answer(inputJson);
    }

    final bool isAnsweredAtOnce = random.nextBool();
    final _HeldExchange held = (
      inputJson: inputJson,
      earlyReply: isAnsweredAtOnce ? answer(inputJson) : null,
      delivery: Completer<String>(),
    );
    _heldExchanges.add(held);
    return held.delivery.future;
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('an out of order transport is never stopped');
  }
}

Future<void> releaseEveryReplyInRandomOrder(
  OutOfOrderReplyTransport transport,
) async {
  await pumpEventQueue();
  while (transport.heldReplyCount > 0) {
    transport.releaseRandomReply();
    await pumpEventQueue();
  }
}

Future<void> awaitIgnoringNodeRefusals(Future<Object?> work) async {
  try {
    await work;
  } on Object catch (problem) {
    final bool isNodeRefusal =
        problem is StateError || problem is RecordNotFound;
    if (!isNodeRefusal) {
      rethrow;
    }
  }
}

final class AnnouncingNodeAnswer {
  AnnouncingNodeAnswer({required this.answer, required this.changeCommands});

  final NodeAnswer answer;
  final Set<String> changeCommands;
  int waitingAnnouncements = 0;

  String answerAndAnnounce(String inputJson) {
    final String reply = answer(inputJson);
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final Map<String, Object?> decodedReply =
        jsonDecode(reply) as Map<String, Object?>;
    final bool isAnnouncedChange =
        changeCommands.contains(command['command']) &&
        decodedReply.containsKey(_successReplyField);
    if (isAnnouncedChange) {
      waitingAnnouncements += 1;
    }
    return reply;
  }

  void takeAnnouncement() {
    if (waitingAnnouncements == 0) {
      throw StateError(_noAnnouncementProblem);
    }
    waitingAnnouncements -= 1;
  }
}

Future<void> releaseRepliesAndAnnouncements({
  required OutOfOrderReplyTransport transport,
  required AnnouncingNodeAnswer announcements,
  required void Function() deliverAnnouncement,
}) async {
  await pumpEventQueue();
  while (transport.heldReplyCount > 0 ||
      announcements.waitingAnnouncements > 0) {
    final bool isAnnouncing =
        announcements.waitingAnnouncements > 0 &&
        (transport.heldReplyCount == 0 || transport.random.nextBool());
    if (isAnnouncing) {
      announcements.takeAnnouncement();
      deliverAnnouncement();
    } else {
      transport.releaseRandomReply();
    }
    await pumpEventQueue();
  }
}

final class PendingRaceWork {
  final List<Future<void>> _startedWork = <Future<void>>[];

  void start(Future<Object?> work) {
    _startedWork.add(awaitIgnoringNodeRefusals(work));
  }

  Future<void> finish() async {
    final List<Future<void>> startedWork = List<Future<void>>.of(_startedWork);
    for (final Future<void> work in startedWork) {
      await work;
    }
  }
}

Future<NodeBackedWorkspaceRepository> openRaceWorkspaces(
  NodeCommandChannel channel,
) async {
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: channel,
        clock: FixedClock(DateTime.utc(2026, 11, 7)),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await workspaces.load();
  return workspaces;
}
