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
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';
import '../support/sample_scopes.dart';

void main() {
  test('test_name_of_workspace_property_round_trips_find_workspace_id', () {
    final Random random = seededRandom(9201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace workspace = pickOne(random, galleryWorkspaces);

      expect(galleryCatalog.nameOfWorkspace(workspace.id), workspace.name);
      expect(galleryCatalog.findWorkspaceId(workspace.name), workspace.id);
      expect(
        () => galleryCatalog.nameOfWorkspace(
          WorkspaceId('x${randomText(random)}'),
        ),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_name_of_project_property_round_trips_find_project_id', () {
    final Random random = seededRandom(9202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);

      expect(galleryCatalog.nameOfProject(project.id), project.name);
      expect(galleryCatalog.findProjectId(project.name), project.id);
      expect(
        () => galleryCatalog.findProjectId('x${randomText(random)}'),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_find_workspace_id_fuzz_property_unknown_names_fail', () {
    final Random random = seededRandom(9203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = 'x${randomText(random)}';

      expect(
        () => galleryCatalog.findWorkspaceId(name),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        () => galleryCatalog.nameOfProject(ProjectId(name)),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_list_projects_in_property_only_chosen_workspaces', () {
    final Random random = seededRandom(9204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> chosen = pickSome(random, <WorkspaceId>[
        GalleryWorkspaceIds.acme,
        GalleryWorkspaceIds.personal,
      ]);
      final List<Project> projects = galleryCatalog.listProjectsIn(chosen);

      if (chosen.isEmpty) {
        expect(projects, galleryProjects);
        continue;
      }
      for (final Project project in galleryProjects) {
        expect(
          projects.contains(project),
          chosen.contains(project.workspaceId),
        );
      }
    }
  });

  test('test_describe_scope_chips_property_names_every_listed_place', () {
    final Random random = seededRandom(9205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScope(random);
      final List<String> chips = describeScopeChips(scope, galleryCatalog);
      final WorkspaceScope workspaces = scope.workspaces;
      final ProjectScope projects = scope.projects;
      final List<String> expected = <String>[
        if (workspaces is OnlyWorkspaces)
          for (final WorkspaceId id in workspaces.workspaces)
            galleryCatalog.nameOfWorkspace(id),
        if (projects is OnlyProjects)
          for (final ProjectId id in projects.projects)
            galleryCatalog.nameOfProject(id),
      ];

      expect(chips, expected.isEmpty ? <String>['Everywhere'] : expected);
    }
  });

  test('test_describe_scope_line_property_workspaces_before_projects', () {
    final Random random = seededRandom(9206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScope(random);
      final String line = describeScopeLine(scope, galleryCatalog);
      final List<String> chips = describeScopeChips(scope, galleryCatalog);

      int searchFrom = 0;
      for (final String chip in chips) {
        final int position = line.indexOf(chip, searchFrom);
        expect(position, greaterThanOrEqualTo(0), reason: line);
        searchFrom = position + chip.length;
      }
      final WorkspaceScope workspaces = scope.workspaces;
      final ProjectScope projects = scope.projects;
      final bool namesWorkspaces =
          workspaces is OnlyWorkspaces && workspaces.workspaces.isNotEmpty;
      final bool namesProjects =
          projects is OnlyProjects && projects.projects.isNotEmpty;
      expect(
        line.endsWith(' · all projects'),
        namesWorkspaces && !namesProjects,
      );
    }
  });

  test('describe scope line pins the gallery skills', () {
    final List<String> lines = <String>[
      for (final Skill skill in gallerySkills)
        describeScopeLine(skill.scope, galleryCatalog),
    ];

    expect(lines, <String>[
      'acme · acme-app',
      'Everywhere',
      'acme · all projects',
      'Everywhere',
    ]);
  });

  test('test_describe_skill_reach_property_built_in_or_scope_line', () {
    final Random random = seededRandom(9207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill base = pickOne(random, gallerySkills);
      final Skill skill = Skill(
        id: base.id,
        name: base.name,
        summary: base.summary,
        instructions: base.instructions,
        scope: randomScope(random),
        usage: base.usage,
        source: pickOne(random, SkillSource.values),
      );

      expect(
        describeSkillReach(skill, galleryCatalog),
        skill.source == SkillSource.builtIn
            ? 'Built in'
            : describeScopeLine(skill.scope, galleryCatalog),
      );
    }
  });

  test('test_describe_skill_users_property_lists_workflows_then_counts', () {
    final Random random = seededRandom(9208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Workflow> workflows = pickSome(random, galleryWorkflows);
      final List<Task> jobs = pickSome(random, galleryJobs);
      final List<Task> tasks = pickSome(random, galleryTasks);
      final String users = describeSkillUsers(
        skillId: skillId,
        workflows: workflows,
        jobs: jobs,
        tasks: tasks,
      );

      final List<String> workflowNames = <String>[
        for (final Workflow workflow in workflows)
          if (workflow.agents.any(
            (WorkflowAgent agent) => agent.skills.contains(skillId),
          ))
            workflow.name,
      ];
      final int jobCount = jobs
          .where((Task job) => job.skills.contains(skillId))
          .length;
      final int taskCount = tasks
          .where((Task task) => task.skills.contains(skillId))
          .length;

      if (workflowNames.isEmpty && jobCount == 0 && taskCount == 0) {
        expect(users, 'Not used yet');
        continue;
      }
      expect(users.startsWith(workflowNames.join(', ')), isTrue);
      expect(users.contains(RegExp(r'\b1 jobs\b|\b1 tasks\b')), isFalse);
      expect(users.contains('$jobCount job'), jobCount > 0);
      expect(users.contains('$taskCount task'), taskCount > 0);
    }
  });

  test('describe skill users pins the gallery skills', () {
    final List<String> users = <String>[
      for (final Skill skill in gallerySkills)
        describeSkillUsers(
          skillId: skill.id,
          workflows: galleryWorkflows,
          jobs: galleryJobs,
          tasks: galleryTasks,
        ),
    ];

    expect(users, <String>[
      'release, feature-pipeline',
      'feature-pipeline, 1 job',
      '1 task',
      'Not used yet',
    ]);
  });
}
