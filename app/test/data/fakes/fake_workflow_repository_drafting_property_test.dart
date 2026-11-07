import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';

const List<String> _blankDescriptions = <String>['', ' ', '\n\t ', ' ', '  　'];
const int _draftIterations = 30;

final Workflow _template = galleryWorkflows[featurePipelineIndex];

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Plan ${randomText(random)} then ship.');
}

Workflow _buildTakenWorkflow(int number) {
  return Workflow(
    id: WorkflowId('drafted-workflow-$number'),
    name: '${_template.name}-$number',
    availability: _template.availability,
    agents: _template.agents,
    connections: _template.connections,
    signature: null,
  );
}

Future<void> _waitForSteps(
  List<WorkflowDraftProgress> steps,
  int count,
) async {
  await Future<void>.delayed(Duration.zero);
  while (steps.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('test_draft_workflow_property_blank_words_add_nothing', () async {
    final Random random = seededRandom(67401);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final int countBefore = repository.listWorkflows().length;
      final String blank = pickOne(random, _blankDescriptions);

      await expectLater(
        repository.draftWorkflow(WorkflowDraft(description: blank)),
        emitsError(isArgumentError),
      );
      expect(repository.listWorkflows(), hasLength(countBefore));
    }
  });

  test('test_draft_workflow_property_result_is_free_and_valid', () async {
    final Random random = seededRandom(67402);

    for (int i = 0; i < _draftIterations; i += 1) {
      final List<Workflow> taken = <Workflow>[
        for (int number = 1; number <= random.nextInt(4); number += 1)
          _buildTakenWorkflow(number),
      ];
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: taken,
        changes: const <WorkflowChange>[],
      );
      final Set<WorkflowId> idsBefore = <WorkflowId>{
        for (final Workflow workflow in taken) workflow.id,
      };
      final Set<String> namesBefore = <String>{
        for (final Workflow workflow in taken) workflow.name,
      };

      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(_randomDraft(random))
          .toList();
      final Workflow drafted = steps.last.workflow;

      expect(idsBefore, isNot(contains(drafted.id)));
      expect(namesBefore, isNot(contains(drafted.name)));
      expect(describeUploadProblem(drafted), isNull);
      final Workflow listed = repository.findWorkflow(drafted.id);
      expect(listed.name, drafted.name);
      expect(listed.agents, orderedEquals(drafted.agents));
      expect(drafted.signature, isNull);
    }
  });

  test('test_draft_workflow_property_one_run_per_request', () async {
    final Random random = seededRandom(67403);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: const <Workflow>[],
        changes: const <WorkflowChange>[],
      );
      final WorkflowDraft draft = _randomDraft(random);
      final Future<List<WorkflowDraftProgress>> first = repository
          .draftWorkflow(draft)
          .toList();
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        repository.draftWorkflow(draft),
        emitsError(isStateError),
      );
      final List<WorkflowDraftProgress> steps = await first;
      expect(steps.last.isFinished, isTrue);
      expect(repository.listWorkflows(), hasLength(1));
    }
  });

  test('test_stop_drafting_property_idle_requests_are_refused', () async {
    final Random random = seededRandom(67404);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final WorkflowDraft draft = _randomDraft(random);

      await expectLater(repository.stopDrafting(draft), throwsStateError);
      await repository.draftWorkflow(draft).toList();
      await expectLater(repository.stopDrafting(draft), throwsStateError);
    }
  });

  test('test_stop_drafting_property_stopped_draft_adds_nothing', () async {
    final Random random = seededRandom(67405);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final int countBefore = repository.listWorkflows().length;
      final WorkflowDraft draft = _randomDraft(random);
      final List<WorkflowDraftProgress> steps = <WorkflowDraftProgress>[];
      final Future<void> drafting = repository
          .draftWorkflow(draft)
          .forEach(steps.add);
      await _waitForSteps(steps, random.nextInt(_template.agents.length));

      await repository.stopDrafting(draft);
      await drafting;

      final bool hasFinished = steps.any(
        (WorkflowDraftProgress step) => step.isFinished,
      );
      expect(hasFinished, isFalse);
      expect(repository.listWorkflows(), hasLength(countBefore));
    }
  });

  test('test_stop_drafting_property_other_drafts_keep_going', () async {
    final Random random = seededRandom(67406);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: const <Workflow>[],
        changes: const <WorkflowChange>[],
      );
      final WorkflowDraft stopped = _randomDraft(random);
      final WorkflowDraft kept = _randomDraft(random);
      final Future<List<WorkflowDraftProgress>> stoppedSteps = repository
          .draftWorkflow(stopped)
          .toList();
      final Future<List<WorkflowDraftProgress>> keptSteps = repository
          .draftWorkflow(kept)
          .toList();
      await Future<void>.delayed(Duration.zero);

      await repository.stopDrafting(stopped);

      expect((await keptSteps).last.isFinished, isTrue);
      final bool stoppedFinished = (await stoppedSteps).any(
        (WorkflowDraftProgress step) => step.isFinished,
      );
      expect(stoppedFinished, isFalse);
      expect(repository.listWorkflows(), hasLength(1));
    }
  });

  test('test_stream_draft_property_agents_arrive_in_order', () async {
    final Random random = seededRandom(67407);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );

      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(_randomDraft(random))
          .toList();
      final Workflow drafted = steps.last.workflow;

      expect(steps, hasLength(_template.agents.length + 1));
      for (int index = 0; index < steps.length; index += 1) {
        final WorkflowDraftProgress step = steps[index];
        final List<String> pendingNames = <String>[
          for (final PendingAgent pending in step.pendingAgents) pending.name,
        ];
        final List<String> remainingNames = <String>[
          for (final WorkflowAgent agent in drafted.agents.skip(index))
            agent.name,
        ];
        expect(
          step.workflow.agents,
          orderedEquals(drafted.agents.take(index)),
        );
        expect(pendingNames, orderedEquals(remainingNames));
        expect(step.isFinished, index == steps.length - 1);
      }
    }
  });

  test('test_stream_draft_property_partial_graphs_stay_closed', () async {
    final Random random = seededRandom(67408);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: const <Workflow>[],
        changes: const <WorkflowChange>[],
      );

      final List<WorkflowDraftProgress> steps = await repository
          .draftWorkflow(_randomDraft(random))
          .toList();

      for (final WorkflowDraftProgress step in steps) {
        final Set<WorkflowAgentId> addedIds = <WorkflowAgentId>{
          for (final WorkflowAgent agent in step.workflow.agents) agent.id,
        };
        for (final AgentConnection connection in step.workflow.connections) {
          expect(addedIds, contains(connection.from));
          expect(addedIds, contains(connection.to));
        }
        expect(step.drafterKind, AgentKind.claudeCode);
        expect(step.drafterDeviceId, GalleryDeviceIds.officeServer);
      }
    }
  });

  test('test_stream_draft_property_listed_only_when_finished', () async {
    final Random random = seededRandom(67409);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: randomSeededWorkflows(random),
        changes: const <WorkflowChange>[],
      );
      final int countBefore = repository.listWorkflows().length;
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final List<int> listedCounts = <int>[];

      await for (final WorkflowDraftProgress step in repository.draftWorkflow(
        _randomDraft(random),
      )) {
        listedCounts.add(repository.listWorkflows().length - countBefore);
        expect(step.workflow.signature, isNull);
      }

      expect(listedCounts.last, 1);
      expect(listedCounts.take(listedCounts.length - 1), everyElement(0));
      expect(notifications.count, 1);
    }
  });
}
