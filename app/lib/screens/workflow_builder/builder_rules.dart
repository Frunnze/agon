import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

const String _chooseAgentLabel = 'Choose an agent';

final class AgentKindChoice {
  const AgentKindChoice(this.kind);

  final AgentKind? kind;

  @override
  bool operator ==(Object other) {
    return other is AgentKindChoice && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;
}

List<SelectOption<AgentKindChoice>> buildAgentKindEntries(AgentKind? kind) {
  return <SelectOption<AgentKindChoice>>[
    if (kind == null)
      const SelectOption<AgentKindChoice>.disabled(
        value: AgentKindChoice(null),
        label: _chooseAgentLabel,
      ),
    for (final AgentKind option in AgentKind.values)
      SelectOption<AgentKindChoice>(
        value: AgentKindChoice(option),
        label: option.label,
      ),
  ];
}

String? describeAgentNameProblem({
  required Workflow workflow,
  required WorkflowAgent agent,
  required String name,
}) {
  final String? formatProblem = describeNameProblem(name);
  if (formatProblem != null) {
    return formatProblem;
  }

  for (final WorkflowAgent other in workflow.agents) {
    if (other.id != agent.id && other.name == name) {
      return 'Another agent has this name';
    }
  }
  return null;
}

String? describeSigningProblem(Workflow workflow) {
  if (workflow.agents.isEmpty) {
    return 'Add at least one agent';
  }

  for (final WorkflowAgent agent in workflow.agents) {
    final String? problem = _describeStepProblem(agent);
    if (problem != null) {
      return problem;
    }
  }
  return describeConnectionsProblem(workflow);
}

String? _describeStepProblem(WorkflowAgent agent) {
  final bool isBlank = agent.task.trim().isEmpty;
  switch (agent.stepKind) {
    case StepKind.person:
      return isBlank ? 'Write a question for ${agent.name}' : null;
    case StepKind.agent:
      if (agent.kind == null) {
        return 'Choose an agent for ${agent.name}';
      }
      return isBlank ? 'Write a task for ${agent.name}' : null;
  }
}
