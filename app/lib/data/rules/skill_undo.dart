import 'package:agent_orchestration/data/models/skill_change.dart';

SkillChange? findUndoableAgentChange(List<SkillChange> history) {
  if (history.isEmpty) {
    return null;
  }

  final SkillChange latest = history.last;
  if (latest.origin is AgentRunOrigin) {
    return latest;
  }
  return null;
}
