import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_agent_login_rig.dart';
import 'support/simulated_agent_login_node.dart';

const String _prefix = 'test_node_backed_agent_login_repository';
const String _readCommand = 'read_agent_login';
const String _statusCommand = 'agent_login_status';
const String _stopCommand = 'stop_agent_login';
const int _followIterations = 15;
const int _longestTyping = 4;
const int _largestLineCount = 5;
const Duration _settleTime = Duration(milliseconds: 25);

Future<AgentLoginRig> _openQuickTerminal(Random random) async {
  final AgentLoginRig rig = buildAgentLoginRig(
    pollInterval: quickLoginPolling,
  );
  await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
  return rig;
}

Future<void> _expectPollingStopped(AgentLoginRig rig) async {
  final int readsBefore = countReceivedCommands(rig.node, _readCommand);
  await Future<void>.delayed(_settleTime);
  expect(countReceivedCommands(rig.node, _readCommand), readsBefore);
}

bool _isFailed(AgentLoginRig rig) {
  return rig.repository.findTerminal()?.state == LoginTerminalState.failed;
}

void main() {
  test('${_prefix}_follow_terminal_property_finished_login_closes', () async {
    final Random random = seededRandom(75601);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);
      final AgentPlace place = rig.repository.findTerminal()!.place;
      final int typingCount = random.nextInt(_longestTyping);
      for (int typing = 0; typing < typingCount; typing += 1) {
        await rig.repository.typeIntoTerminal(randomText(random));
      }

      rig.node.finishLogin(problem: null);
      await waitForLogin(
        () => countReceivedCommands(rig.node, _statusCommand) == 1,
      );
      await waitForLogin(() => rig.repository.findStatus() != null);

      final AgentLoginStatus? status = rig.repository.findStatus();
      expect(rig.repository.findTerminal(), isNull);
      expect(rig.node.login, isNull);
      expect(countReceivedCommands(rig.node, _stopCommand), 1);
      if (place == AgentPlace.container) {
        expect(
          status?.containerCredential,
          AgentCredentialKind.longLivedToken,
        );
      } else {
        expect(status?.claudeLogin, ClaudeLogin.loggedIn);
      }
    }
  });

  test('${_prefix}_follow_terminal_property_failed_login_stays', () async {
    final Random random = seededRandom(75602);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);
      final String problem = 'failed ${randomText(random)}';

      rig.node.finishLogin(problem: problem);
      await waitForLogin(() => _isFailed(rig));
      await waitForLogin(() => rig.repository.findStatus() != null);
      await _expectPollingStopped(rig);

      expect(rig.repository.findTerminal()?.problem, problem);
      expect(countReceivedCommands(rig.node, _statusCommand), 1);
      expect(countReceivedCommands(rig.node, _stopCommand), 0);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_follow_terminal_property_closing_stops_it', () async {
    final Random random = seededRandom(75603);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);
      await waitForLogin(
        () => countReceivedCommands(rig.node, _readCommand) >= 2,
      );

      await rig.repository.closeTerminal();
      await pumpEventQueue();
      await _expectPollingStopped(rig);

      expect(countReceivedCommands(rig.node, _statusCommand), 0);
      expect(rig.repository.findStatus(), isNull);
      expect(rig.repository.findTerminal(), isNull);
    }
  });

  test('${_prefix}_is_following_property_polls_while_running', () async {
    final Random random = seededRandom(75604);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);
      final int wantedReads = 2 + random.nextInt(4);

      await waitForLogin(
        () => countReceivedCommands(rig.node, _readCommand) >= wantedReads,
      );

      expect(rig.repository.findTerminal()?.state, LoginTerminalState.running);
      expect(countReceivedCommands(rig.node, _statusCommand), 0);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_is_following_property_vanished_login_stops', () async {
    final Random random = seededRandom(75605);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);

      rig.node.login = null;
      await waitForLogin(() => rig.repository.findTerminal() == null);
      await waitForLogin(() => rig.repository.findStatus() != null);
      await _expectPollingStopped(rig);

      expect(countReceivedCommands(rig.node, _statusCommand), 1);
      expect(countReceivedCommands(rig.node, _stopCommand), 0);
    }
  });

  test('${_prefix}_is_following_property_only_the_newest_terminal', () async {
    final Random random = seededRandom(75606);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);
      await rig.repository.closeTerminal();
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));

      rig.node.finishLogin(problem: null);
      await waitForLogin(() => rig.repository.findStatus() != null);
      await Future<void>.delayed(_settleTime);

      expect(countReceivedCommands(rig.node, _statusCommand), 1);
      expect(countReceivedCommands(rig.node, _stopCommand), 2);
      expect(rig.repository.findTerminal(), isNull);
    }
  });

  test('${_prefix}_read_terminal_property_shows_node_lines_exactly', () async {
    final Random random = seededRandom(75607);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = await _openQuickTerminal(random);
      final int lineCount = random.nextInt(_largestLineCount);
      final List<String> lines = <String>[
        for (int line = 0; line < lineCount; line += 1) randomText(random),
      ];

      rig.node.login = <String, Object?>{...?rig.node.login, 'lines': lines};
      await waitForLogin(
        () => listEquals(rig.repository.findTerminal()?.lines, lines),
      );

      expect(rig.repository.findTerminal()?.lines, lines);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_read_terminal_property_each_read_notifies', () async {
    final Random random = seededRandom(75608);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      final int typingCount = random.nextInt(_longestTyping);
      for (int typing = 0; typing < typingCount; typing += 1) {
        await rig.repository.typeIntoTerminal(randomText(random));
      }

      final int reads = countReceivedCommands(rig.node, _readCommand);
      expect(reads, 1 + typingCount);
      expect(rig.notifications.count, reads);
      await rig.repository.closeTerminal();
    }
  });

  test('${_prefix}_read_terminal_property_late_older_read_loses', () async {
    final Random random = seededRandom(75609);
    for (int i = 0; i < _followIterations; i += 1) {
      final AgentLoginRig rig = buildAgentLoginRig(
        pollInterval: slowLoginPolling,
      );
      await rig.repository.openTerminal(pickOne(random, AgentPlace.values));
      final List<String> newerLines = <String>[
        loginPrompt,
        'newer ${randomText(random)}',
      ];
      rig.transport.holdNextReply(_readCommand);

      final Future<void> olderTyping = rig.repository.typeIntoTerminal(
        randomText(random),
      );
      await rig.transport.heldReplyArrival;
      rig.node.login = <String, Object?>{
        ...?rig.node.login,
        'lines': newerLines,
      };
      await rig.repository.typeIntoTerminal(randomText(random));
      rig.transport.releaseHeldReply();
      await olderTyping;

      expect(rig.repository.findTerminal()?.lines, newerLines);
      await rig.repository.closeTerminal();
    }
  });
}
