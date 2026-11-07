import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes/record_lists.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_conversation.dart';

const String _conversationKind = 'conversation';

String _identifyConversationRun(Conversation conversation) {
  return conversation.runId.value;
}

final class FakeChatRepository extends ChangeNotifier
    implements ChatRepository {
  FakeChatRepository({
    required List<Conversation> conversations,
    required TaskRepository taskRepository,
    required Clock clock,
  }) : _conversations = <RunId, Conversation>{
         for (final Conversation conversation in conversations)
           conversation.runId: conversation,
       },
       _taskRepository = taskRepository,
       _clock = clock {
    refuseDuplicateIdentifiers(
      conversations,
      identify: _identifyConversationRun,
      kind: _conversationKind,
    );
  }

  final Clock _clock;
  final TaskRepository _taskRepository;
  final Map<RunId, Conversation> _conversations;

  @override
  Conversation findConversation(RunId runId) {
    final Conversation? kept = _conversations[runId];
    if (kept != null) {
      return kept;
    }
    return buildConversationFromRun(_taskRepository.findRun(runId));
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
