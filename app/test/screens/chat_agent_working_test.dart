import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const int _conversationIterations = 40;
const int _mostMessages = 4;

ChatMessage _randomChatMessage(Random random) {
  return ChatMessage(
    at: randomUtcMoment(random),
    author: pickOne(random, ChatAuthor.values),
    text: randomText(random),
    isError: random.nextBool(),
    waitingToSend: false,
  );
}

Conversation _randomConversation(Random random) {
  final List<ChatMessage> messages = <ChatMessage>[
    for (int i = 0; i < random.nextInt(_mostMessages + 1); i += 1)
      _randomChatMessage(random),
  ];

  return Conversation(
    runId: RunId(randomText(random)),
    messages: messages,
    link: RunnerLink.direct,
    linkLostAt: null,
    agentActivity: pickOne(random, AgentActivity.values),
  );
}

Future<void> _pumpConversation(
  WidgetTester tester,
  Conversation conversation,
) async {
  useViewSize(tester, const Size(phoneWidth, phoneHeight));
  final Widget view = ConversationView(
    conversation: conversation,
    runnerName: 'mac-studio',
  );
  await tester.pumpWidget(wrapInApp(view, platform: phonePlatform));
  await tester.pump();
}

void main() {
  testWidgets(
    'test_conversation_view_property_one_cursor_exactly_while_replying',
    (WidgetTester tester) async {
      final Random random = seededRandom(9927);
      for (int i = 0; i < _conversationIterations; i += 1) {
        final Conversation conversation = _randomConversation(random);
        final bool isReplying =
            conversation.agentActivity == AgentActivity.replying;

        await _pumpConversation(tester, conversation);

        expect(
          find.byType(BlinkingCursor),
          isReplying ? findsOneWidget : findsNothing,
        );
      }
    },
  );
}
