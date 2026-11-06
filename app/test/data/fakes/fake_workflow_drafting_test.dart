import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(
    description: 'Plan ${randomWordPhrase(random)} then ship.',
  );
}

bool _isAvailableSomewhere(WorkspaceScope availability) {
  return switch (availability) {
    AllWorkspaces() => true,
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) =>
      workspaces.isNotEmpty,
  };
}

List<String> _listNames(FakeWorkflowRepository repository) {
  return <String>[
    for (final Workflow workflow in repository.listWorkflows()) workflow.name,
  ];
}

bool _isAcyclic(Workflow workflow) {
  final List<WorkflowAgent> ordered = orderAgents(workflow);
  final List<WorkflowAgentId> ids = <WorkflowAgentId>[
    for (final WorkflowAgent agent in ordered) agent.id,
  ];

  for (final AgentConnection connection in workflow.connections) {
    if (ids.indexOf(connection.from) >= ids.indexOf(connection.to)) {
      return false;
    }
  }
  return true;
}

void _expectSoundWorkflows(FakeWorkflowRepository repository) {
  final List<Workflow> workflows = repository.listWorkflows();
  final Set<WorkflowId> ids = <WorkflowId>{
    for (final Workflow workflow in workflows) workflow.id,
  };
  expect(ids.length, workflows.length);

  for (final Workflow workflow in workflows) {
    final Set<String> names = <String>{
      for (final WorkflowAgent agent in workflow.agents) agent.name,
    };
    expect(names.length, workflow.agents.length);
    expect(_isAcyclic(workflow), isTrue);
  }
}

