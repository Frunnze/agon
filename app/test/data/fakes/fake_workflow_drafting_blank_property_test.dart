import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_workflow_drafting.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';

const int _draftIterations = 30;
const int _longestBlankLength = 8;
const int _largestRefusalCount = 4;
const int _seedSpan = 1 << 30;
const int _firstVisibleCodeUnit = 0x21;
const int _visibleCodeUnitSpan = 94;
const List<String> _whiteSpaceCharacters = <String>[
  ' ',
  '\t',
  '\n',
  '\r',
  '\u000B',
  '\u000C',
  '\u0085',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  '　',
  '﻿',
];

final class _DraftListing {
  final List<Workflow> listed = <Workflow>[];

  void record(Workflow drafted) {
    listed.add(drafted);
  }
}

String _randomBlankDescription(Random random) {
  final int length = random.nextInt(_longestBlankLength + 1);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    buffer.write(pickOne(random, _whiteSpaceCharacters));
  }
  return buffer.toString();
}

String _randomWordedDescription(Random random) {
  final int visibleCodeUnit =
      _firstVisibleCodeUnit + random.nextInt(_visibleCodeUnitSpan);
  final String visible = String.fromCharCode(visibleCodeUnit);
  final String core = '$visible${randomText(random)}';
  final String leading = _randomBlankDescription(random);
  final String trailing = _randomBlankDescription(random);
  return '$leading$core$trailing';
}

FakeWorkflowDrafting _buildDrafting(Random random) {
  return FakeWorkflowDrafting(
    template: randomValidWorkflow(random, index: 0, signature: null),
    drafterDeviceId: GalleryDeviceIds.officeServer,
    stepDelay: Duration.zero,
  );
}

Stream<WorkflowDraftProgress> _streamDraft(
  FakeWorkflowDrafting drafting,
  String description,
  _DraftListing listing,
) {
  return drafting.streamDraftProgress(
    draft: WorkflowDraft(description: description),
    listedWorkflows: const <Workflow>[],
    listDrafted: listing.record,
  );
}

Matcher _throwsBlank(String description) {
  return throwsA(
    isA<ArgumentError>()
        .having(
          (ArgumentError error) => error.message,
          'message',
          blankWorkflowDescriptionProblem,
        )
        .having((ArgumentError error) => error.name, 'name', 'description')
        .having(
          (ArgumentError error) => error.invalidValue,
          'invalidValue',
          description,
        ),
  );
}

void main() {
  test('test_stream_draft_progress_property_refuses_blank_'
      'descriptions', () async {
    final Random random = seededRandom(95191);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _DraftListing listing = _DraftListing();
      final String blank = _randomBlankDescription(random);

      await expectLater(
        _streamDraft(_buildDrafting(random), blank, listing).toList(),
        _throwsBlank(blank),
      );

      expect(listing.listed, isEmpty);
    }
  });

  test('test_stream_draft_progress_property_blank_refusals_take_no_'
      'number', () async {
    final Random random = seededRandom(95192);

    for (int i = 0; i < _draftIterations; i += 1) {
      final int drafterSeed = random.nextInt(_seedSpan);
      final FakeWorkflowDrafting refusing = _buildDrafting(
        seededRandom(drafterSeed),
      );
      final FakeWorkflowDrafting fresh = _buildDrafting(
        seededRandom(drafterSeed),
      );
      final _DraftListing refusingListing = _DraftListing();
      final _DraftListing freshListing = _DraftListing();
      final int refusalCount = 1 + random.nextInt(_largestRefusalCount);
      final String description = _randomWordedDescription(random);

      for (int refusal = 0; refusal < refusalCount; refusal += 1) {
        final String blank = _randomBlankDescription(random);
        await expectLater(
          _streamDraft(refusing, blank, refusingListing).toList(),
          _throwsBlank(blank),
        );
      }
      await _streamDraft(refusing, description, refusingListing).toList();
      await _streamDraft(fresh, description, freshListing).toList();

      final Workflow drafted = refusingListing.listed.single;
      expect(drafted.id, freshListing.listed.single.id);
      expect(drafted.name, freshListing.listed.single.name);
    }
  });

  test('test_stream_draft_progress_property_blank_refused_while_another_'
      'runs', () async {
    final Random random = seededRandom(95193);

    for (int i = 0; i < _draftIterations; i += 1) {
      final FakeWorkflowDrafting drafting = _buildDrafting(random);
      final _DraftListing listing = _DraftListing();
      final String blank = _randomBlankDescription(random);
      final Future<List<WorkflowDraftProgress>> running = _streamDraft(
        drafting,
        _randomWordedDescription(random),
        listing,
      ).toList();

      await expectLater(
        _streamDraft(drafting, blank, listing).toList(),
        _throwsBlank(blank),
      );

      final List<WorkflowDraftProgress> steps = await running;
      expect(steps.last.isFinished, isTrue);
      expect(listing.listed, hasLength(1));
    }
  });

  test('test_stream_draft_progress_property_words_around_white_space_'
      'are_drafted', () async {
    final Random random = seededRandom(95194);

    for (int i = 0; i < _draftIterations; i += 1) {
      final _DraftListing listing = _DraftListing();

      final List<WorkflowDraftProgress> steps = await _streamDraft(
        _buildDrafting(random),
        _randomWordedDescription(random),
        listing,
      ).toList();

      expect(steps.last.isFinished, isTrue);
      expect(listing.listed.single.id, steps.last.workflow.id);
    }
  });

  test('test_stream_draft_progress_property_repository_lists_nothing_'
      'for_blank', () async {
    final Random random = seededRandom(95195);

    for (int i = 0; i < _draftIterations; i += 1) {
      final SeededWorkflows? seeded = seedRandomWorkflows(random);
      if (seeded == null) {
        continue;
      }
      final FakeWorkflowRepository repository = seeded.repository;
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final String blank = _randomBlankDescription(random);

      await expectLater(
        repository.draftWorkflow(WorkflowDraft(description: blank)).toList(),
        _throwsBlank(blank),
      );

      expect(repository.listWorkflows(), orderedEquals(seeded.workflows));
      expect(notifications.count, 0);
    }
  });
}
