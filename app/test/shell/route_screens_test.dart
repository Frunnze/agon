import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/screens/shared/placeholder_screen.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/route_screens.dart';
import 'package:agent_orchestration/shell/section_route_screens.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';

const Set<AppSection> _builtSections = <AppSection>{
  AppSection.approvals,
  AppSection.tasks,
  AppSection.jobs,
  AppSection.projects,
  AppSection.workflows,
  AppSection.skills,
  AppSection.rules,
  AppSection.settings,
  AppSection.devices,
  AppSection.more,
};

const ProjectFilesRoute _galleryFilesRoute = ProjectFilesRoute(
  projectId: GalleryProjectIds.acmeApp,
  repositoryAddress: galleryAppRepositoryAddress,
);

void main() {
  final AppDependencies dependencies = buildGalleryDependencies();
  final AppNavigation navigation = AppNavigation(
    initialRoute: const SectionRoute(AppSection.tasks),
  );

  test('test_build_section_screen_property_unbuilt_sections_placeholder', () {
    for (final AppSection section in AppSection.values) {
      final Widget screen = buildSectionScreen(
        section: section,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect(screen is PlaceholderScreen, !_builtSections.contains(section));
    }
  });

  test('test_build_route_screen_property_every_route_has_a_screen', () {
    final List<AppRoute> routes = <AppRoute>[
      for (final AppSection section in AppSection.values)
        SectionRoute(section),
      const NewTaskRoute(),
      const EditTaskRoute(GalleryTaskIds.cleanUpBranches),
      const TaskRunRoute(GalleryRunIds.release42),
      const ChatRoute(GalleryRunIds.release42),
      const NewJobRoute(),
      const EditJobRoute(GalleryTaskIds.updateDependencies),
      const WorkflowChangeRoute(GalleryWorkflowIds.trainRanker),
      const WorkspaceSwitcherRoute(),
      const NewSkillRoute(),
      const SkillDetailRoute(GallerySkillIds.iosRelease),
      const EditSkillRoute(GallerySkillIds.gitCleanup),
      const RuleDetailRoute(RuleId('rule-never-push-to-main')),
      const EditRuleRoute(RuleId('rule-follow-app-style-guide')),
      const NewRuleRoute(presetProjectId: null),
      const NewRuleRoute(presetProjectId: GalleryProjectIds.docs),
      const RunnerDetailRoute(GalleryDeviceIds.gpuBox),
      const PairingCodeRoute(),
      const PairingApprovalRoute(),
      const SetupRoleRoute(),
      const PairingCodeEntryRoute(DeviceRole.runner),
      const PairingCodeEntryRoute(DeviceRole.client),
      PairingDoneRoute(galleryPairingOutcome),
      const NewProjectRoute(),
      const ProjectRoute(GalleryProjectIds.acmeApp),
      _galleryFilesRoute,
      RepositoryFileRoute(
        filesRoute: _galleryFilesRoute,
        source:
            galleryFileSources[galleryAppRepositoryAddress]!
                as FilesFromRunner,
        branch: 'main',
        path: 'README.md',
      ),
      const NewWorkflowRoute(),
      const WorkflowDraftingRoute(WorkflowDraft(description: 'Ship it')),
      const WorkflowDetailRoute(GalleryWorkflowIds.release),
      const WorkflowBuilderRoute(
        GalleryWorkflowIds.featurePipeline,
        opening: BuilderOpening.forEditing,
      ),
      const NewWorkflowTaskRoute(GalleryWorkflowIds.release),
    ];

    for (final AppRoute route in routes) {
      expect(
        buildRouteScreen(
          route: route,
          dependencies: dependencies,
          navigation: navigation,
        ),
        isA<Widget>(),
      );
    }
  });

  test('test_build_task_form_screen_property_keeps_the_task', () {
    final Random random = seededRandom(7201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> tasks = dependencies.taskRepository.listTasks();
      final Task? task = random.nextBool() ? pickOne(random, tasks) : null;
      final Widget screen = buildTaskFormScreen(
        existingTask: task,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect((screen as TaskFormScreen).existingTask, same(task));
    }
  });

  test('test_build_job_form_screen_property_keeps_the_job', () {
    final Random random = seededRandom(7202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> jobs = dependencies.jobRepository.listJobs();
      final Task? job = random.nextBool() ? pickOne(random, jobs) : null;
      final Widget screen = buildJobFormScreen(
        existingJob: job,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect((screen as JobFormScreen).existingJob, same(job));
    }
  });

  test('test_build_task_form_options_for_property_current_workspace_only', () {
    final Random random = seededRandom(7203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomRunnerTarget(random);
      final TaskFormOptions options = buildTaskFormOptionsFor(
        dependencies: dependencies,
        chosenTarget: target,
      );

      expect(options.projects.map((option) => option.label).toList(), <String>[
        'acme-app',
        'ml-ranker',
        'docs',
      ]);
      expect(
        options.runners.where((option) => option.value == target).length,
        1,
      );
    }
  });
}
