import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

const String defaultRepositoryBranch = 'main';

String describeAgentAccessChoiceTitle(AgentAccess access) {
  switch (access) {
    case AgentAccess.readOnly:
      return 'Read only';
    case AgentAccess.pushAfterApproval:
      return 'Read, and push once you approve';
  }
}

List<ChoiceOption<AgentAccess>> buildAgentAccessChoices() {
  return <ChoiceOption<AgentAccess>>[
    ChoiceOption<AgentAccess>(
      value: AgentAccess.readOnly,
      title: describeAgentAccessChoiceTitle(AgentAccess.readOnly),
      detail:
          "Agents read the code and work in their sandbox. They can't push.",
    ),
    ChoiceOption<AgentAccess>(
      value: AgentAccess.pushAfterApproval,
      title: describeAgentAccessChoiceTitle(AgentAccess.pushAfterApproval),
      detail: 'The hub pushes for the agent after you approve.',
    ),
  ];
}
