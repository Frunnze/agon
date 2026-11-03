import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const int _shownChangeCount = 5;
const String _momentSeparator = ' · ';

List<SkillChange> listRecentSkillChanges(List<SkillChange> history) {
  final List<SkillChange> newestFirst = history.reversed.toList();
  return newestFirst.take(_shownChangeCount).toList();
}

String describeSkillChangeTitle(SkillChangeOrigin origin) {
  return switch (origin) {
    PersonEdit() => 'Changed by you',
    ApprovedAgentRun() => 'Improved by an agent, approved by you',
    AutomaticAgentRun() => 'Improved by an agent automatically',
  };
}

String describeSkillChangeMoment({
  required String? runLabel,
  required DateTime savedAt,
  required DateTime now,
}) {
  final String since = describeTimeSince(savedAt, now);
  if (runLabel == null) {
    return since;
  }
  return '$runLabel$_momentSeparator$since';
}
