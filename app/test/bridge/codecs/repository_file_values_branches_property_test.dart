import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_file_json.dart';
import '../support/random_repository_file_values.dart';
import '../support/random_wire_values.dart';
import '../support/repository_branches_wire_fields.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const List<String> _branchKinds = <String>['available', 'unavailable'];

WireFields _readBranchesFields(JsonObject json) {
  if (json[branchesKindField] == AvailableRepositoryBranches.kind) {
    return availableBranchesFields;
  }
  return unavailableBranchesFields;
}

AvailableRepositoryBranches _randomAvailable(Random random) {
  return AvailableRepositoryBranches(
    runner: randomFileRunner(random),
    branches: randomTextList(random),
    taskBranches: randomTextList(random),
  );
}

void main() {
  test(
    'test_repository_branches_view_from_json_property_kind_picks_variant',
    () {
      final Random random = seededRandom(52301);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryBranchesJson(random);

        final RepositoryBranchesView view = RepositoryBranchesView.fromJson(
          withUnknownFields(random, json),
        );

        switch (view) {
          case AvailableRepositoryBranches():
            expect(json[branchesKindField], 'available');
            expect(view.runner.toJson(), equals(json['runner']));
            expect(
              view.branches,
              orderedEquals(json['branches']! as List<Object?>),
            );
            expect(
              view.taskBranches,
              orderedEquals(json['task_branches']! as List<Object?>),
            );
          case UnavailableRepositoryBranches():
            expect(json[branchesKindField], 'unavailable');
            expect(encodeList(view.holders), equals(json['holders']));
        }
      }
    },
  );

  test(
    'test_repository_branches_view_from_json_property_unknown_kinds_raise',
    () {
      final Random random = seededRandom(52302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryBranchesJson(random);
        final String kind = json[branchesKindField]!.toString();

        for (final String nearMiss in nearMissWireNames(
          random,
          kind,
          'Ready',
        )) {
          if (_branchKinds.contains(nearMiss)) {
            continue;
          }
          final JsonObject renamed = withFieldValue(
            json,
            branchesKindField,
            nearMiss,
          );
          expect(
            () => RepositoryBranchesView.fromJson(renamed),
            throwsFormatException,
          );
        }
      }
    },
  );

  test(
    'test_repository_branches_view_from_json_property_missing_fields_follow',
    () {
      final Random random = seededRandom(52303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryBranchesJson(random);

        expectRequiredFieldsAreNeeded(
          json,
          _readBranchesFields(json),
          RepositoryBranchesView.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_branches_view_from_json_property_wrong_kinds_raise',
    () {
      final Random random = seededRandom(52304);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomRepositoryBranchesJson(random),
          RepositoryBranchesView.fromJson,
        );
      }
    },
  );

  test('test_available_repository_branches_property_keeps_each_list', () {
    final Random random = seededRandom(52305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> branches = randomTextList(random);
      final List<String> taskBranches = randomTextList(random);

      final AvailableRepositoryBranches view = AvailableRepositoryBranches(
        runner: randomFileRunner(random),
        branches: branches,
        taskBranches: taskBranches,
      );

      expect(view.branches, orderedEquals(branches));
      expect(view.taskBranches, orderedEquals(taskBranches));
    }
  });

  test(
    'test_available_repository_branches_property_ignores_caller_changes',
    () {
      final Random random = seededRandom(52306);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<String> branches = randomTextList(random);
        final List<String> taskBranches = randomTextList(random);

        final AvailableRepositoryBranches view = AvailableRepositoryBranches(
          runner: randomFileRunner(random),
          branches: branches,
          taskBranches: taskBranches,
        );

        expectListIgnoresCallerChanges(branches, view.branches, 'main');
        expectListIgnoresCallerChanges(
          taskBranches,
          view.taskBranches,
          'task',
        );
      }
    },
  );

  test('test_available_repository_branches_property_lists_refuse_changes', () {
    final Random random = seededRandom(52307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AvailableRepositoryBranches view = _randomAvailable(random);

      expectListRefusesChanges(view.branches, 'main');
      expectListRefusesChanges(view.taskBranches, 'task');
    }
  });

  test(
    'test_available_repository_branches_to_json_property_writes_node_fields',
    () {
      final Random random = seededRandom(52308);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject encoded = _randomAvailable(random).toJson();

        expect(
          encoded.keys.toSet(),
          equals(availableBranchesFields.everyField),
        );
        expect(encoded[branchesKindField], AvailableRepositoryBranches.kind);
      }
    },
  );

  test(
    'test_available_repository_branches_to_json_property_mirrors_lists',
    () {
      final Random random = seededRandom(52309);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AvailableRepositoryBranches view = _randomAvailable(random);

        final JsonObject encoded = view.toJson();

        expect(encoded['runner'], equals(view.runner.toJson()));
        expect(encoded['branches'], orderedEquals(view.branches));
        expect(encoded['task_branches'], orderedEquals(view.taskBranches));
      }
    },
  );

  test('test_available_repository_branches_to_json_property_decodes_back', () {
    final Random random = seededRandom(52310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AvailableRepositoryBranches view = _randomAvailable(random);

      final RepositoryBranchesView reread = RepositoryBranchesView.fromJson(
        reencodeThroughText(view),
      );

      expect(reread, isA<AvailableRepositoryBranches>());
      expectPlainJsonThatDecodesBack(view, RepositoryBranchesView.fromJson);
    }
  });
}