void main() {
  test('test_draft_workflow_property_agents_arrive_one_by_one', () async {
    final Random random = seededRandom(8401);

    for (int i = 0; i < 20; i += 1) {
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();
      final WorkflowDraft draft = _randomDraft(random);
      final List<String> namesBefore = _listNames(repository);
      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(draft)
          .toList();
      final Workflow drafted = steps.last.workflow;

      for (int index = 0; index < steps.length; index += 1) {
        final WorkflowDraftProgress step = steps[index];
        expect(step.workflow.agents.length, index);
        expect(
          step.workflow.agents.length + step.pendingAgents.length,
          drafted.agents.length,
        );
        expect(step.isFinished, index == steps.length - 1);
        expect(step.drafterKind, AgentKind.claudeCode);
        expect(step.drafterDeviceId, GalleryDeviceIds.officeServer);
      }
      expect(describeNameProblem(drafted.name), isNull);
      expect(namesBefore, isNot(contains(drafted.name)));
      expect(_isAvailableSomewhere(drafted.availability), isTrue);
      expect(drafted.signature, isNull);
      expect(drafted.agents.length, 5);
      expect(repository.findWorkflow(drafted.id).name, drafted.name);
      _expectSoundWorkflows(repository);
    }
  });

  test('test_draft_workflow_property_agent_picks_a_free_name', () async {
    final Random random = seededRandom(8405);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();

    for (int i = 0; i < 6; i += 1) {
      final List<String> namesBefore = _listNames(repository);
      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(_randomDraft(random))
          .toList();
      final String draftedName = steps.last.workflow.name;

      expect(namesBefore, isNot(contains(draftedName)));
      expect(_listNames(repository), contains(draftedName));
    }
  });

  test(
    'test_draft_workflow_property_blank_words_are_a_stream_error',
    () async {
      final Random random = seededRandom(8406);
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();

      for (int i = 0; i < 6; i += 1) {
        final String blank = pickOne(random, <String>['', ' ', '\n\t ']);

        await expectLater(
          repository.draftWorkflow(WorkflowDraft(description: blank)),
          emitsError(isArgumentError),
        );
      }
    },
  );

  test('test_stop_drafting_property_stopped_draft_is_never_saved', () async {
    final Random random = seededRandom(8404);

    for (int i = 0; i < 20; i += 1) {
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();
      final WorkflowDraft draft = _randomDraft(random);
      final int workflowsBefore = repository.listWorkflows().length;
      final int stepsBeforeStop = random.nextInt(5);
      final List<WorkflowDraftProgress> steps = <WorkflowDraftProgress>[];
      final Future<void> drafting = repository
          .draftWorkflow(draft)
          .forEach(steps.add);
      await Future<void>.delayed(Duration.zero);
      while (steps.length < stepsBeforeStop) {
        await Future<void>.delayed(Duration.zero);
      }

      await repository.stopDrafting(draft);
      await drafting;

      expect(
        steps.any((WorkflowDraftProgress step) => step.isFinished),
        isFalse,
      );
      expect(repository.listWorkflows(), hasLength(workflowsBefore));
      await expectLater(repository.stopDrafting(draft), throwsStateError);
    }
  });

  test('test_change_workflow_property_adds_one_connected_agent', () async {
    final Random random = seededRandom(8402);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, repository.listWorkflows());
      final String request = 'add ${randomWordPhrase(random)} step';
      final Workflow changed = await repository.changeWorkflow(
        workflow.id,
        '  $request  ',
        pickOne(random, AgentKind.values),
      );
      final WorkflowAgent added = changed.agents.last;

      expect(changed.agents.length, workflow.agents.length + 1);
      expect(added.task, request);
      expect(added.kind, isNotNull);
      for (final WorkflowAgent agent in workflow.agents) {
        final bool feedsNothing = workflow.connections.every(
          (AgentConnection connection) => connection.from != agent.id,
        );
        expect(
          changed.connections.contains(
            AgentConnection(
              from: agent.id,
              to: added.id,
              condition: null,
              roundLimit: null,
            ),
          ),
          feedsNothing,
        );
      }
      expect(
        repository.findWorkflow(workflow.id).agents.length,
        changed.agents.length,
      );
    }
    _expectSoundWorkflows(repository);
    await expectLater(
      repository.changeWorkflow(
        GalleryWorkflowIds.release,
        ' ',
        AgentKind.claudeCode,
      ),
      throwsArgumentError,
    );
  });

  test(
    'test_fill_agent_settings_property_fills_only_what_is_missing',
    () async {
      final Random random = seededRandom(8403);
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = pickOne(random, repository.listWorkflows());
        final WorkflowAgent blank = workflow.agents.first.copyWith(task: '');
        await repository.saveWorkflow(
          workflow.withGraph(
            agents: <WorkflowAgent>[blank, ...workflow.agents.skip(1)],
            connections: workflow.connections,
          ),
        );
        final WorkflowAgent agent = pickOne(
          random,
          repository.findWorkflow(workflow.id).agents,
        );
        final Workflow filled = await repository.fillAgentSettings(
          workflow.id,
          agent.id,
        );
        final WorkflowAgent result = filled.findAgent(agent.id);

        expect(result.kind, agent.kind ?? AgentKind.claudeCode);
        expect(result.task, isNotEmpty);
        if (agent.task.isNotEmpty) {
          expect(result.task, agent.task);
        }
        expect(result.name, agent.name);
        expect(result.runsOn, agent.runsOn);
        expect(result.position.vertical, agent.position.vertical);
      }
    },
  );

  test('test_change_workflow_property_agent_choice_keeps_the_change', () async {
    final Random random = seededRandom(8410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String request = 'add ${randomWordPhrase(random)} step';
      final List<int> agentCounts = <int>[];

      for (final AgentKind agent in AgentKind.values) {
        final FakeWorkflowRepository repository =
            buildGalleryWorkflowRepository();
        final Workflow changed = await repository.changeWorkflow(
          GalleryWorkflowIds.release,
          request,
          agent,
        );
        agentCounts.add(changed.agents.length);
        expect(changed.agents.last.task, request);
      }

      expect(agentCounts.toSet(), hasLength(1));
    }
  });

  test('test_change_workflow_property_refuses_every_blank_request', () async {
    final Random random = seededRandom(8411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository =
          buildGalleryWorkflowRepository();
      final Workflow before = repository.findWorkflow(
        GalleryWorkflowIds.release,
      );
      final String blank = ' ' * random.nextInt(6);

      await expectLater(
        repository.changeWorkflow(
          GalleryWorkflowIds.release,
          blank,
          pickOne(random, AgentKind.values),
        ),
        throwsArgumentError,
      );

      expect(repository.findWorkflow(GalleryWorkflowIds.release), before);
    }
  });
}
