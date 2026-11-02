import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/screens/chat/chat_composer.dart';

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _chattingTitle = 'Wait for release and listen';
const String _followUpMessage = 'Also add a line about the tests.';
const String _followUpReply = 'answered the follow-up';

Finder _findComposerInput() {
  return find.descendant(
    of: find.byType(ChatComposer),
    matching: find.byType(TextField),
  );
}

Future<void> _sendThroughComposer(WidgetTester tester, String text) async {
  await waitUntilShown(tester, _findComposerInput());
  await tester.enterText(_findComposerInput(), text);
  await tester.pump();
  await tapWhenShown(tester, find.text('Send'));
}

Future<bool> _hasSentMessage(RealStack stack) async {
  final node.Run run = await readLatestNodeRun(stack, _chattingTitle);
  for (final node.ChatMessage message in run.chat) {
    final bool isFromUser = message.author == node.ChatAuthor.you;
    if (isFromUser && message.text == _followUpMessage) {
      return true;
    }
  }
  return false;
}

void main() {
  testWidgets(
    'test_chat_property_sent_message_reaches_the_agent_and_it_replies',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );
      await startNewTaskNow(
        tester,
        title: _chattingTitle,
        details: 'Answer questions after the release.',
      );
      await waitUntilTrue(
        tester,
        description: 'the agent to start on the runner',
        isReached: () => runner.hasRecord(agentStartedFileName),
      );

      await tapAndWait(
        tester,
        find.text('Chat with agent'),
        expected: findPageTitle('Agent on $runnerDeviceName'),
      );
      await waitUntilGone(
        tester,
        findPageTitle(describeFirstRunTitle(_chattingTitle)),
      );
      await _sendThroughComposer(tester, _followUpMessage);
      await waitUntilShown(tester, find.text(_followUpMessage));
      await waitUntilNodeAgrees(
        tester,
        description: 'the chat message stored with the run',
        check: () => _hasSentMessage(stack),
      );

      runner.releaseAgent();
      await waitUntilTrue(
        tester,
        description: 'the agent to resume with the message',
        isReached: () => runner.hasRecord(resumedFileName),
      );
      await waitUntilShown(tester, find.text(_followUpReply));
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _chattingTitle,
        status: node.RunStatus.done,
      );

      expect(runner.readRecord(resumedFileName), contains(_followUpMessage));
      expect(find.text(agentFinishedReply), findsOneWidget);
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
