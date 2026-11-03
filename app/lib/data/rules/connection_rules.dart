import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

const int maximumOutcomeLength = 40;
const int fewestLoopRounds = 1;
const int mostLoopRounds = 10;
const String _outcomeFormatRule =
    '1 to $maximumOutcomeLength lowercase letters, digits, spaces or dashes, '
    'with no space at either end';
const String outcomeFormatProblem = 'Use $_outcomeFormatRule';
const String loopNeedsOutcomeProblem =
    'A loop needs the outcome that sends the work back';
const String _cycleProblem =
    'The connections go round in a circle; draw the one going back as a loop';
final RegExp _outcomeCharacters = RegExp(r'^[a-z0-9 \-]+$');

bool isWellFormedOutcome(String outcome) {
  final bool hasAllowedLength =
      outcome.isNotEmpty && outcome.length <= maximumOutcomeLength;
  final bool hasAllowedCharacters = _outcomeCharacters.hasMatch(outcome);
  final bool isTrimmed = outcome.trim() == outcome;
  return hasAllowedLength && hasAllowedCharacters && isTrimmed;
}

bool _isOutcomeTakenElsewhere({
  required Workflow workflow,
  required AgentConnection connection,
  required String outcome,
}) {
  for (final AgentConnection other in workflow.connections) {
    final bool isSibling =
        other.from == connection.from && !other.joinsSameSteps(connection);
    if (isSibling && other.condition == outcome) {
      return true;
    }
  }
  return false;
}

String? describeOutcomeProblem({
  required Workflow workflow,
  required AgentConnection connection,
  required String outcome,
}) {
  if (!isWellFormedOutcome(outcome)) {
    return outcomeFormatProblem;
  }
  final bool isTaken = _isOutcomeTakenElsewhere(
    workflow: workflow,
    connection: connection,
    outcome: outcome,
  );
  if (isTaken) {
    final String fromName = workflow.findAgent(connection.from).name;
    return 'Another connection from $fromName already uses $outcome';
  }
  return null;
}

String _describeEnds(Workflow workflow, AgentConnection connection) {
  final String fromName = workflow.findAgent(connection.from).name;
  final String toName = workflow.findAgent(connection.to).name;
  return 'from $fromName to $toName';
}

String? _describeRoundLimitProblem(
  Workflow workflow,
  AgentConnection connection,
) {
  final int? roundLimit = connection.roundLimit;
  if (roundLimit == null) {
    return null;
  }
  final String ends = _describeEnds(workflow, connection);
  if (roundLimit < fewestLoopRounds || roundLimit > mostLoopRounds) {
    return 'The loop $ends can go back $fewestLoopRounds to '
        '$mostLoopRounds rounds, not $roundLimit';
  }
  if (connection.condition == null) {
    return 'Give the loop $ends an outcome';
  }
  return null;
}

String? _describeConditionProblem(
  Workflow workflow,
  AgentConnection connection,
  Set<String> seenOutcomes,
) {
  final String? condition = connection.condition;
  if (condition == null) {
    return null;
  }
  if (!isWellFormedOutcome(condition)) {
    final String ends = _describeEnds(workflow, connection);
    return 'Fix the outcome "$condition" $ends: use $_outcomeFormatRule';
  }
  final String outcomeKey = '${connection.from.value} $condition';
  if (!seenOutcomes.add(outcomeKey)) {
    final String fromName = workflow.findAgent(connection.from).name;
    return 'Two connections from $fromName share the outcome $condition';
  }
  return null;
}

bool _hasForwardCycle(Workflow workflow) {
  final List<AgentConnection> forward = listForwardConnections(workflow);
  final List<WorkflowAgent> remaining = List<WorkflowAgent>.of(
    workflow.agents,
  );
  final Set<WorkflowAgentId> placedIds = <WorkflowAgentId>{};

  int? readyIndex = findReadyIndex(remaining, placedIds, forward);
  while (readyIndex != null) {
    placedIds.add(remaining.removeAt(readyIndex).id);
    readyIndex = findReadyIndex(remaining, placedIds, forward);
  }
  return remaining.isNotEmpty;
}

String? _describeLoopDirectionProblem(Workflow workflow) {
  for (final AgentConnection connection in workflow.connections) {
    if (connection.isLoop && !pointsBack(workflow, connection)) {
      final String ends = _describeEnds(workflow, connection);
      return 'The loop $ends must go back to an earlier step';
    }
  }
  return null;
}

String? describeConnectionsProblem(Workflow workflow) {
  final Set<String> seenOutcomes = <String>{};
  for (final AgentConnection connection in workflow.connections) {
    final String? problem =
        _describeRoundLimitProblem(workflow, connection) ??
        _describeConditionProblem(workflow, connection, seenOutcomes);
    if (problem != null) {
      return problem;
    }
  }

  if (_hasForwardCycle(workflow)) {
    return _cycleProblem;
  }
  return _describeLoopDirectionProblem(workflow);
}
