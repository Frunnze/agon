import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes/gallery_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'draft_record_fields.dart';
import 'random_drafts.dart';

const ProjectId _unlistedProjectId = ProjectId('project-nowhere');
const WorkflowId _unlistedWorkflowId = WorkflowId('workflow-nowhere');

TaskFormOptions _buildGalleryOptions(AppDependencies dependencies) {
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    findPendingChange: dependencies.workflowRepository.findPendingChange,
    runners: dependencies.runnerRepository.listRunners(),
    deviceNames: DeviceNames(dependencies.deviceRepository.listDevices()),
    skills: dependencies.skillRepository.listSkills(),
    chosenTarget: const AnyFreeRunner(),
  );
}

void main() {
  test('test_from_drafted_work_property_listed_drafts_round_trip', () {
    final Random random = seededRandom(8501);
    final TaskFormOptions options = _buildGalleryOptions(
      buildGalleryDependencies(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, <DraftKind>[
        DraftKind.task,
        DraftKind.job,
      ]);
      final DraftedWork work = randomListedWork(random, kind);

      final TaskFormValues values = TaskFormValues.fromDraftedWork(
        work: work,
        options: options,
        unscheduledRepeat: RepeatChoice.none,
      );

      expect(
        describeDraftedWorkFields(values.toDraftedWork()),
        describeDraftedWorkFields(work),
      );
    }
  });

  test(
    'test_from_drafted_work_property_unscheduled_work_takes_the_repeat',
    () {
      final Random random = seededRandom(8502);
      final TaskFormOptions options = _buildGalleryOptions(
        buildGalleryDependencies(),
      );

      for (int i = 0; i < propertyIterations; i += 1) {
        final RepeatChoice repeat = pickOne(random, RepeatChoice.values);
        final DraftedWork work = randomListedWork(random, DraftKind.task);
        final DraftedWork unscheduled = DraftedWork(
          title: work.title,
          details: work.details,
          projectId: work.projectId,
          doer: work.doer,
          runsOn: work.runsOn,
          agentPlace: work.agentPlace,
          skills: work.skills,
          usesAutomaticSkills: work.usesAutomaticSkills,
          approvalPolicy: work.approvalPolicy,
          schedule: null,
        );

        final TaskFormValues values = TaskFormValues.fromDraftedWork(
          work: unscheduled,
          options: options,
          unscheduledRepeat: repeat,
        );

        expect(values.repeat, repeat);
      }
    },
  );

  test('test_pick_shown_project_property_unlisted_become_the_first', () {
    final Random random = seededRandom(8503);
    final TaskFormOptions options = _buildGalleryOptions(
      buildGalleryDependencies(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectId? projectId = pickOne(random, <ProjectId?>[
        ...sampleProjectIds,
        _unlistedProjectId,
        null,
      ]);

      final ProjectId shown = options.pickShownProject(projectId);

      final bool isListed = sampleProjectIds.contains(projectId);
      expect(shown, isListed ? projectId : options.firstProjectId);
    }
  });

  test('test_pick_shown_doer_property_unlisted_become_the_default', () {
    final Random random = seededRandom(8504);
    final TaskFormOptions options = _buildGalleryOptions(
      buildGalleryDependencies(),
    );
    final List<TaskDoer> listedDoers = <TaskDoer>[
      for (final AgentKind agent in AgentKind.values) OneAgentDoer(agent),
      for (final WorkflowId workflowId in sampleWorkflowIds)
        WorkflowDoer(workflowId),
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDoer doer = pickOne(random, <TaskDoer>[
        ...listedDoers,
        const WorkflowDoer(_unlistedWorkflowId),
      ]);

      final TaskDoer shown = options.pickShownDoer(doer);

      final bool isListed = listedDoers.contains(doer);
      expect(shown, isListed ? doer : defaultTaskDoer);
    }
  });

  test('a review refuses a draft of another kind', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final DraftReview review = SkillDraftReview(
      skillRepository: dependencies.skillRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: AppNavigation(
        initialRoute: const SectionRoute(AppSection.skills),
      ),
    );
    const DraftedRule rule = DraftedRule(
      RuleDraft(title: 'x', details: '', scope: Scope.everywhere()),
    );

    expect(review.approve(rule), throwsArgumentError);
  });
}
