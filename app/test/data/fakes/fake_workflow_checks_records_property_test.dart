import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_workflow_checks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

const List<String> _blankRequests = <String>['', ' ', '\t', '\n', '  \t\n '];
const int _largestChangeCount = 6;

List<WorkflowChange> _randomChanges(Random random) {
  final int count = random.nextInt(_largestChangeCount);
  return <WorkflowChange>[
    for (int index = 0; index < count; index += 1)
      buildSampleChange(WorkflowId('workflow-${random.nextInt(4)}')),
  ];
}

bool _hasRepeat(List<String> identifiers) {
  return identifiers.toSet().length != identifiers.length;
}

void main() {
  test('test_refuse_duplicate_workflow_records_property_refuses_exactly_'
      'repeated_workflow_ids', () {
    final Random random = seededRandom(92701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final bool isRepeating = seeded.isNotEmpty && random.nextBool();
      final List<Workflow> workflows = <Workflow>[
        ...seeded,
        if (isRepeating) pickOne(random, seeded),
      ];
      final bool isRepeated = _hasRepeat(<String>[
        for (final Workflow workflow in workflows) workflow.id.value,
      ]);

      expect(
        () => refuseDuplicateWorkflowRecords(
          workflows: workflows,
          changes: const <WorkflowChange>[],
        ),
        isRepeated ? throwsArgumentError : returnsNormally,
      );
    }
  });

  test('test_refuse_duplicate_workflow_records_property_refuses_exactly_'
      'repeated_change_ids', () {
    final Random random = seededRandom(92702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowChange> changes = _randomChanges(random);
      final bool isRepeated = _hasRepeat(<String>[
        for (final WorkflowChange change in changes) change.workflowId.value,
      ]);

      expect(
        () => refuseDuplicateWorkflowRecords(
          workflows: const <Workflow>[],
          changes: changes,
        ),
        isRepeated ? throwsArgumentError : returnsNormally,
      );
    }
  });

  test('test_refuse_duplicate_workflow_records_property_names_the_kind_of_'
      'the_repeated_record', () {
    final Random random = seededRandom(92703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowChange change = buildSampleChange(
        WorkflowId(randomText(random)),
      );

      expect(
        () => refuseDuplicateWorkflowRecords(
          workflows: const <Workflow>[],
          changes: <WorkflowChange>[change, change],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => '${error.message}',
            'message',
            contains(workflowChangeKind),
          ),
        ),
      );
    }
  });

  test('test_require_change_request_property_trims_a_real_request', () {
    final Random random = seededRandom(92704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String core = 'add ${randomWordPhrase(random)} step $i';
      final String padded =
          '${pickOne(random, _blankRequests)}$core'
          '${pickOne(random, _blankRequests)}';

      expect(requireChangeRequest(padded), core);
    }
  });

  test('test_require_change_request_property_refuses_blank_requests', () {
    final Random random = seededRandom(92705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String blank = pickOne(random, _blankRequests);

      expect(
        () => requireChangeRequest(blank),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            blank,
          ),
        ),
      );
    }
  });

  test('test_require_change_request_property_is_idempotent', () {
    final Random random = seededRandom(92706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String request = '  ${randomText(random)}x ';

      final String once = requireChangeRequest(request);

      expect(requireChangeRequest(once), once);
      expect(once.trim(), once);
    }
  });

  test('test_find_change_of_property_finds_the_first_change_of_the_'
      'workflow', () {
    final Random random = seededRandom(92707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowChange> changes = _randomChanges(random);
      final WorkflowId wanted = WorkflowId('workflow-${random.nextInt(4)}');

      final WorkflowChange? found = findChangeOf(changes, wanted);

      final List<WorkflowChange> matching = <WorkflowChange>[
        for (final WorkflowChange change in changes)
          if (change.workflowId == wanted) change,
      ];
      if (matching.isEmpty) {
        expect(found, isNull);
      } else {
        expect(found, same(matching.first));
      }
    }
  });

  test('test_find_change_of_property_finds_nothing_in_an_empty_list', () {
    final Random random = seededRandom(92708);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        findChangeOf(const <WorkflowChange>[], WorkflowId(randomText(random))),
        isNull,
      );
    }
  });

  test('test_find_change_of_property_ignores_changes_of_other_'
      'workflows', () {
    final Random random = seededRandom(92709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowChange> changes = _randomChanges(random);
      final WorkflowId absent = WorkflowId('absent-${randomText(random)}');

      expect(findChangeOf(changes, absent), isNull);
    }
  });
}
