import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

const String draftedWorkflowGreeting =
    'I drafted this from your description. Check each agent before you '
    'sign, or tell me what to change.';
const String openWorkflowGreeting =
    'Tell me what to change and I will redraw the diagram.';
const String changeDoneReply =
    'Done. Check the change on the diagram before you sign.';
const String changeFailedReplyStart = 'That did not work: ';
const String _blankRequestProblem = 'Say what the agent should change';
const String _busyProblem = 'The agent is still changing the workflow';
const AgentKind _firstAgent = AgentKind.claudeCode;

typedef WorkflowChangeRequest =
    Future<Workflow> Function(
      WorkflowId workflowId,
      String request,
      AgentKind agent,
    );

sealed class WorkflowChatMessage {
  const WorkflowChatMessage(this.text);

  final String text;
}

final class PersonMessage extends WorkflowChatMessage {
  const PersonMessage(super.text);
}

final class AgentMessage extends WorkflowChatMessage {
  const AgentMessage({required this.agent, required String text})
    : super(text);

  final AgentKind agent;
}

final class WorkflowChangeChat extends ChangeNotifier {
  WorkflowChangeChat({
    required WorkflowId workflowId,
    required String greeting,
    required WorkflowChangeRequest changeWorkflow,
  }) : _workflowId = workflowId,
       _changeWorkflow = changeWorkflow,
       _messages = List<WorkflowChatMessage>.unmodifiable(<WorkflowChatMessage>[
         AgentMessage(agent: _firstAgent, text: greeting),
       ]);

  final WorkflowId _workflowId;
  final WorkflowChangeRequest _changeWorkflow;
  List<WorkflowChatMessage> _messages;
  AgentKind _agent = _firstAgent;
  bool _isWorking = false;
  bool _isDisposed = false;

  List<WorkflowChatMessage> get messages => _messages;

  AgentKind get agent => _agent;

  bool get isWorking => _isWorking;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void chooseAgent(AgentKind agent) {
    _agent = agent;
    notifyListeners();
  }

  Future<void> send(String request) async {
    final String trimmedRequest = request.trim();
    if (trimmedRequest.isEmpty) {
      throw ArgumentError.value(request, 'request', _blankRequestProblem);
    }
    if (_isWorking) {
      throw StateError(_busyProblem);
    }

    final AgentKind answeringAgent = _agent;
    _append(PersonMessage(trimmedRequest));
    _isWorking = true;
    notifyListeners();

    try {
      final String reply = await _askForChange(trimmedRequest, answeringAgent);
      if (!_isDisposed) {
        _append(AgentMessage(agent: answeringAgent, text: reply));
      }
    } finally {
      _isWorking = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<String> _askForChange(String request, AgentKind agent) async {
    try {
      await _changeWorkflow(_workflowId, request, agent);
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      return '$changeFailedReplyStart$explanation';
    }
    return changeDoneReply;
  }

  void _append(WorkflowChatMessage message) {
    _messages = List<WorkflowChatMessage>.unmodifiable(<WorkflowChatMessage>[
      ..._messages,
      message,
    ]);
  }
}
