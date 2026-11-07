import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';
import 'package:agent_orchestration/screens/workflows/workflow_text.dart';

import '../../support/random_inputs.dart';

const int _galleryIterations = 20;

List<WorkspaceId> _listWorkspaceIds(AppDependencies dependencies) {
  return <WorkspaceId>[
    for (final Workspace workspace
        in dependencies.workspaceRepository.listWorkspaces())
      workspace.id,
  ];
}

SignatureState _readState(AppDependencies dependencies, Workflow workflow) {
  return findSignatureState(
    workflow,
    dependencies.workflowRepository.findPendingChange(workflow.id),
  );
}

void _expectRunnerTargetResolves(
  AppDependencies dependencies,
  RunnerTarget target,
) {
  switch (target) {
    case AnyFreeRunner():
      return;
    case SpecificRunner(:final DeviceId deviceId):
      dependencies.deviceRepository.findDevice(deviceId);
      dependencies.runnerRepository.findRunner(deviceId);
    case RunnerWithLabels(:final List<String> labels):
      final bool isOffered = dependencies.runnerRepository.listRunners().any(
        (Runner runner) => labels.every(runner.labels.contains),
      );
      expect(isOffered, isTrue, reason: '$labels');
  }
}

List<Workflow> _listUnusedWorkflows(AppDependencies dependencies) {
  final List<Task> work = <Task>[
    ...dependencies.taskRepository.listTasks(),
    ...dependencies.jobRepository.listJobs(),
  ];
  final List<Workflow> unused = <Workflow>[];
  for (final Workflow workflow
      in dependencies.workflowRepository.listWorkflows()) {
    final WorkflowDoer usingDoer = WorkflowDoer(workflow.id);
    final bool isUsed = work.any((Task task) => task.doer == usingDoer);
    if (!isUsed) {
      unused.add(workflow);
    }
  }
  return unused;
}

void main() {
  test('test_build_gallery_dependencies_property_workflows_validate', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final Workflow workflow
        in dependencies.workflowRepository.listWorkflows()) {
      expect(
        describeNameProblem(workflow.name),
        isNull,
        reason: workflow.name,
      );
      expect(describeWorkflowProblem(workflow), isNull, reason: workflow.name);
      final Set<String> stepNames = <String>{
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      };
      expect(stepNames, hasLength(workflow.agents.length));
      expect(workflow.agents, isNotEmpty, reason: workflow.name);
    }
  });

  test('test_build_gallery_dependencies_property_seeds_save_back', () async {
    final Random random = seededRandom(68301);

    for (int i = 0; i < _galleryIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workflow workflow = pickOne(
        random,
        dependencies.workflowRepository.listWorkflows(),
      );
      final SignatureState before = _readState(dependencies, workflow);

      final Workflow saved = await dependencies.workflowRepository
          .saveWorkflow(workflow);

      expect(_readState(dependencies, saved), before);
      expect(saved.signature, same(workflow.signature));
    }
  });

  test('test_build_gallery_dependencies_property_changes_are_signed', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final Workflow workflow
        in dependencies.workflowRepository.listWorkflows()) {
      final WorkflowChange? change = dependencies.workflowRepository
          .findPendingChange(workflow.id);
      final WorkflowSignature? signature = workflow.signature;
      if (change == null || signature == null) {
        expect(change, isNull, reason: workflow.name);
        continue;
      }
      expect(change.signedDocument, signature.signedDocument);
      dependencies.deviceRepository.findDevice(change.changedBy!);
      dependencies.deviceRepository.findDevice(signature.signedBy);
    }
  });

  test('test_build_gallery_dependencies_property_steps_can_run', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final Workflow workflow
        in dependencies.workflowRepository.listWorkflows()) {
      for (final WorkflowAgent agent in workflow.agents) {
        _expectRunnerTargetResolves(dependencies, agent.runsOn);
        for (final SkillId skillId in agent.skills) {
          dependencies.skillRepository.findSkill(skillId);
        }
      }
    }
  });

  test('test_build_gallery_dependencies_property_scopes_are_known', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<WorkspaceId> workspaceIds = _listWorkspaceIds(dependencies);

    for (final Workflow workflow
        in dependencies.workflowRepository.listWorkflows()) {
      final WorkspaceScope availability = workflow.availability;
      if (availability is OnlyWorkspaces) {
        expect(workspaceIds, containsAll(availability.workspaces));
      }
    }
    for (final Device device in dependencies.deviceRepository.listDevices()) {
      expect(workspaceIds, containsAll(device.workspaces));
    }
    expect(
      workspaceIds,
      contains(dependencies.workspaceRepository.currentWorkspace().id),
    );
  });

  test('test_build_gallery_dependencies_property_workspaces_valid', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<WorkspaceId> workspaceIds = _listWorkspaceIds(dependencies);

    expect(workspaceIds.toSet(), hasLength(workspaceIds.length));
    for (final Workspace workspace
        in dependencies.workspaceRepository.listWorkspaces()) {
      expect(describeNameProblem(workspace.name), isNull);
      expect(
        workspace.protectedFiles.toSet(),
        hasLength(workspace.protectedFiles.length),
      );
    }
  });

  test('test_build_gallery_dependencies_property_drafts_validate', () async {
    final Random random = seededRandom(68302);
    final AppDependencies dependencies = buildGalleryDependencies();
    final List<String> namesBefore = <String>[
      for (final Workflow workflow
          in dependencies.workflowRepository.listWorkflows())
        workflow.name,
    ];
    final WorkflowDraft draft = WorkflowDraft(
      description: 'Plan ${randomText(random)} and ship',
    );

    final WorkflowDraftProgress finished = await dependencies
        .workflowRepository
        .draftWorkflow(draft)
        .last;

    final Workflow drafted = dependencies.workflowRepository.findWorkflow(
      finished.workflow.id,
    );
    expect(describeNameProblem(drafted.name), isNull);
    expect(describeWorkflowProblem(drafted), isNull);
    expect(namesBefore, isNot(contains(drafted.name)));
  });

  test(
    'test_build_gallery_dependencies_property_builds_are_isolated',
    () async {
      final Random random = seededRandom(68303);

      for (int i = 0; i < _galleryIterations; i += 1) {
        final AppDependencies first = buildGalleryDependencies();
        final AppDependencies second = buildGalleryDependencies();
        final Workflow workflow = pickOne(random, _listUnusedWorkflows(first));

        await first.workflowRepository.deleteWorkflow(workflow.id);
        await first.workspaceRepository.createWorkspace(name: 'team-$i');

        expect(
          second.workflowRepository.findWorkflow(workflow.id).id,
          workflow.id,
        );
        expect(
          second.workspaceRepository.listWorkspaces(),
          hasLength(first.workspaceRepository.listWorkspaces().length - 1),
        );
      }
    },
  );
}
