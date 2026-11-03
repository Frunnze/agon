import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';

const String _approvalsMessage =
    'When an agent asks to do something that needs your approval, the '
    'request waits here.';
const String _jobsMessage =
    'A job is a task that repeats on a schedule, like nightly tests or a '
    'weekly dependency update.';
const String _skillsMessage =
    'Write the steps an agent should follow for one kind of work, like '
    'releasing the iOS app.';
const String _rulesMessage =
    'Write what every agent must follow, like never pushing to main, and '
    "each run's AGENTS.md gets it.";
const String _projectsMessage =
    'Add a project with the repos its tasks should work on.';
const String _workflowsMessage =
    'Describe what a chain of agents should do and an agent drafts the '
    'workflow for you.';
const List<Size> _sizes = <Size>[phoneSize, desktopSize];

Future<void> _pumpSection(
  WidgetTester tester, {
  required Random random,
  required AppSection section,
  required AppDependencies dependencies,
}) async {
  await pumpApp(
    tester,
    size: pickOne(random, _sizes),
    route: SectionRoute(section),
    dependencies: dependencies,
  );
}

void _expectEmptyStateFor(
  List<Object> listed, {
  required String title,
  required String message,
}) {
  final Matcher emptyStateMatcher = listed.isEmpty
      ? findsOneWidget
      : findsNothing;

  expect(find.text(title), emptyStateMatcher);
  expect(find.text(message), emptyStateMatcher);
}

List<Project> _listProjectsIn(
  List<Project> projects,
  WorkspaceId workspaceId,
) {
  final List<Project> workspaceProjects = <Project>[];
  for (final Project project in projects) {
    if (project.workspaceId == workspaceId) {
      workspaceProjects.add(project);
    }
  }
  return workspaceProjects;
}

void main() {
  testWidgets('test_approvals_screen_property_empty_only_without_requests', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ApprovalRequest> approvals = pickRandomRecords(
        random,
        galleryApprovals,
      );
      await _pumpSection(
        tester,
        random: random,
        section: AppSection.approvals,
        dependencies: buildDependenciesWithApprovals(approvals),
      );

      _expectEmptyStateFor(
        approvals,
        title: 'No approvals waiting',
        message: _approvalsMessage,
      );
      expect(find.text('Nothing is waiting for you.'), findsNothing);
      expect(find.text('Review'), findsNWidgets(approvals.length));
    }
  });

  testWidgets('test_jobs_screen_property_empty_only_without_jobs', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Task> jobs = pickRandomRecords(random, galleryJobs);
      await _pumpSection(
        tester,
        random: random,
        section: AppSection.jobs,
        dependencies: buildDependenciesWithJobs(jobs),
      );

      _expectEmptyStateFor(jobs, title: 'No jobs yet', message: _jobsMessage);
      expect(find.text('New job'), findsOneWidget);
      expect(
        find.text('Tasks that repeat on a schedule.'),
        jobs.isNotEmpty ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_skills_screen_property_empty_only_without_skills', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = pickRandomRecords(random, gallerySkills);
      await _pumpSection(
        tester,
        random: random,
        section: AppSection.skills,
        dependencies: buildDependenciesWithSkills(skills),
      );

      _expectEmptyStateFor(
        skills,
        title: 'No skills yet',
        message: _skillsMessage,
      );
      expect(find.text('New skill'), findsOneWidget);
    }
  });

  testWidgets('test_rules_screen_property_empty_only_without_rules', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = pickRandomRecords(random, galleryRules);
      await _pumpSection(
        tester,
        random: random,
        section: AppSection.rules,
        dependencies: buildDependenciesWithRules(rules),
      );

      _expectEmptyStateFor(
        rules,
        title: 'No rules yet',
        message: _rulesMessage,
      );
      expect(find.text('New rule'), findsOneWidget);
      expect(
        find.textContaining('AGENTS.md for'),
        rules.isNotEmpty ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_projects_screen_property_empty_only_without_projects', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Project> projects = pickRandomRecords(
        random,
        galleryProjects,
      );
      final List<Project> acmeProjects = _listProjectsIn(
        projects,
        GalleryWorkspaceIds.acme,
      );
      await _pumpSection(
        tester,
        random: random,
        section: AppSection.projects,
        dependencies: buildDependenciesWithProjects(projects),
      );

      _expectEmptyStateFor(
        acmeProjects,
        title: 'No projects yet',
        message: _projectsMessage,
      );
      expect(find.text('New project'), findsOneWidget);
      expect(
        find.text('Each project holds the repos its tasks work on.'),
        acmeProjects.isEmpty ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_workflows_screen_property_empty_only_without_workflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workflow> workflows = pickRandomRecords(
        random,
        galleryWorkflows,
      );
      await _pumpSection(
        tester,
        random: random,
        section: AppSection.workflows,
        dependencies: buildDependenciesWithWorkflows(workflows),
      );

      _expectEmptyStateFor(
        workflows,
        title: 'No workflows yet',
        message: _workflowsMessage,
      );
      expect(find.text('New workflow'), findsOneWidget);
      expect(
        find.text('Available in all your workspaces unless you limit it.'),
        workflows.isNotEmpty ? findsOneWidget : findsNothing,
      );
    }
  });
}
