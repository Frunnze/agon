import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_workflow_drafting.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

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

Future<Workflow> _draftOnce(
  Random random,
  FakeWorkflowDrafting drafting,
  List<Workflow> listedWorkflows,
) async {
  final _DraftListing listing = _DraftListing();
  await drafting
      .streamDraftProgress(
        draft: _randomDraft(random),
        listedWorkflows: listedWorkflows,
        listDrafted: listing.record,
      )
      .toList();
  return listing.listed.single;
}

void main() {
  test('test_claim_free_draft_property_names_pass_the_rule', () async {
    final Random random = seededRandom(67810);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final _DraftListing listing = _DraftListing();

      await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: <Workflow>[_takenBy(template, 1)],
            listDrafted: listing.record,
          )
          .toList();

      expect(describeUploadProblem(listing.listed.single), isNull);
    }
  });

  test('test_is_taken_property_same_name_other_id_is_taken', () async {
    final Random random = seededRandom(67811);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final Workflow sameName = Workflow(
        id: WorkflowId('other-${randomText(random)}'),
        name: '${template.name}-1',
        availability: template.availability,
        agents: const <WorkflowAgent>[],
        connections: const <AgentConnection>[],
        signature: null,
      );
      final _DraftListing listing = _DraftListing();

      await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: <Workflow>[sameName],
            listDrafted: listing.record,
          )
          .toList();

      expect(listing.listed.single.name, isNot(sameName.name));
    }
  });

  test('test_is_taken_property_same_id_other_name_is_taken', () async {
    final Random random = seededRandom(67812);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final Workflow sameId = Workflow(
        id: const WorkflowId('drafted-workflow-1'),
        name: 'unrelated-${random.nextInt(100)}',
        availability: template.availability,
        agents: const <WorkflowAgent>[],
        connections: const <AgentConnection>[],
        signature: null,
      );
      final _DraftListing listing = _DraftListing();

      await _buildDrafting(template)
          .streamDraftProgress(
            draft: _randomDraft(random),
            listedWorkflows: <Workflow>[sameId],
            listDrafted: listing.record,
          )
          .toList();

      expect(listing.listed.single.id, isNot(sameId.id));
    }
  });

  test('test_claim_free_draft_property_numbers_keep_rising', () async {
    final Random random = seededRandom(67813);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowDrafting drafting = _buildDrafting(
        _randomTemplate(random),
      );

      const List<Workflow> nothingListed = <Workflow>[];
      final Workflow first = await _draftOnce(random, drafting, nothingListed);
      final Workflow second = await _draftOnce(
        random,
        drafting,
        nothingListed,
      );

      expect(second.id, isNot(first.id));
      expect(second.name, isNot(first.name));
    }
  });

  test('test_claim_free_draft_property_starts_unsigned', () async {
    final Random random = seededRandom(67814);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = randomValidWorkflow(
        random,
        index: i,
        signature: buildSampleSignature(),
      );

      final Workflow drafted = await _draftOnce(
        random,
        _buildDrafting(template),
        const <Workflow>[],
      );

      expect(drafted.signature, isNull);
      expect(drafted.availability, same(template.availability));
    }
  });

  test('test_is_taken_property_free_listing_keeps_first_number', () async {
    final Random random = seededRandom(67815);

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow template = _randomTemplate(random);
      final Workflow unrelated = _takenBy(
        template.withName('other-$i'),
        50 + i,
      );

      final Workflow drafted = await _draftOnce(
        random,
        _buildDrafting(template),
        <Workflow>[unrelated],
      );

      expect(drafted.id.value, 'drafted-workflow-1');
      expect(drafted.name, '${template.name}-1');
    }
  });
}
