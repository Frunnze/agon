import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

enum AgentActivity { idle, replying }

final class Conversation {
  Conversation({
    required this.runId,
    required List<ChatMessage> messages,
    required this.link,
    required this.linkLostAt,
    required this.agentActivity,
  }) : messages = List<ChatMessage>.unmodifiable(messages);

  final RunId runId;
  final List<ChatMessage> messages;
  final RunnerLink link;
  final DateTime? linkLostAt;
  final AgentActivity agentActivity;

  Conversation withMessages(List<ChatMessage> nextMessages) {
    return Conversation(
      runId: runId,
      messages: nextMessages,
      link: link,
      linkLostAt: linkLostAt,
      agentActivity: agentActivity,
    );
  }
}
