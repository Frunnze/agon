import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';

List<Run> _listGalleryRuns(TaskId taskId) {
  return <Run>[
    for (final Run run in galleryRuns)
      if (run.taskId == taskId) run,
  ];
}

void main() {
  test('test_collect_project_work_property_only_that_project', () {
    final Random random = seededRandom(9301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);
      final ProjectWork work = collectProjectWork(
        projectId: project.id,
        tasks: galleryTasks,
        listRuns: _listGalleryRuns,
      );

      for (final Task task in work.tasks) {
        expect(task.projectId, project.id);
      }
      final Set<TaskId> taskIds = <TaskId>{
        for (final Task task in work.tasks) task.id,
      };
      for (final Run run in work.runs) {
        expect(taskIds, contains(run.taskId));
      }
      expect(
        work.runningTaskCount,
        work.tasks
            .where((Task task) => task.status == TaskStatus.running)
            .length,
      );
    }
  });

  test('test_latest_run_property_no_run_starts_later', () {
    final ProjectWork work = collectProjectWork(
      projectId: galleryProjects.first.id,
      tasks: galleryTasks,
      listRuns: _listGalleryRuns,
    );
    final Run latest = work.latestRun!;

    for (final Run run in work.runs) {
      expect(run.startedAt.isAfter(latest.startedAt), isFalse);
    }
    expect(work.latestTaskTitle, 'Ship release 2.4');
    expect(ProjectWork(tasks: const [], runs: const []).latestRun, isNull);
    expect(
      ProjectWork(tasks: const [], runs: const []).latestTaskTitle,
      isNull,
    );
  });

  test('test_describe_project_summary_property_counts_repos_and_tasks', () {
    for (final Project project in galleryProjects) {
      final ProjectWork work = collectProjectWork(
        projectId: project.id,
        tasks: galleryTasks,
        listRuns: _listGalleryRuns,
      );
      final String summary = describeProjectSummary(project, work);

      expect(summary, startsWith('${project.repositories.length} repo'));
      expect(summary, contains(' · ${work.tasks.length} task'));
    }
  });

  test('test_build_project_row_property_keyed_and_tappable', () {
    int taps = 0;
    for (final Project project in galleryProjects) {
      final ListRowData row = buildProjectRow(
        project: project,
        work: ProjectWork(tasks: const [], runs: const []),
        now: galleryNow,
        onTap: () => taps += 1,
      );

      expect(row.key, ValueKey<ProjectId>(project.id));
      expect(row.meta.length, 2);
      row.onTap!();
    }
    expect(taps, galleryProjects.length);
  });

  test('test_find_project_rules_property_only_rules_that_apply', () {
    for (final Project project in galleryProjects) {
      final List<Rule> rules = findProjectRules(galleryRules, project);

      for (final Rule rule in galleryRules) {
        expect(
          rules.contains(rule),
          doesScopeApply(
            scope: rule.scope,
            workspaceId: project.workspaceId,
            projectId: project.id,
          ),
        );
      }
    }
  });

  test(
    'test_describe_repository_entry_problem_property_new_addresses_only',
    () {
      final Random random = seededRandom(9302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String text = pickOne(random, <String>[
          'github.com/acme/app',
          'https://github.com/acme/new.git',
          'nonsense',
          '',
        ]);
        final String? problem = describeRepositoryEntryProblem(
          text: text,
          addedAddresses: const <String>['github.com/acme/app'],
        );

        expect(problem == null, text == 'https://github.com/acme/new.git');
      }
    },
  );
}
