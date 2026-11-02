import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';

final class FakeChatRepository extends ChangeNotifier
    implements ChatRepository {
  FakeChatRepository({
    required List<Conversation> conversations,
    required Clock clock,
  }) : _conversations = <RunId, Conversation>{
         for (final Conversation conversation in conversations)
           conversation.runId: conversation,
       },
       _clock = clock;

  final Clock _clock;
  final Map<RunId, Conversation> _conversations;

  @override
  Conversation findConversation(RunId runId) {
    return _conversations[runId] ??
        Conversation(
          runId: runId,
          messages: const <ChatMessage>[],
          link: RunnerLink.direct,
          linkLostAt: null,
          agentActivity: AgentActivity.idle,
        );
  }

  @override
  Future<ChatMessage> sendMessage(RunId runId, String text) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Write a message first');
    }

    final Conversation conversation = findConversation(runId);
    final ChatMessage message = ChatMessage(
      at: _clock.now(),
      author: ChatAuthor.you,
      text: trimmedText,
      isError: false,
      waitingToSend: conversation.link == RunnerLink.unreachable,
    );

    _conversations[runId] = conversation.withMessages(<ChatMessage>[
      ...conversation.messages,
      message,
    ]);
    notifyListeners();
    return message;
  }
}
