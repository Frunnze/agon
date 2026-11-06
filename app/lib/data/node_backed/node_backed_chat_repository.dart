import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/run_commands.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

const String _emptyMessageProblem = 'Write a message first';

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

final class NodeBackedChatRepository implements ChatRepository {
  const NodeBackedChatRepository({
    required NodeCommandChannel channel,
    required RunSource runSource,
    required WorkspaceRepository workspaceRepository,
  }) : _channel = channel,
       _runSource = runSource,
       _workspaceRepository = workspaceRepository;

  final NodeCommandChannel _channel;
  final RunSource _runSource;
  final WorkspaceRepository _workspaceRepository;

  @override
  void addListener(VoidCallback listener) {
    _runSource.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _runSource.removeListener(listener);
  }

  @override
  Conversation findConversation(RunId runId) {
    return buildConversationFromRun(_runSource.findRun(runId));
  }

  @override
  Future<ChatMessage> sendMessage(RunId runId, String text) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError.value(text, 'text', _emptyMessageProblem);
    }

    final node.ChatMessage sent = await executeNodeCommand(
      _channel,
      node.SendChatMessageCommand(
        workspaceId: _workspaceRepository.currentWorkspace().id,
        runId: runId,
        text: trimmedText,
      ),
    );
    await _runSource.refreshRun(runId);
    return mapChatMessageFromNode(sent);
  }
}
