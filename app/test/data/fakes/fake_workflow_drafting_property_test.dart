import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_workflow_drafting.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

const String _typePrefix = 'test_fake_workflow_drafting';
const int _draftIterations = 30;

final class _DraftListing {
  final List<Workflow> listed = <Workflow>[];

  void record(Workflow drafted) {
    listed.add(drafted);
  }
}

FakeWorkflowDrafting _buildDrafting(Workflow template) {
  return FakeWorkflowDrafting(
    template: template,
    drafterDeviceId: GalleryDeviceIds.gpuBox,
    stepDelay: Duration.zero,
  );
}

Workflow _randomTemplate(Random random) {
  return randomValidWorkflow(
    random,
    index: random.nextInt(9),
    signature: null,
  );
}

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Draft ${randomText(random)}');
}

Workflow _takenBy(Workflow template, int number) {
  return Workflow(
    id: WorkflowId('drafted-workflow-$number'),
    name: '${template.name}-${number + 1}',
    availability: template.availability,
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
}

void main() {
  test('${_typePrefix}_new_property_drafts_from_the_template', () async {
    final Random random = seededRandom(67801);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final _DraftListing listing = _DraftListing();

      final List<WorkflowDraftProgress> steps = await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: const <Workflow>[],
            listDrafted: listing.record,
          )
          .toList();

      final Workflow drafted = listing.listed.single;
      expect(drafted.agents, orderedEquals(template.agents));
      expect(drafted.connections, orderedEquals(template.connections));
      expect(drafted.name, startsWith('${template.name}-'));
      expect(steps.last.drafterDeviceId, GalleryDeviceIds.gpuBox);
    }
  });

  test('${_typePrefix}_new_property_template_steps_set_length', () async {
    final Random random = seededRandom(67802);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);

      final List<WorkflowDraftProgress> steps = await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: const <Workflow>[],
            listDrafted: _DraftListing().record,
          )
          .toList();

      expect(steps, hasLength(template.agents.length + 1));
    }
  });

  test('${_typePrefix}_new_property_each_instance_starts_free', () async {
    final Random random = seededRandom(67803);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final _DraftListing first = _DraftListing();
      final _DraftListing second = _DraftListing();

      await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: const <Workflow>[],
            listDrafted: first.record,
          )
          .toList();
      await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: const <Workflow>[],
            listDrafted: second.record,
          )
          .toList();

      expect(first.listed.single.id, second.listed.single.id);
    }
  });

  test('${_typePrefix}_stream_draft_progress_property_skips_taken', () async {
    final Random random = seededRandom(67804);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final List<Workflow> taken = <Workflow>[
        for (int number = 1; number <= random.nextInt(5); number += 1)
          _takenBy(template, number),
      ];
      final _DraftListing listing = _DraftListing();

      await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: taken,
            listDrafted: listing.record,
          )
          .toList();

      final Workflow drafted = listing.listed.single;
      for (final Workflow listed in taken) {
        expect(drafted.id, isNot(listed.id));
        expect(drafted.name, isNot(listed.name));
      }
    }
  });

  test(
    '${_typePrefix}_stream_draft_progress_property_refuses_twice',
    () async {
      final Random random = seededRandom(67805);

      for (int i = 0; i < _draftIterations; i += 1) {
        final FakeWorkflowDrafting drafting = _buildDrafting(
          galleryWorkflows[featurePipelineIndex],
        );
        final WorkflowDraft draft = _randomDraft(random);
        final _DraftListing listing = _DraftListing();
        final Future<List<WorkflowDraftProgress>> running = drafting
            .streamDraftProgress(
              draft: draft,
              listedWorkflows: const <Workflow>[],
              listDrafted: listing.record,
            )
            .toList();
        await Future<void>.delayed(Duration.zero);

        await expectLater(
          drafting.streamDraftProgress(
            draft: draft,
            listedWorkflows: const <Workflow>[],
            listDrafted: listing.record,
          ),
          emitsError(isStateError),
        );
        await running;
        expect(listing.listed, hasLength(1));
      }
    },
  );

  test(
    '${_typePrefix}_stream_draft_progress_property_distinct_runs',
    () async {
      final Random random = seededRandom(67806);

      for (int i = 0; i < _draftIterations; i += 1) {
        final FakeWorkflowDrafting drafting = _buildDrafting(
          _randomTemplate(random),
        );
        final _DraftListing listing = _DraftListing();
        final int draftCount = 1 + random.nextInt(4);

        for (int draft = 0; draft < draftCount; draft += 1) {
          await drafting
              .streamDraftProgress(
                draft: _randomDraft(random),
                listedWorkflows: listing.listed,
                listDrafted: listing.record,
              )
              .toList();
        }

        final Set<WorkflowId> ids = <WorkflowId>{
          for (final Workflow drafted in listing.listed) drafted.id,
        };
        expect(ids, hasLength(draftCount));
      }
    },
  );

  test('${_typePrefix}_stop_drafting_property_idle_is_refused', () async {
    final Random random = seededRandom(67807);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowDrafting drafting = _buildDrafting(
        _randomTemplate(random),
      );

      await expectLater(
        drafting.stopDrafting(_randomDraft(random)),
        throwsStateError,
      );
    }
  });

  test(
    '${_typePrefix}_stop_drafting_property_stopped_lists_nothing',
    () async {
      final Random random = seededRandom(67808);

      for (int i = 0; i < _draftIterations; i += 1) {
        final FakeWorkflowDrafting drafting = _buildDrafting(
          galleryWorkflows[featurePipelineIndex],
        );
        final WorkflowDraft draft = _randomDraft(random);
        final _DraftListing listing = _DraftListing();
        final Future<List<WorkflowDraftProgress>> running = drafting
            .streamDraftProgress(
              draft: draft,
              listedWorkflows: const <Workflow>[],
              listDrafted: listing.record,
            )
            .toList();
        await Future<void>.delayed(Duration.zero);

        await drafting.stopDrafting(draft);

        final List<WorkflowDraftProgress> steps = await running;
        expect(
          steps.any((WorkflowDraftProgress step) => step.isFinished),
          false,
        );
        expect(listing.listed, isEmpty);
      }
    },
  );

  test('${_typePrefix}_stop_drafting_property_only_once', () async {
    final Random random = seededRandom(67809);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowDrafting drafting = _buildDrafting(
        galleryWorkflows[featurePipelineIndex],
      );
      final WorkflowDraft draft = _randomDraft(random);
      final Future<List<WorkflowDraftProgress>> running = drafting
          .streamDraftProgress(
            draft: draft,
            listedWorkflows: const <Workflow>[],
            listDrafted: _DraftListing().record,
          )
          .toList();
      await Future<void>.delayed(Duration.zero);

      await drafting.stopDrafting(draft);
      await expectLater(drafting.stopDrafting(draft), throwsStateError);
      await running;
    }
  });
}
