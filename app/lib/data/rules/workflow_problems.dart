import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

const String noAgentsProblem = 'Add at least one agent';

String? _describeRepeatedAgentProblem(List<WorkflowAgent> agents) {
  final Set<WorkflowAgentId> seenIds = <WorkflowAgentId>{};
  final Set<String> seenNames = <String>{};
  for (final WorkflowAgent agent in agents) {
    if (!seenIds.add(agent.id)) {
      return 'Two agents share the id ${agent.id.value}';
    }
    if (!seenNames.add(agent.name)) {
      return 'Two agents are named ${agent.name}';
    }
  }
  return null;
}

String? _describeStepNameProblem(List<WorkflowAgent> agents) {
  for (final WorkflowAgent agent in agents) {
    final String? nameProblem = describeNameProblem(agent.name);
    if (nameProblem != null) {
      return 'Rename the step "${agent.name}": $nameProblem';
    }
  }
  return null;
}

String? _describeConnectionEndProblem(Workflow workflow) {
  for (final AgentConnection connection in workflow.connections) {
    for (final WorkflowAgentId end in <WorkflowAgentId>[
      connection.from,
      connection.to,
    ]) {
      if (workflow.findAgentIfPresent(end) == null) {
        return 'A connection points to the unknown agent ${end.value}';
      }
    }
    if (connection.from == connection.to) {
      final String name = workflow.findAgent(connection.from).name;
      return 'The agent $name is connected to itself';
    }
  }
  return null;
}

String? describeWorkflowProblem(Workflow workflow) {
  if (workflow.agents.isEmpty) {
    return noAgentsProblem;
  }
  return _describeRepeatedAgentProblem(workflow.agents) ??
      _describeStepNameProblem(workflow.agents) ??
      _describeConnectionEndProblem(workflow) ??
      describeConnectionsProblem(workflow);
}
