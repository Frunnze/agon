import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

final class DeletionPrompt {
  const DeletionPrompt({
    required this.title,
    required this.explanation,
    required this.keepLabel,
    required this.deleteLabel,
    this.facts = const <Fact>[],
  });

  final String title;
  final String explanation;
  final String keepLabel;
  final String deleteLabel;
  final List<Fact> facts;
}

DeletionPrompt describeProjectDeletion(Project project) {
  return DeletionPrompt(
    title: 'Delete ${project.name}?',
    explanation:
        'Its tasks and jobs go with it, with their runs, logs and chats. '
        "The code stays in its repos. A project with a running task can't "
        'be deleted.',
    keepLabel: 'Keep project',
    deleteLabel: 'Delete project',
  );
}

DeletionPrompt describeWorkflowDeletion(Workflow workflow) {
  return DeletionPrompt(
    title: 'Delete ${workflow.name}?',
    explanation:
        "It leaves every workspace it's in, with its signed version. A "
        "workflow that tasks or jobs still use can't be deleted.",
    keepLabel: 'Keep workflow',
    deleteLabel: 'Delete workflow',
  );
}

DeletionPrompt describeTaskDeletion(Task task) {
  return DeletionPrompt(
    title: 'Delete "${task.title}"?',
    explanation:
        'Its runs go with it, with their logs and chats. Branches already '
        "pushed stay in their repos. A running task can't be deleted.",
    keepLabel: 'Keep task',
    deleteLabel: 'Delete task',
  );
}

DeletionPrompt describeJobDeletion(Task job) {
  return DeletionPrompt(
    title: 'Delete "${job.title}"?',
    explanation:
        'It stops repeating, and its runs go with it, with their logs and '
        "chats. A job with a run in progress can't be deleted.",
    keepLabel: 'Keep job',
    deleteLabel: 'Delete job',
  );
}

DeletionPrompt describeSkillDeletion({
  required Skill skill,
  required String users,
}) {
  return DeletionPrompt(
    title: 'Delete ${skill.name}?',
    explanation:
        'Agents stop using it. Tasks, jobs and workflows that chose it '
        'keep running without it.',
    keepLabel: 'Keep skill',
    deleteLabel: 'Delete skill',
    facts: <Fact>[
      Fact(term: 'Used by', description: <TextSegment>[TextSegment(users)]),
    ],
  );
}

DeletionPrompt describeRuleDeletion(Rule rule) {
  return DeletionPrompt(
    title: 'Delete "${rule.title}"?',
    explanation: 'Agents stop getting it in AGENTS.md from their next run.',
    keepLabel: 'Keep rule',
    deleteLabel: 'Delete rule',
  );
}

DeletionPrompt describeWorkspaceDeletion({
  required Workspace doomed,
  required Workspace next,
}) {
  return DeletionPrompt(
    title: 'Delete ${doomed.name}?',
    explanation:
        'Its projects go with it, with their tasks, jobs and runs. Your '
        'devices stay paired. You switch to ${next.name}. The last '
        "workspace can't be deleted, nor one with a running task.",
    keepLabel: 'Keep workspace',
    deleteLabel: 'Delete workspace',
  );
}
