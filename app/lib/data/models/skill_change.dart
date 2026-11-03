import 'package:agent_orchestration/data/models/identifiers.dart';

sealed class SkillChangeOrigin {
  const SkillChangeOrigin();
}

final class PersonEdit extends SkillChangeOrigin {
  const PersonEdit();
}

sealed class AgentRunOrigin extends SkillChangeOrigin {
  const AgentRunOrigin(this.runId);

  final RunId runId;
}

final class ApprovedAgentRun extends AgentRunOrigin {
  const ApprovedAgentRun(super.runId);
}

final class AutomaticAgentRun extends AgentRunOrigin {
  const AutomaticAgentRun(super.runId);
}

final class SkillChange {
  const SkillChange({
    required this.origin,
    required this.savedAt,
    required this.replacedInstructions,
  });

  final SkillChangeOrigin origin;
  final DateTime savedAt;
  final String replacedInstructions;
}
