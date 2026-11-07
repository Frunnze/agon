import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';

Conversation buildConversationFromRun(Run run) {
  return Conversation(
    runId: run.id,
    messages: run.chat,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentActivity: _describeAgentActivity(run),
  );
}

AgentActivity _describeAgentActivity(Run run) {
  for (final RunStep step in run.steps) {
    if (step.status == StepStatus.running) {
      return AgentActivity.replying;
    }
  }
  return AgentActivity.idle;
}
