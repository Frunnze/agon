import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

abstract interface class ChatRepository implements Listenable {
  Conversation findConversation(RunId runId);

  Future<ChatMessage> sendMessage(RunId runId, String text);
}
