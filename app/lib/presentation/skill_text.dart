import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';

const String _builtInLabel = 'Built in';
const String _unusedLabel = 'Not used yet';
const String _userSeparator = ', ';

String describeSkillReach(Skill skill, ScopeCatalog catalog) {
  if (skill.source == SkillSource.builtIn) {
    return _builtInLabel;
  }
  return describeScopeLine(skill.scope, catalog);
}

int _countTasksUsing(List<Task> tasks, SkillId skillId) {
  int count = 0;
  for (final Task task in tasks) {
    if (task.skills.contains(skillId)) {
      count += 1;
    }
  }
  return count;
}

bool _doesWorkflowUse(Workflow workflow, SkillId skillId) {
  for (final WorkflowAgent agent in workflow.agents) {
    if (agent.skills.contains(skillId)) {
      return true;
    }
  }
  return false;
}

String describeSkillUsers({
  required SkillId skillId,
  required List<Workflow> workflows,
  required List<Task> jobs,
  required List<Task> tasks,
}) {
  final List<String> users = <String>[];

  for (final Workflow workflow in workflows) {
    if (_doesWorkflowUse(workflow, skillId)) {
      users.add(workflow.name);
    }
  }

  final int jobCount = _countTasksUsing(jobs, skillId);
  if (jobCount > 0) {
    users.add(describeCount(jobCount, singular: 'job', plural: 'jobs'));
  }

  final int taskCount = _countTasksUsing(tasks, skillId);
  if (taskCount > 0) {
    users.add(describeCount(taskCount, singular: 'task', plural: 'tasks'));
  }

  if (users.isEmpty) {
    return _unusedLabel;
  }
  return users.join(_userSeparator);
}
