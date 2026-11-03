import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';

Project _randomProject(Random random) {
  return Project(
    id: ProjectId('project-${random.nextInt(1000)}'),
    workspaceId: GalleryWorkspaceIds.acme,
    name: randomWordPhrase(random),
    repositories: const <Repository>[],
  );
}

Workspace _randomWorkspace(Random random) {
  return Workspace(
    id: WorkspaceId('workspace-${random.nextInt(1000)}'),
    name: randomWordPhrase(random),
    appServerAddress: 'peer://example',
  );
}

void _expectAsksPlainly(DeletionPrompt prompt, String kind) {
  expect(prompt.title, startsWith('Delete '));
  expect(prompt.title, endsWith('?'));
  expect(prompt.explanation, contains("can't be deleted"));
  expect(prompt.keepLabel, 'Keep $kind');
  expect(prompt.deleteLabel, 'Delete $kind');
}

void main() {
  test('test_describe_project_deletion_property_names_the_project', () {
    final Random random = seededRandom(7301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = _randomProject(random);
      final DeletionPrompt prompt = describeProjectDeletion(project);

      expect(prompt.title, 'Delete ${project.name}?');
      _expectAsksPlainly(prompt, 'project');
    }
  });

  test('test_describe_workflow_deletion_property_names_the_workflow', () {
    final Random random = seededRandom(7302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final DeletionPrompt prompt = describeWorkflowDeletion(workflow);

      expect(prompt.title, 'Delete ${workflow.name}?');
      _expectAsksPlainly(prompt, 'workflow');
    }
  });

  test('test_describe_task_deletion_property_quotes_the_title', () {
    final Random random = seededRandom(7303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final DeletionPrompt prompt = describeTaskDeletion(task);

      expect(prompt.title, 'Delete "${task.title}"?');
      _expectAsksPlainly(prompt, 'task');
    }
  });

  test('test_describe_job_deletion_property_quotes_the_title', () {
    final Random random = seededRandom(7304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task job = pickOne(random, galleryJobs);
      final DeletionPrompt prompt = describeJobDeletion(job);

      expect(prompt.title, 'Delete "${job.title}"?');
      expect(prompt.explanation, startsWith('It stops repeating'));
      _expectAsksPlainly(prompt, 'job');
    }
  });

  test('test_describe_workspace_deletion_property_names_both_workspaces', () {
    final Random random = seededRandom(7305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace doomed = _randomWorkspace(random);
      final Workspace next = _randomWorkspace(random);
      final DeletionPrompt prompt = describeWorkspaceDeletion(
        doomed: doomed,
        next: next,
      );

      expect(prompt.title, 'Delete ${doomed.name}?');
      expect(prompt.explanation, contains('You switch to ${next.name}.'));
      _expectAsksPlainly(prompt, 'workspace');
    }
  });

  test('test_describe_skill_deletion_property_lists_who_uses_it', () {
    final Random random = seededRandom(7306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = pickOne(random, gallerySkills);
      final String users = randomWordPhrase(random);
      final DeletionPrompt prompt = describeSkillDeletion(
        skill: skill,
        users: users,
      );
      final Fact usersFact = prompt.facts.single;
      final List<String> usersTexts = <String>[
        for (final TextSegment segment in usersFact.description) segment.text,
      ];

      expect(prompt.title, 'Delete ${skill.name}?');
      expect(prompt.keepLabel, 'Keep skill');
      expect(prompt.deleteLabel, 'Delete skill');
      expect(usersFact.term, 'Used by');
      expect(usersTexts.join(), users);
    }
  });

  test('test_describe_rule_deletion_property_quotes_the_rule', () {
    final Random random = seededRandom(7307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, galleryRules);
      final DeletionPrompt prompt = describeRuleDeletion(rule);

      expect(prompt.title, 'Delete "${rule.title}"?');
      expect(prompt.keepLabel, 'Keep rule');
      expect(prompt.deleteLabel, 'Delete rule');
      expect(prompt.facts, isEmpty);
    }
  });

  test('describe deletion texts match the design pages', () {
    final Workspace acme = galleryWorkspaces.first;
    final Workspace personal = galleryWorkspaces.last;

    expect(
      describeWorkspaceDeletion(doomed: acme, next: personal).explanation,
      'Its projects go with it, with their tasks, jobs and runs, and so '
      'do the skills, rules and workflows only it can use. Your '
      'devices stay paired. You switch to personal. The last workspace '
      "can't be deleted, nor one with a running task.",
    );
    expect(
      describeSkillDeletion(skill: gallerySkills.first, users: '').explanation,
      'Agents stop using it. Tasks, jobs and workflows that chose it keep '
      'running without it.',
    );
    expect(
      describeRuleDeletion(galleryRules.first).explanation,
      'Agents stop getting it in AGENTS.md from their next run.',
    );
    expect(
      describeTaskDeletion(galleryTasks[2]).explanation,
      'Its runs go with it, with their logs and chats. Branches already '
      "pushed stay in their repos. A running task can't be deleted.",
    );
  });
}
