import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_repository_file_values.dart';
import '../support/repository_branches_wire_fields.dart';
import '../support/wire_contract_checks.dart';

UnavailableRepositoryBranches _randomUnavailable(Random random) {
  return UnavailableRepositoryBranches(
    holders: randomRepositoryHolders(random),
  );
}

void main() {
  test('test_unavailable_repository_branches_property_keeps_holders', () {
    final Random random = seededRandom(52311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryHolder> holders = randomRepositoryHolders(random);

      final UnavailableRepositoryBranches view = UnavailableRepositoryBranches(
        holders: holders,
      );

      expect(view.holders, orderedEquals(holders));
    }
  });

  test(
    'test_unavailable_repository_branches_property_ignores_caller_changes',
    () {
      final Random random = seededRandom(52312);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<RepositoryHolder> holders = randomRepositoryHolders(random);

        final UnavailableRepositoryBranches view =
            UnavailableRepositoryBranches(holders: holders);

        expectListIgnoresCallerChanges(
          holders,
          view.holders,
          randomRepositoryHolder(random),
        );
      }
    },
  );

  test(
    'test_unavailable_repository_branches_property_holders_refuse_change',
    () {
      final Random random = seededRandom(52313);

      for (int i = 0; i < propertyIterations; i += 1) {
        final UnavailableRepositoryBranches view = _randomUnavailable(random);

        expectListRefusesChanges(view.holders, randomRepositoryHolder(random));
      }
    },
  );

  test(
    'test_unavailable_repository_branches_to_json_property_writes_node_fields',
    () {
      final Random random = seededRandom(52314);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject encoded = _randomUnavailable(random).toJson();

        expect(
          encoded.keys.toSet(),
          equals(unavailableBranchesFields.everyField),
        );
        expect(encoded[branchesKindField], UnavailableRepositoryBranches.kind);
      }
    },
  );

  test(
    'test_unavailable_repository_branches_to_json_property_holders_in_order',
    () {
      final Random random = seededRandom(52315);

      for (int i = 0; i < propertyIterations; i += 1) {
        final UnavailableRepositoryBranches view = _randomUnavailable(random);

        final List<Object?> encodedHolders =
            view.toJson()['holders']! as List<Object?>;

        expect(encodedHolders.length, view.holders.length);
        for (int j = 0; j < view.holders.length; j += 1) {
          expect(encodedHolders[j], equals(view.holders[j].toJson()));
        }
      }
    },
  );

  test(
    'test_unavailable_repository_branches_to_json_property_decodes_back',
    () {
      final Random random = seededRandom(52316);

      for (int i = 0; i < propertyIterations; i += 1) {
        final UnavailableRepositoryBranches view = _randomUnavailable(random);

        final RepositoryBranchesView reread = RepositoryBranchesView.fromJson(
          reencodeThroughText(view),
        );

        expect(reread, isA<UnavailableRepositoryBranches>());
        expectPlainJsonThatDecodesBack(view, RepositoryBranchesView.fromJson);
      }
    },
  );
}
